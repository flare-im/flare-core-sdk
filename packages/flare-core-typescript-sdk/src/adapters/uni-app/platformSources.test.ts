import { afterEach, describe, expect, it, vi } from "vitest";

import { DefaultFlareImClient } from "../../adapter/defaultFlareImClient";
import type { NativeBridge, NativeCallDescriptor } from "../../contract/bridge_contract";
import { registerPlatformLifecycleSources } from "../../lifecycle/platformLifecycle";
import { uniLifecycleSources, type UniLifecycleApi } from "./platformSources";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

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

/** The `uni` app and network events, driven by hand. */
function fakeUni(networkType = "wifi") {
  const show = new Set<() => void>();
  const hide = new Set<() => void>();
  const network = new Set<(status: { isConnected?: boolean; networkType?: string }) => void>();
  const uni: UniLifecycleApi & {
    emitShow(): void;
    emitHide(): void;
    emitNetwork(isConnected: boolean, type: string): void;
    listeners(): number;
  } = {
    onAppShow: (listener) => void show.add(listener),
    offAppShow: (listener) => void show.delete(listener),
    onAppHide: (listener) => void hide.add(listener),
    offAppHide: (listener) => void hide.delete(listener),
    onNetworkStatusChange: (listener) => void network.add(listener),
    offNetworkStatusChange: (listener) => void network.delete(listener),
    getNetworkType: ({ success }) => success?.({ networkType }),
    emitShow: () => show.forEach((listener) => listener()),
    emitHide: () => hide.forEach((listener) => listener()),
    emitNetwork: (isConnected, type) => network.forEach((listener) => listener({ isConnected, networkType: type })),
    listeners: () => show.size + hide.size + network.size,
  };
  return uni;
}

afterEach(() => {
  registerPlatformLifecycleSources(null);
  vi.unstubAllGlobals();
});

describe("platform lifecycle under uni-app", () => {
  it("reports uni app and network events", async () => {
    vi.stubGlobal("window", undefined);
    vi.stubGlobal("document", undefined);
    const uni = fakeUni("wifi");
    registerPlatformLifecycleSources(() => uniLifecycleSources(uni));
    const bridge = new RecordingBridge();
    const client = new DefaultFlareImClient(bridge);

    await client.init({ tenantId: "0" });
    await flush();
    uni.emitHide();
    uni.emitNetwork(true, "4g");
    uni.emitNetwork(false, "none");
    uni.emitShow();
    await flush();

    expect(bridge.lifecycleCalls()).toEqual([
      {
        operation: "connection.notify_network_change",
        request: { available: true, reason: "initial", interface: "wifi", fingerprintHint: "wifi" },
      },
      { operation: "lifecycle.set_app_state", request: { appState: "background" } },
      {
        operation: "connection.notify_network_change",
        request: { available: true, reason: "network_status_change", interface: "cellular", fingerprintHint: "4g" },
      },
      {
        operation: "connection.notify_network_change",
        request: { available: false, reason: "network_status_change", interface: "unknown", fingerprintHint: "none" },
      },
      { operation: "lifecycle.set_app_state", request: { appState: "foreground" } },
    ]);

    await client.dispose();
    expect(uni.listeners()).toBe(0);
  });

  it("falls back to the browser sources for what uni does not offer", () => {
    vi.stubGlobal("window", undefined);
    vi.stubGlobal("document", undefined);
    expect(uniLifecycleSources({})).toEqual({});
    const onlyNetwork = uniLifecycleSources({ onNetworkStatusChange: () => undefined });
    expect(onlyNetwork.appState).toBeUndefined();
    expect(onlyNetwork.network).toBeDefined();
  });
});
