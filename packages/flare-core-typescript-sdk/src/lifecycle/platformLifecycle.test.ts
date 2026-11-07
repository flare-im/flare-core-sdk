import { afterEach, describe, expect, it, vi } from "vitest";

import { DefaultFlareImClient } from "../adapter/defaultFlareImClient";
import type { NativeBridge, NativeCallDescriptor } from "../contract/bridge_contract";
import { AppState } from "../model/app_state";
import { NetworkInterfaceKind } from "../model/network_interface_kind";
import { PlatformLifecycle, type PlatformLifecycleReports } from "./platformLifecycle";

/** A browser-like event source whose listeners the test fires by hand. */
class FakeTarget {
  private readonly listeners = new Map<string, Set<() => void>>();

  addEventListener(type: string, listener: () => void): void {
    const bucket = this.listeners.get(type) ?? new Set();
    bucket.add(listener);
    this.listeners.set(type, bucket);
  }

  removeEventListener(type: string, listener: () => void): void {
    this.listeners.get(type)?.delete(listener);
  }

  fire(type: string): void {
    for (const listener of [...(this.listeners.get(type) ?? [])]) listener();
  }

  count(): number {
    let total = 0;
    for (const bucket of this.listeners.values()) total += bucket.size;
    return total;
  }
}

class FakeDocument extends FakeTarget {
  visibilityState = "visible";
}

class FakeConnection extends FakeTarget {
  type = "wifi";
}

function browser() {
  const window = new FakeTarget();
  const document = new FakeDocument();
  const connection = new FakeConnection();
  const navigator = { onLine: true, connection };
  return { window, document, connection, navigator };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

/** Records what the generated client sends to the native layer. */
class RecordingBridge implements NativeBridge {
  readonly calls: Array<{ operation: string; request?: unknown }> = [];

  async invoke<T>(descriptor: NativeCallDescriptor, request?: unknown): Promise<T> {
    this.calls.push({ operation: descriptor.operation, request });
    return undefined as T;
  }

  lifecycleCalls() {
    return this.calls.filter((call) =>
      call.operation === "connection.notify_network_change" || call.operation === "lifecycle.set_app_state");
  }
}

function recordingClient() {
  const calls: Array<[string, unknown]> = [];
  const client: PlatformLifecycleReports = {
    notifyNetworkChange: async (request) => void calls.push(["network", request]),
    setAppState: async (request) => void calls.push(["appState", request.appState]),
  };
  return { client, calls };
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("PlatformLifecycle", () => {
  it("reports the current network and app state once when installed", async () => {
    const page = browser();
    const { client, calls } = recordingClient();

    new PlatformLifecycle(client, page).install();
    await flush();

    expect(calls).toEqual([
      ["network", {
        available: true,
        reason: "initial",
        interface: NetworkInterfaceKind.Wifi,
        fingerprintHint: "wifi",
      }],
      ["appState", AppState.Foreground],
    ]);
  });

  it("forwards network and visibility changes and drops repeats of the same state", async () => {
    const page = browser();
    const { client, calls } = recordingClient();
    new PlatformLifecycle(client, page).install();
    await flush();
    calls.length = 0;

    page.navigator.onLine = false;
    page.window.fire("offline");
    page.window.fire("offline");
    page.navigator.onLine = true;
    page.window.fire("online");
    page.connection.fire("change");
    page.connection.type = "cellular";
    page.connection.fire("change");
    page.document.visibilityState = "hidden";
    page.document.fire("visibilitychange");
    page.window.fire("pagehide");
    page.document.visibilityState = "visible";
    page.window.fire("pageshow");
    await flush();

    expect(calls).toEqual([
      ["network", { available: false, reason: "offline", interface: NetworkInterfaceKind.Wifi, fingerprintHint: "wifi" }],
      ["network", { available: true, reason: "online", interface: NetworkInterfaceKind.Wifi, fingerprintHint: "wifi" }],
      ["network", {
        available: true,
        reason: "connection_change",
        interface: NetworkInterfaceKind.Cellular,
        fingerprintHint: "cellular",
      }],
      ["appState", AppState.Background],
      ["appState", AppState.Foreground],
    ]);
  });

  it("reports no interface or hint where the browser has no Network Information API", async () => {
    const page = browser();
    const { client, calls } = recordingClient();
    new PlatformLifecycle(client, { ...page, navigator: { onLine: true } }).install();
    await flush();

    expect(calls[0]).toEqual(["network", { available: true, reason: "initial" }]);
  });

  it("is inert without browser globals and swallows rejected reports", async () => {
    const onError = vi.fn();
    const failing: PlatformLifecycleReports = {
      notifyNetworkChange: async () => { throw new Error("not initialized"); },
      setAppState: async () => { throw new Error("not initialized"); },
    };

    const inert = new PlatformLifecycle(failing, { window: null, document: null, navigator: null, onError });
    expect(inert.active).toBe(false);
    inert.install();
    await flush();
    expect(onError).not.toHaveBeenCalled();

    const page = browser();
    new PlatformLifecycle(failing, { ...page, onError }).install();
    await flush();
    expect(onError).toHaveBeenCalledTimes(2);
  });

  it("removes every listener on dispose", async () => {
    const page = browser();
    const { client, calls } = recordingClient();
    const lifecycle = new PlatformLifecycle(client, page).install();
    await flush();
    expect(page.window.count() + page.document.count() + page.connection.count()).toBe(6);

    lifecycle.dispose();
    page.window.fire("offline");
    await flush();

    expect(page.window.count() + page.document.count() + page.connection.count()).toBe(0);
    expect(calls).toHaveLength(2);
  });
});

describe("client.init installs the platform lifecycle", () => {
  function stubBrowser() {
    const page = browser();
    vi.stubGlobal("window", page.window);
    vi.stubGlobal("document", page.document);
    vi.stubGlobal("navigator", page.navigator);
    return page;
  }

  it("installs it after a successful init and removes it on dispose", async () => {
    const page = stubBrowser();
    const bridge = new RecordingBridge();
    const client = new DefaultFlareImClient(bridge);

    await client.init({ tenantId: "0" });
    await flush();

    expect(bridge.calls[0]).toEqual({ operation: "sdk.init", request: { tenantId: "0" } });
    expect(bridge.lifecycleCalls()).toEqual([
      {
        operation: "connection.notify_network_change",
        request: { available: true, reason: "initial", interface: "wifi", fingerprintHint: "wifi" },
      },
      { operation: "lifecycle.set_app_state", request: { appState: "foreground" } },
    ]);

    page.document.visibilityState = "hidden";
    page.document.fire("visibilitychange");
    await flush();
    expect(bridge.lifecycleCalls().at(-1)).toEqual({
      operation: "lifecycle.set_app_state",
      request: { appState: "background" },
    });

    await client.dispose();
    expect(page.window.count() + page.document.count() + page.connection.count()).toBe(0);
  });

  it("replaces the previous one when init runs again", async () => {
    const page = stubBrowser();
    const client = new DefaultFlareImClient(new RecordingBridge());

    await client.init({});
    await client.init({});

    expect(page.window.count() + page.document.count() + page.connection.count()).toBe(6);
  });

  it("is not installed when init turns it off, and the flag never reaches the core", async () => {
    const page = stubBrowser();
    const bridge = new RecordingBridge();
    const client = new DefaultFlareImClient(bridge);

    await client.init({ tenantId: "0", installPlatformLifecycle: false });
    await flush();

    expect(bridge.calls).toEqual([{ operation: "sdk.init", request: { tenantId: "0" } }]);
    expect(page.window.count() + page.document.count() + page.connection.count()).toBe(0);
  });

  it("is not installed when init fails", async () => {
    const page = stubBrowser();
    const client = new DefaultFlareImClient({
      invoke: async () => { throw new Error("CONFIGURATION_ERROR"); },
    });

    await expect(client.init({})).rejects.toThrow("CONFIGURATION_ERROR");
    expect(page.window.count() + page.document.count() + page.connection.count()).toBe(0);
  });
});
