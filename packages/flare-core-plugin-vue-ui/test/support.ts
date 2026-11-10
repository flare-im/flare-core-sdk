import { vi } from "vitest";
import { defineComponent, h, shallowRef, type Component } from "vue";
import { mount } from "@vue/test-utils";
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import { PluginUiSession, type PluginMessageEnvelope, type PluginUiPort } from "@flare-im/sdk/plugin-ui";
import {
  provideCorePluginDirectory, provideCorePluginUi, type CorePluginDirectory, type CorePluginErrorText, type CorePluginStateChange,
} from "../src/index";

type Call = (request: Record<string, unknown>) => Promise<unknown>;
/** A port whose calls the test answers (each a spy over the given implementation). */
export function fakePort(overrides: Partial<Record<"presentMessage" | "invokeAction" | "invokePageAction" | "pluginDetail", Call>> = {}) {
  return {
    catalog: vi.fn(async (): Promise<unknown> => ({})),
    resolveMessage: vi.fn(async (): Promise<unknown> => ({})),
    action: vi.fn(async (): Promise<unknown> => ({})),
    dispatch: vi.fn(async (): Promise<unknown> => ({})),
    uploadFile: vi.fn(async (_request: import("@flare-im/sdk/plugin-ui").PluginFileUploadRequest) => ({ fileId: "test-file" })),
    presentMessage: vi.fn<Call>(overrides.presentMessage ?? (async () => ({ available: false, title: "", fields: [], actions: [], stateVersion: 0 }))),
    invokeAction: vi.fn<Call>(overrides.invokeAction ?? (async () => ({ kind: "operation", response: { success: true, data: {} } }))),
    invokePageAction: vi.fn<Call>(overrides.invokePageAction ?? (async () => ({ kind: "operation", response: { success: true, data: {} } }))),
    pluginDetail: vi.fn<Call>(overrides.pluginDetail ?? (async () => ({ available: true, title: "", fields: [], actions: [] }))),
  } satisfies PluginUiPort;
}
export type FakePort = ReturnType<typeof fakePort>;

/** A timeline row's content: the envelope as the custom element's UTF-8 payload bytes. */
export function cardContent(envelope: PluginMessageEnvelope): Record<string, unknown> {
  return { description: envelope.summary, payload: Array.from(new TextEncoder().encode(JSON.stringify(envelope))) };
}

/** A promise the test settles. */
export function deferred<T>() {
  let resolve!: (value: T) => void, reject!: (error: unknown) => void;
  const promise = new Promise<T>((ok, fail) => { resolve = ok; reject = fail; });
  return { promise, resolve, reject };
}

const mounted: Array<{ unmount(): void }> = [];
export function unmountAll(): void { mounted.splice(0).forEach((wrapper) => wrapper.unmount()); }

/** The host's side of the SDK's `onMessagePluginStateChanged`: the test announces a message, cards listening hear it. */
export function stateFeed() {
  const listeners = new Set<(change: CorePluginStateChange) => void>();
  return {
    subscribe: (listener: (change: CorePluginStateChange) => void) => { listeners.add(listener); return () => { listeners.delete(listener); }; },
    announce: (messageId: string) => { for (const listener of [...listeners]) listener({ messageId, conversationId: "conv-1" }); },
    listening: () => listeners.size,
  };
}

/** Mounts `child` under the kit i18n provider and the Core plugin UI over `port`. */
export function mountWithSession(port: PluginUiPort, child: () => ReturnType<typeof h>, directory?: CorePluginDirectory,
  host: { feed?: ReturnType<typeof stateFeed>; errorText?: CorePluginErrorText } = {}) {
  const session = shallowRef<PluginUiSession | null>(new PluginUiSession(port, "web", () => "en-US"));
  const feed = host.feed ?? stateFeed();
  const Host = defineComponent({ setup() {
    provideCorePluginUi(session, { conversationId: () => "conv-1", stateChanges: feed.subscribe, errorText: host.errorText });
    if (directory) provideCorePluginDirectory(directory);
    return child;
  } });
  const wrapper = mount(defineComponent({ setup() { useFlareI18nProvider("en-US"); return () => h(Host as Component); } }));
  mounted.push(wrapper);
  return { wrapper, session, feed };
}
