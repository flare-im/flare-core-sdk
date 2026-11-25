import { describe, expect, it, vi } from "vitest";

import { NativeCallMap, type ConnectTokenRefresher } from "../../contract/bridge_contract";
import { ffiContractVersion } from "../../contract/sdk_contract";
import { WasmNativeBridge } from "../../bridge/wasmNativeBridge";
import {
  FlareSdkException,
  NetworkUncertainError,
  OverloadedError,
  UpgradeRequiredError,
  createSdkException,
} from "../../bridge/flareSdkException";
import type { ConnectionStatus } from "../../model";
import { WebFlareImClient } from "./webFlareImClient";
import { withWebAppInfo } from "../../lifecycle";
import { WebProductionBridge } from "./webProductionBridge";

function storageHostStub() {
  return {
    loadSnapshot: async () => "{}",
    saveMessage: async () => {},
    saveConversation: async () => {},
    saveCursor: async () => {},
    commitOutgoing: async () => {},
    savePendingSend: async () => {},
    deleteMessage: async () => {},
    deleteConversation: async () => {},
    deletePendingSend: async () => {},
  };
}

function fakeRuntime(invoke: (op: string, json: string) => unknown = () => null) {
  const steps: string[] = [];
  let eventCallback: ((event: unknown) => void) | null = null;
  const runtime = {
    steps,
    refresher: undefined as ConnectTokenRefresher | undefined,
    requests: new Map<string, unknown>(),
    emit: (event: unknown) => eventCallback?.(event),
    invoke: vi.fn(async (op: string, json: string) => {
      steps.push(op);
      runtime.requests.set(op, JSON.parse(json));
      return invoke(op, json);
    }),
    flareBindingContractVersion: () => ffiContractVersion,
    dispose: vi.fn(),
    setEventCallback: vi.fn((cb: ((event: unknown) => void) | null) => { eventCallback = cb; }),
    setStorageHost: vi.fn(() => void steps.push("setStorageHost")),
    setConnectTokenRefresher: vi.fn(async (refresher: ConnectTokenRefresher | undefined) => {
      runtime.refresher = refresher;
    }),
  };
  return runtime;
}

function webClient(runtime: ReturnType<typeof fakeRuntime>, appInfo = {}) {
  const bridge = new WebProductionBridge({
    loadRuntime: async () => ({ runtime: runtime as never }),
    createStorageHost: () => storageHostStub() as never,
    appInfo,
  });
  return { client: new WebFlareImClient(bridge) };
}

describe("WebProductionBridge link wiring", () => {
  it("installs the message storage host before the first runtime call", async () => {
    const runtime = fakeRuntime();
    const { client } = webClient(runtime);

    await client.init({ tenantId: "0", installPlatformLifecycle: false });

    expect(runtime.steps).toEqual(["setStorageHost", "sdk.init"]);
  });

  it("fills the app keys the host left out from the build-time identity", async () => {
    const runtime = fakeRuntime();
    const { client } = webClient(runtime, { version: "3.2.1", build: 30201 });

    await client.init({ tenantId: "0", installPlatformLifecycle: false });
    expect(runtime.requests.get("sdk.init")).toEqual({ tenantId: "0", app: { version: "3.2.1", build: 30201 } });

    await client.init({ app: { channel: "stable" }, installPlatformLifecycle: false });
    expect(runtime.requests.get("sdk.init")).toEqual({ app: { channel: "stable", version: "3.2.1", build: 30201 } });

    await client.init({ app: { version: "9.9.9", channel: "beta" }, installPlatformLifecycle: false });
    expect(runtime.requests.get("sdk.init")).toEqual({ app: { version: "9.9.9", channel: "beta", build: 30201 } });
  });

  it("adds no app without build-time identity, and handles the wrapped init shape", () => {
    expect(withWebAppInfo({ tenantId: "0" }, {})).toEqual({ tenantId: "0" });
    expect(withWebAppInfo({ environment: "development", sdkConfig: { tenantId: "0" } }, { version: "1.0.0" }))
      .toEqual({ environment: "development", sdkConfig: { tenantId: "0", app: { version: "1.0.0" } } });
  });

  it("fills the update center's app keys the host left out", () => {
    const info = { channel: "beta", buildId: "20261105-abc", locale: "en-US", target: "darwin-aarch64" };
    expect(withWebAppInfo({ tenantId: "0" }, info)).toEqual({ tenantId: "0", app: info });
    expect(withWebAppInfo({ app: { locale: "zh-CN" } }, info)).toEqual({ app: { ...info, locale: "zh-CN" } });
  });

  it("hands connection://status to the host as a ConnectionStatus", async () => {
    const runtime = fakeRuntime();
    const { client } = webClient(runtime);
    const statuses: ConnectionStatus[] = [];
    client.events.onConnectionStatusChanged((status) => statuses.push(status));
    await client.events.subscribeEvents({});

    runtime.emit({
      channel: "connection://status",
      payload: {
        phase: "reconnecting", quality: null, endpointRevision: 1,
        protocol: "quic", rttMs: null, attempt: 2, nextRetryAt: 1_762_250_000_000, reason: null,
        developmentMode: false,
      },
    });

    expect(statuses).toEqual([{
      phase: "reconnecting",
      endpointRevision: 1,
      protocol: "quic",
      attempt: 2,
      nextRetryAt: 1_762_250_000_000,
      developmentMode: false,
    }]);
  });

  it("passes the page's refresher straight to the runtime and removes it with null", async () => {
    const runtime = fakeRuntime();
    const { client } = webClient(runtime);
    const refresher = vi.fn(async () => "fresh-token");

    await client.setConnectTokenRefresher(refresher);
    expect(runtime.refresher).toBe(refresher);
    await expect(runtime.refresher?.()).resolves.toBe("fresh-token");

    await client.setConnectTokenRefresher(null);
    expect(runtime.refresher).toBeUndefined();
    expect("completeConnectTokenRefresh" in client).toBe(false);
  });

  it("refuses the bridge-level complete operation: the runtime calls the refresher itself", async () => {
    const bridge = new WebProductionBridge({
      loadRuntime: async () => ({ runtime: fakeRuntime() as never }),
      createStorageHost: () => storageHostStub() as never,
    });
    await expect(bridge.invoke(NativeCallMap.sdkCompleteConnectTokenRefresh, { requestId: 1, token: "t" }))
      .rejects.toMatchObject({ code: "capabilityUnavailable" });
  });

  it("surfaces typed errors from the runtime", async () => {
    const runtime = fakeRuntime((op) => {
      if (op === "connection.get_status") throw Object.assign(new Error("upgrade"), { code: "UPGRADE_REQUIRED" });
      if (op === "connection.reconnect_now") throw Object.assign(new Error("uncertain"), { code: "NETWORK_UNCERTAIN" });
      return null;
    });
    const { client } = webClient(runtime);

    await expect(client.connection.getStatus()).rejects.toBeInstanceOf(UpgradeRequiredError);
    await expect(client.connection.reconnectNow()).rejects.toBeInstanceOf(NetworkUncertainError);
  });

  it("forwards the host function to the runtime hook", async () => {
    const runtime = fakeRuntime();
    const bridge = new WasmNativeBridge({ runtime: runtime as never });
    const refresher = async () => null;

    await bridge.setConnectTokenRefresher(refresher);
    expect(runtime.refresher).toBe(refresher);
    await bridge.setConnectTokenRefresher(null);
    expect(runtime.refresher).toBeUndefined();
  });

  it("reports capabilityUnavailable on a runtime without the hook", async () => {
    const bridge = new WasmNativeBridge({
      runtime: { invoke: () => null, flareBindingContractVersion: () => ffiContractVersion },
    });
    await expect(bridge.setConnectTokenRefresher(async () => "t"))
      .rejects.toMatchObject({ code: "capabilityUnavailable" });
  });
});

describe("typed SDK errors", () => {
  it("maps the three link error codes to their classes and keeps the rest generic", () => {
    const overloaded = createSdkException("OVERLOADED", "busy", "connection.get_status", { retryAfterMs: "2500" });
    expect(overloaded).toBeInstanceOf(OverloadedError);
    expect(overloaded).toBeInstanceOf(FlareSdkException);
    expect((overloaded as OverloadedError).retryAfterMs).toBe(2500);
    expect(createSdkException("upgradeRequired", "old")).toBeInstanceOf(UpgradeRequiredError);
    expect(createSdkException("networkUncertain", "?")).toBeInstanceOf(NetworkUncertainError);

    const generic = createSdkException("PERMISSION_DENIED", "no");
    expect(generic).toBeInstanceOf(FlareSdkException);
    expect(generic).not.toBeInstanceOf(OverloadedError);
  });

  it("builds the typed error from a binding rejection", () => {
    const error = FlareSdkException.fromBindingError(
      { code: "OVERLOADED", message: "busy", retryable: true },
      NativeCallMap.connectionGetStatus.operation,
    );
    expect(error).toBeInstanceOf(OverloadedError);
    expect(error).toMatchObject({ code: "OVERLOADED", retryable: true, operation: "connection.get_status" });
    expect((error as OverloadedError).retryAfterMs).toBeUndefined();
  });
});
