/**
 * Web bundles in the Core plugin surfaces: a page whose view carries the engine's bundle marker opens in the kit's
 * bundle host; a page without it draws the declarative page and never tries a bundle; a bundle the bridge closes or the
 * engine fails to open falls back to the view already read; the session ends with the page.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { defineComponent, h, type Component } from "vue";
import { flushPromises, mount } from "@vue/test-utils";
import { FlarePluginBundleHost, FlarePluginPage, FlarePluginView } from "@flare-im/vue-ui";
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import { createPluginBundleEventHub, type PluginBundlePort } from "@flare-im/sdk/plugin-ui";
import { CorePluginMessage, CorePluginPage, PluginComposerSheet, corePluginBundleFailed, corePluginBundleGaveUp, corePluginBundleResultData, provideCorePluginHost, resetCorePluginBundleFailures, type CorePluginBundleHost, type CorePluginPageEntry, type CorePluginUiOptions } from "../src/index";
import { cardContent, fakePort, mountWithSession, unmountAll } from "./support";

const root: CorePluginPageEntry = { pluginId: "sdk.plugin.task", page: "task.dashboard", title: "Tasks" };
const mounted: Array<{ unmount(): void }> = [];
afterEach(() => { mounted.splice(0).forEach((wrapper) => wrapper.unmount()); unmountAll(); resetCorePluginBundleFailures(); });

function bundlePort(open: PluginBundlePort["pluginBundleOpen"]): PluginBundlePort {
  return {
    pluginBundleOpen: vi.fn(open),
    pluginBundleBridge: vi.fn(async () => ({ envelope: "{}" })),
    pluginBundleHostResult: vi.fn(async () => ({ envelope: "{}" })),
    pluginBundleHostEvent: vi.fn(async () => ({ deliveries: [] })),
    pluginBundleClose: vi.fn(async () => ({ closed: true })),
  };
}

function render(bundles: CorePluginBundleHost, bundle = true) {
  const port = { ...fakePort(), pluginPage: vi.fn(async () => ({ available: true, title: "Tasks", fields: [], actions: [], ...(bundle ? { bundle: true } : {}) })) };
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
  it("opens the bundle the page view marks as offered", async () => {
    const port = bundlePort(async () => opened);
    const { wrapper, port: pagePort } = render({ port, events: createPluginBundleEventHub(), theme: () => ({ mode: "light" }) });
    await flushPromises();
    expect(port.pluginBundleOpen).toHaveBeenCalledWith(expect.objectContaining({ pluginId: "sdk.plugin.task", contributionId: "task.dashboard", presentation: "page" }));
    const host = wrapper.getComponent(FlarePluginBundleHost);
    expect(host.props("files")).toBe("https://plugin-sandbox.example.com/b/abc/");
    expect(pagePort.pluginPage).toHaveBeenCalledTimes(1);
    wrapper.unmount();
    expect(port.pluginBundleClose).toHaveBeenCalledWith({ sessionId: "s1" });
  });

  it("draws the declarative page without trying a bundle when the view has no marker", async () => {
    const port = bundlePort(async () => opened);
    const { wrapper, port: pagePort } = render({ port, events: createPluginBundleEventHub(), theme: () => ({ mode: "light" }) }, false);
    await flushPromises();
    expect(wrapper.findComponent(FlarePluginPage).exists()).toBe(true);
    expect(wrapper.findComponent(FlarePluginBundleHost).exists()).toBe(false);
    expect(port.pluginBundleOpen).not.toHaveBeenCalled();
    expect(pagePort.pluginPage).toHaveBeenCalledTimes(1);
  });

  it("falls back to the view already read when the open fails", async () => {
    const port = bundlePort(async () => { throw new Error("sdk.plugin_bundle.unavailable"); });
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

describe("forms and card details with web bundles", () => {
  const bundles = () => ({ port: bundlePort(async () => opened), events: createPluginBundleEventHub(), theme: () => ({ mode: "light" as const }) });
  const item = { id: "plugin:acme.task.create", kind: "plugin" as const, pluginId: "acme.task", contributionId: "acme.task.create", label: "Task", order: 1 };
  const form = (bundle: boolean) => ({ available: true, title: "New task", fields: [], actions: [], stateVersion: 0, ...(bundle ? { bundle: true } : {}) });

  it("tries a bundle for a '+' form only when its presented view is marked", async () => {
    for (const marked of [true, false]) {
      const host = bundles();
      const port = fakePort({ presentMessage: vi.fn(async () => form(marked)) });
      const { wrapper } = mountWithSession(port, () => h(PluginComposerSheet, { item, conversationId: "group-1" }), undefined, { plugin: { bundles: host } });
      await flushPromises();
      expect(port.presentMessage).toHaveBeenCalledTimes(1);
      expect(host.port.pluginBundleOpen).toHaveBeenCalledTimes(marked ? 1 : 0);
      expect(wrapper.findComponent(FlarePluginBundleHost).exists()).toBe(marked);
    }
  });

  it("opens a card's 'view all' as a bundle only when the card is marked", async () => {
    const envelope = { pluginId: "acme.poll", contributionId: "acme.poll.card", schemaVersion: 1, summary: "Lunch?", payload: {} };
    for (const marked of [true, false]) {
      const host = bundles();
      const port = fakePort({ presentMessage: vi.fn(async () => ({ available: true, title: "Lunch?", fields: [], actions: [], detail: true, stateVersion: 1, ...(marked ? { bundle: true } : {}) })),
        pluginDetail: vi.fn(async () => ({ available: true, title: "All", fields: [], actions: [] })) });
      const { wrapper } = mountWithSession(port, () => h(CorePluginMessage, { content: cardContent(envelope), messageId: "srv-1" }), undefined, { plugin: { bundles: host } });
      await flushPromises();
      wrapper.getComponent(FlarePluginView).vm.$emit("openDetail");
      await flushPromises();
      expect(host.port.pluginBundleOpen).toHaveBeenCalledTimes(marked ? 1 : 0);
      expect(port.pluginDetail).toHaveBeenCalledTimes(marked ? 0 : 1);
    }
  });

  const pollCard = { pluginId: "acme.poll", contributionId: "acme.poll.card", schemaVersion: 1, summary: "Lunch?", payload: {} };
  const markedPort = () => fakePort({ presentMessage: vi.fn(async () => ({ available: true, title: "Lunch?", fields: [], actions: [], detail: true, stateVersion: 1, bundle: true })) });

  it("tells a card's detail bundle the conversation type the host provided, and an empty one without it", async () => {
    const cases: Array<[CorePluginUiOptions["conversationType"], string]> = [["group", "group"], [() => "single", "single"], [undefined, ""]];
    for (const [conversationType, expected] of cases) {
      const host = bundles();
      const { wrapper } = mountWithSession(markedPort(), () => h(CorePluginMessage, { content: cardContent(pollCard), messageId: "srv-1" }), undefined,
        { plugin: { bundles: host }, options: conversationType ? { conversationType } : {} });
      await flushPromises();
      wrapper.getComponent(FlarePluginView).vm.$emit("openDetail");
      await flushPromises();
      expect(host.port.pluginBundleOpen).toHaveBeenCalledWith(expect.objectContaining({
        presentation: "detail", conversation: { id: "conv-1", type: expected },
      }));
    }
  });

  it("hands a detail bundle's navigation to a page to the host's openPage, and keeps the sheet open", async () => {
    const opened: CorePluginPageEntry[] = [];
    const host = bundles();
    const { wrapper } = mountWithSession(markedPort(), () => h(CorePluginMessage, { content: cardContent(pollCard), messageId: "srv-1" }), undefined,
      { plugin: { bundles: host }, options: { openPage: (entry) => opened.push(entry) } });
    await flushPromises();
    wrapper.getComponent(FlarePluginView).vm.$emit("openDetail");
    await flushPromises();
    const frame = wrapper.getComponent(FlarePluginBundleHost);
    frame.vm.$emit("navigate", { page: "acme.poll.results", arguments: { pollId: "p1" } });
    frame.vm.$emit("navigate", { bundleRoute: "/inner" });
    await flushPromises();
    expect(opened).toEqual([{ pluginId: "acme.poll", page: "acme.poll.results", title: "", args: { pollId: "p1" }, conversationId: "conv-1" }]);
    expect(wrapper.findComponent(FlarePluginBundleHost).exists()).toBe(true);
  });

  it("leaves a detail bundle's navigation unanswered without openPage, as before", async () => {
    const host = bundles();
    const { wrapper } = mountWithSession(markedPort(), () => h(CorePluginMessage, { content: cardContent(pollCard), messageId: "srv-1" }), undefined,
      { plugin: { bundles: host } });
    await flushPromises();
    wrapper.getComponent(FlarePluginView).vm.$emit("openDetail");
    await flushPromises();
    expect(() => wrapper.getComponent(FlarePluginBundleHost).vm.$emit("navigate", { page: "acme.poll.results" })).not.toThrow();
    expect(wrapper.findComponent(FlarePluginBundleHost).exists()).toBe(true);
  });
});
