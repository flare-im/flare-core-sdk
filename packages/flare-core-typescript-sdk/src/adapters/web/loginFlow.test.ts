import fs from "node:fs";

import { beforeAll, describe, expect, it } from "vitest";

import { LoginFlowMockBridge, operations } from "./testing/loginFlowMockBridge";
import { loadWasmRuntimeForTests, wasmPkgAvailable } from "./testing/loadWasmRuntimeForTests";
import { WebFlareImClient } from "./webFlareImClient";
import { WasmNativeBridge } from "../../bridge/wasmNativeBridge";
import { ffiContractVersion } from "../../contract/sdk_contract";
import { LifecycleEventName } from "../../model";

const requestGoldenDir = new URL(
  "../../../../../sdk-spec/golden/requests/",
  import.meta.url,
);

function readRequestGolden(name: string): Record<string, unknown> {
  return JSON.parse(
    fs.readFileSync(new URL(name, requestGoldenDir), "utf8"),
  ) as Record<string, unknown>;
}

describe("web login flow (raw SDK)", () => {
  it("keeps login request golden and session lifecycle bridge contract stable", async () => {
    const bridge = new LoginFlowMockBridge();
    const raw = new WebFlareImClient(bridge);
    const lifecycle: string[] = [];
    const loginRequest = readRequestGolden("login.json");

    raw.events.onLoginSucceeded((event) => {
      lifecycle.push(`${event.name}:${event.operation}:${event.userId ?? ""}`);
    });

    await raw.login(loginRequest as { userId: string; token: string });
    await expect(raw.sessionActive()).resolves.toBe(true);

    expect(bridge.calls).toEqual([
      { operation: "sdk.login", request: loginRequest },
      { operation: "sdk.session_active", request: undefined },
    ]);
    expect(lifecycle).toEqual([
      `${LifecycleEventName.LoginSucceeded}:sdk.login:user_001`,
    ]);
  });

  it("runs init -> subscribe -> login with provided token", async () => {
    const bridge = new LoginFlowMockBridge();
    const raw = new WebFlareImClient(bridge);

    await raw.init({
      wsUrl: "ws://127.0.0.1:50051",
      dataUrl: "idb://flare-core-web-app",
      tenantId: "0",
      httpUrl: "http://127.0.0.1:50050",
    });
    await raw.events.subscribeEvents({
      sources: ["lifecycle", "connection", "message", "conversation", "sync", "presence", "media", "capability"],
    });
    await raw.login({ userId: "hugo", token: "provided-dev-token" });
    await Promise.all([
      raw.diagnostics.getSdkVersion(),
      raw.diagnostics.getFfiContractVersion(),
      raw.diagnostics.getDataRoot(),
      raw.currentUserId(),
      raw.sessionActive(),
      raw.isConnected(),
      raw.connection.getConnectionState(),
    ]);

    const ops = operations(bridge.calls);
    expect(ops.slice(0, 3)).toEqual(["sdk.init", "event.subscribe", "sdk.login"]);
    expect(ops).toContain("diagnostics.sdk_version");
    expect(ops).toContain("diagnostics.ffi_contract_version");
    expect(ops).toContain("diagnostics.data_root");
    expect(ops).toContain("sdk.current_user_id");
    expect(ops).toContain("sdk.session_active");
    expect(ops).toContain("sdk.is_connected");
    expect(ops).toContain("connection.get_state");
  });
});

// wasm 产物由同级仓 flare-im-core-sdk 构建产出，不在本仓；缺失时整组跳过。
describe.skipIf(!wasmPkgAvailable())("web login flow (wasm integration)", () => {
  let wasmAvailable = false;
  let wasmLoadError = "";
  let runtime: Awaited<ReturnType<typeof loadWasmRuntimeForTests>> | null = null;

  beforeAll(async () => {
    try {
      runtime = await loadWasmRuntimeForTests();
      wasmAvailable = true;
    } catch (error) {
      wasmAvailable = false;
      wasmLoadError = error instanceof Error ? `${error.message}\n${error.stack ?? ""}` : String(error);
    }
  });

  it("loads wasm pkg for integration tests", () => {
    if (!wasmAvailable) {
      throw new Error(wasmLoadError || "wasm pkg unavailable");
    }
    expect(runtime).toBeTruthy();
  });


  it("wasm sdk.init accepts browser transport config through the SDK bridge", async () => {
    if (!wasmAvailable || !runtime) {
      throw new Error(wasmLoadError || "wasm pkg unavailable");
    }
    const raw = new WebFlareImClient(new WasmNativeBridge({ runtime }));
    await expect(
      raw.init({
        wsUrl: "ws://127.0.0.1:50051",
        httpUrl: "http://127.0.0.1:50050",
        tenantId: "0",
      }),
    ).resolves.toBeUndefined();
  });

  it("wasm runtime accepts generated message builder dispatch route", async () => {
    if (!wasmAvailable || !runtime) {
      throw new Error(wasmLoadError || "wasm pkg unavailable");
    }

    let outcome = "ok";
    try {
      await runtime.invoke("message_builder.dispatch", JSON.stringify({
        op: "create_text",
        conversationId: "single:alice",
        text: "hello",
      }));
    } catch (error) {
      outcome = error instanceof Error ? error.message : String(error);
    }

    expect(outcome).not.toContain("OPERATION_NOT_SUPPORTED");
    expect(outcome).not.toContain("binding operation is not implemented");
  });

  it("wasm bridge surfaces runtime login errors instead of dropping them", async () => {
    const raw = new WebFlareImClient(new WasmNativeBridge({
      runtime: {
        invoke(operation) {
          if (operation === "sdk.login") {
            throw new Error("CONNECTION_FAILED: WebSocket unavailable");
          }
          return null;
        },
        flareBindingContractVersion: () => ffiContractVersion,
      },
    }));
    await expect(
      raw.login({ userId: "hugo", token: "probe-token" }),
    ).rejects.toThrow(/CONNECTION_FAILED|sdk\.error|WebSocket/i);
  });
});
