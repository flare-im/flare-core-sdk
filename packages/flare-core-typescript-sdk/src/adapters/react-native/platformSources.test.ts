import { afterEach, describe, expect, it, vi } from "vitest";

import { DefaultFlareImClient } from "../../adapter/defaultFlareImClient";
import type { NativeBridge, NativeCallDescriptor } from "../../contract/bridge_contract";
import { PlatformLifecycle, registerPlatformLifecycleSources } from "../../lifecycle/platformLifecycle";
import { reactNativeLifecycleSources, type ReactNativeAppStateModule } from "./platformSources";

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

/** react-native's AppState, driven by hand. */
function fakeAppState(initial = "active") {
  const listeners = new Set<(state: string) => void>();
  const module: ReactNativeAppStateModule & { change(state: string): void; listeners: number } = {
    currentState: initial,
    addEventListener(_type, listener) {
      listeners.add(listener);
      return { remove: () => listeners.delete(listener) };
    },
    change(state) {
      module.currentState = state;
      for (const listener of [...listeners]) listener(state);
    },
    get listeners() {
      return listeners.size;
    },
  };
  return module;
}

/** React Native's globals: `window` is the global object itself, with no addEventListener. */
function stubReactNativeGlobals() {
  vi.stubGlobal("window", globalThis);
  vi.stubGlobal("document", undefined);
  vi.stubGlobal("navigator", { product: "ReactNative" });
}

afterEach(() => {
  registerPlatformLifecycleSources(null);
  vi.unstubAllGlobals();
});

describe("platform lifecycle under React Native", () => {
  it("lets init succeed on React Native globals even without registered sources", async () => {
    stubReactNativeGlobals();
    registerPlatformLifecycleSources(null);
    const bridge = new RecordingBridge();
    const client = new DefaultFlareImClient(bridge);

    await expect(client.init({ tenantId: "0" })).resolves.toBeUndefined();
    await flush();

    expect(bridge.calls).toEqual([{ operation: "sdk.init", request: { tenantId: "0" } }]);
  });

  it("reports AppState changes through lifecycle.setAppState", async () => {
    stubReactNativeGlobals();
    const appState = fakeAppState("active");
    registerPlatformLifecycleSources(() => reactNativeLifecycleSources(appState));
    const bridge = new RecordingBridge();
    const client = new DefaultFlareImClient(bridge);

    await client.init({ tenantId: "0" });
    await flush();
    appState.change("inactive");
    appState.change("background");
    appState.change("active");
    await flush();

    expect(bridge.lifecycleCalls()).toEqual([
      { operation: "lifecycle.set_app_state", request: { appState: "foreground" } },
      { operation: "lifecycle.set_app_state", request: { appState: "background" } },
      { operation: "lifecycle.set_app_state", request: { appState: "foreground" } },
    ]);

    await client.dispose();
    expect(appState.listeners).toBe(0);
  });

  it("has no sources when react-native cannot be loaded", () => {
    expect(reactNativeLifecycleSources(null)).toEqual({});
  });

  it("never throws from install when a source fails", async () => {
    const onError = vi.fn();
    const lifecycle = new PlatformLifecycle(
      { notifyNetworkChange: async () => undefined, setAppState: async () => undefined },
      {
        onError,
        sources: {
          appState: {
            current: () => undefined,
            subscribe: () => { throw new TypeError("addEventListener is not a function"); },
          },
        },
      },
    );

    expect(() => lifecycle.install()).not.toThrow();
    await flush();
    expect(onError).toHaveBeenCalledWith(expect.any(TypeError));
  });
});
