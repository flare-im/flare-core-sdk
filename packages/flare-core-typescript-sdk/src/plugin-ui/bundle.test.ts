import { describe, expect, it, vi } from "vitest";
import {
  browserBundleRuntime,
  createPluginBundleEventHub,
  openPluginBundle,
  pluginBundleAnswer,
  pluginBundleErrorReason,
  type PluginBundlePort,
} from "./bundle";

function port(overrides: Partial<PluginBundlePort> = {}): PluginBundlePort {
  return {
    pluginBundleOpen: vi.fn(async () => ({ sessionId: "s1", origin: "null", root: "https://sandbox.example.com/b/abc/", entry: "index.html", csp: "default-src 'none'", hello: {} })),
    pluginBundleBridge: vi.fn(async () => ({ envelope: '{"bridge":1,"id":"r-1","type":"response","result":{}}' })),
    pluginBundleHostResult: vi.fn(async () => ({ envelope: '{"bridge":1,"id":"r-2","type":"response","result":{"confirmed":true}}' })),
    pluginBundleHostEvent: vi.fn(async () => ({ deliveries: [
      { sessionId: "s1", envelope: '{"bridge":1,"type":"event","event":"theme.changed","payload":{}}' },
      { sessionId: "s2", envelope: '{"bridge":1,"type":"event","event":"theme.changed","payload":{}}' },
    ] })),
    pluginBundleClose: vi.fn(async () => ({ closed: true })),
    ...overrides,
  };
}

const request = { pluginId: "sdk.plugin.task", contributionId: "task.dashboard", locale: "en-US", theme: { mode: "light" as const, tokens: {} } };

describe("plugin bundle session", () => {
  it("carries envelopes as JSON text to the engine and objects to the host", async () => {
    const p = port();
    const session = await openPluginBundle(p, request);
    expect(session?.sessionId).toBe("s1");
    const answer = await session!.request({ bridge: 1, id: "r-1", type: "request", method: "host.hello" }, { userGesture: true });
    expect(p.pluginBundleBridge).toHaveBeenCalledWith({ sessionId: "s1", envelope: '{"bridge":1,"id":"r-1","type":"request","method":"host.hello"}', userGesture: true });
    expect(answer).toEqual({ envelope: { bridge: 1, id: "r-1", type: "response", result: {} } });
  });

  it("answers host requests once and only for its own session's events", async () => {
    const p = port();
    const session = (await openPluginBundle(p, request))!;
    await session.hostResult("r-2", { result: { confirmed: true } });
    expect(p.pluginBundleHostResult).toHaveBeenCalledWith({ sessionId: "s1", id: "r-2", result: { confirmed: true } });
    const envelopes = await session.hostEvent("theme.changed", { mode: "dark", tokens: {} });
    expect(envelopes).toHaveLength(1);
    session.close();
    session.close();
    expect(p.pluginBundleClose).toHaveBeenCalledTimes(1);
    expect(await session.request({ type: "request" }, { userGesture: false })).toBeNull();
  });

  it("falls back when the engine offers no bundle", async () => {
    const p = port({ pluginBundleOpen: vi.fn(async () => { throw new Error("sdk.plugin_bundle.not_offered"); }) });
    expect(await openPluginBundle(p, request)).toBeNull();
    const bad = port({ pluginBundleOpen: vi.fn(async () => { throw { messageKey: "sdk.plugin_bundle.invalid_request" }; }) });
    await expect(openPluginBundle(bad, request)).rejects.toBeTruthy();
    expect(pluginBundleErrorReason({ details: { key: "sdk.plugin_bundle.rejected" } })).toBe("rejected");
  });

  it("routes engine events to the session they name", () => {
    const hub = createPluginBundleEventHub();
    const seen: unknown[] = [];
    const stop = hub.listen("s1", (event) => seen.push(event));
    expect(hub.announce({ sessionId: "s2", close: "evicted" })).toBe(false);
    expect(hub.announce({ sessionId: "s1", envelope: '{"type":"event","event":"catalog.changed"}' })).toBe(true);
    expect(hub.announce({ sessionId: "s1", close: "withdrawn" })).toBe(true);
    stop();
    expect(hub.announce({ sessionId: "s1", close: "withdrawn" })).toBe(false);
    expect(seen).toEqual([{ envelope: { type: "event", event: "catalog.changed" } }, { close: "withdrawn" }]);
  });

  it("reads host requests from the bridge answer", () => {
    expect(pluginBundleAnswer({ host: { id: "a", method: "ui.toast", params: { message: "hi" } } }))
      .toEqual({ host: { id: "a", method: "ui.toast", params: { message: "hi" } } });
    expect(pluginBundleAnswer({ envelope: "not json" })).toBeNull();
  });
});

describe("browser bundle runtime", () => {
  it("reports engines at or above the floor only", () => {
    expect(browserBundleRuntime({ userAgent: "x", userAgentData: { brands: [{ brand: "Chromium", version: "120" }] } }))
      .toEqual({ bridge: 1, engine: "chromium", engineMajor: 120 });
    expect(browserBundleRuntime({ userAgent: "Mozilla/5.0 (X11; Linux) Gecko/20100101 Firefox/128.0" })?.engine).toBe("gecko");
    expect(browserBundleRuntime({ userAgent: "Mozilla/5.0 Gecko/20100101 Firefox/102.0" })).toBeUndefined();
    expect(browserBundleRuntime({ userAgent: "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15" }))
      .toEqual({ bridge: 1, engine: "webkit", engineMajor: 17 });
    expect(browserBundleRuntime({ userAgent: "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko)" })?.engineMajor).toBe(16);
    expect(browserBundleRuntime({ userAgent: "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0 Safari/537.36" })).toBeUndefined();
    expect(browserBundleRuntime(undefined)).toBeUndefined();
  });
});
