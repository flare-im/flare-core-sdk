/**
 * Web bundles in the Core plugin surfaces: a page whose bundle the engine offers opens in the kit's bundle host and the
 * declarative page is never read; a page the engine offers no bundle for, or whose bundle the bridge closes, draws the
 * declarative page; the session ends with the page.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, type Component } from "vue";
import { flushPromises, mount } from "@vue/test-utils";
import { FlarePluginBundleHost, FlarePluginPage } from "@flare-im/vue-ui";
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import { createPluginBundleEventHub, type PluginBundlePort } from "@flare-im/sdk/plugin-ui";
import { CorePluginPage, corePluginBundleFailed, corePluginBundleGaveUp, corePluginBundleResultData, provideCorePluginHost, resetCorePluginBundleFailures, type CorePluginBundleHost, type CorePluginPageEntry } from "../src/index";
import { fakePort } from "./support";

const root: CorePluginPageEntry = { pluginId: "sdk.plugin.task", page: "task.dashboard", title: "Tasks" };
const mounted: Array<{ unmount(): void }> = [];
afterEach(() => { mounted.splice(0).forEach((wrapper) => wrapper.unmount()); resetCorePluginBundleFailures(); });

function bundlePort(open: PluginBundlePort["pluginBundleOpen"]): PluginBundlePort {
  return {
    pluginBundleOpen: vi.fn(open),
    pluginBundleBridge: vi.fn(async () => ({ envelope: "{}" })),
    pluginBundleHostResult: vi.fn(async () => ({ envelope: "{}" })),
    pluginBundleHostEvent: vi.fn(async () => ({ deliveries: [] })),
    pluginBundleClose: vi.fn(async () => ({ closed: true })),
  };
}

function render(bundles: CorePluginBundleHost) {
  const port = { ...fakePort(), pluginPage: vi.fn(async () => ({ available: true, title: "Tasks", fields: [], actions: [] })) };
  const Host = defineComponent({ setup() {
    provideCorePluginHost({ bundles });
    return () => h(CorePluginPage as Component, { root, port, platform: "web", loadFailedText: "failed" });
  } });
  const wrapper = mount(defineComponent({ setup() { useFlareI18nProvider("en-US"); return () => h(Host as Component); } }));
  mounted.push(wrapper);
  return { wrapper, port };
}

const opened = { sessionId: "s1", origin: "null", root: "https://plugin-sandbox.example.com/b/abc/", entry: "index.html", csp: "", hello: {} };

describe("CorePluginPage with web bundles", () => {
  it("opens the bundle the engine offers and never reads the declarative page", async () => {
    const port = bundlePort(async () => opened);
    const { wrapper, port: pagePort } = render({ port, events: createPluginBundleEventHub(), theme: () => ({ mode: "light" }) });
    await flushPromises();
    expect(port.pluginBundleOpen).toHaveBeenCalledWith(expect.objectContaining({ pluginId: "sdk.plugin.task", contributionId: "task.dashboard", presentation: "page" }));
    const host = wrapper.getComponent(FlarePluginBundleHost);
    expect(host.props("files")).toBe("https://plugin-sandbox.example.com/b/abc/");
    expect(pagePort.pluginPage).not.toHaveBeenCalled();
    wrapper.unmount();
    expect(port.pluginBundleClose).toHaveBeenCalledWith({ sessionId: "s1" });
  });

  it("draws the declarative page when no bundle is offered", async () => {
    const port = bundlePort(async () => { throw new Error("sdk.plugin_bundle.not_offered"); });
    const { wrapper, port: pagePort } = render({ port, events: createPluginBundleEventHub(), theme: () => ({ mode: "light" }) });
    await flushPromises();
    expect(wrapper.findComponent(FlarePluginPage).exists()).toBe(true);
    expect(pagePort.pluginPage).toHaveBeenCalledTimes(1);
  });

  it("falls back when the bridge closes the page", async () => {
    const events = createPluginBundleEventHub();
    const port = bundlePort(async () => opened);
    const { wrapper, port: pagePort } = render({ port, events, theme: () => ({ mode: "dark" }) });
    await flushPromises();
    expect(events.announce({ sessionId: "s1", close: "withdrawn" })).toBe(true);
    await flushPromises();
    expect(wrapper.findComponent(FlarePluginPage).exists()).toBe(true);
    expect(pagePort.pluginPage).toHaveBeenCalledTimes(1);
  });
});

describe("bundle failure budget", () => {
  it("gives up after three failures in a session", () => {
    expect(corePluginBundleFailed("a")).toBe(false);
    expect(corePluginBundleFailed("a")).toBe(false);
    expect(corePluginBundleFailed("a")).toBe(true);
    expect(corePluginBundleGaveUp("a")).toBe(true);
    expect(corePluginBundleGaveUp("b")).toBe(false);
  });

  it("reads a form's close result", () => {
    expect(corePluginBundleResultData({ operationResult: { data: { posted: 1 } } })).toEqual({ posted: 1 });
    expect(corePluginBundleResultData({ data: { posted: 2 } })).toEqual({ posted: 2 });
    expect(corePluginBundleResultData("x")).toBe("x");
  });
});
