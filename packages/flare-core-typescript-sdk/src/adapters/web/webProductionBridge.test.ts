import { describe, expect, it, vi } from "vitest";

import { WebProductionBridge, invokeTimeoutMs } from "./webProductionBridge";

describe("invokeTimeoutMs 发送路径超时", () => {
  it("send 路径的消息构建 message_builder.* 与发送同档 30s，不落 12s 默认死线", () => {
    // 线上缺陷：巨型会话历史回填占住单槽时，message_builder.dispatch(dispatchTypedBuild)
    // 12s 就被误判超时；它是发送路径的一部分，应与 message.send 同档。
    expect(invokeTimeoutMs("message_builder.dispatch")).toBe(30_000);
    expect(invokeTimeoutMs("message_builder.create_text")).toBe(30_000);
    expect(invokeTimeoutMs("message.send")).toBe(30_000);
    expect(invokeTimeoutMs("message.build_and_send")).toBe(30_000);
  });

  it("其它操作超时不受影响", () => {
    expect(invokeTimeoutMs("message.typing")).toBe(1_500);
    expect(invokeTimeoutMs("conversation.update_draft")).toBe(5_000);
    expect(invokeTimeoutMs("sync.messages")).toBe(8_000);
    expect(invokeTimeoutMs("conversation.list")).toBe(12_000); // default 不变
  });
});

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

describe("WebProductionBridge session recovery", () => {
  it("cancels a stuck operation and searches on the same authenticated runtime", async () => {
    vi.useFakeTimers();
    let cancel: (() => void) | undefined;
    let loggedIn = false;
    const runtime = {
      invoke: vi.fn(async (op: string) => {
        if (op === "sdk.login") { loggedIn = true; return "null"; }
        if (op === "conversation.update_draft") {
          return new Promise((_, reject) => { cancel = () => reject(new Error("cancelled")); });
        }
        if (!loggedIn) throw new Error("NOT_CONNECTED");
        return { messages: [] };
      }),
      cancelPendingInvocations: vi.fn(() => { cancel?.(); return true; }),
      dispose: vi.fn(), setEventCallback: vi.fn(), setStorageHost: vi.fn(),
    };
    const loadRuntime = vi.fn(async () => ({ runtime: runtime as never }));
    const bridge = new WebProductionBridge({ loadRuntime, createStorageHost: () => storageHostStub() as never });
    try {
      await bridge.invoke({ operation: "sdk.login" } as never, {});
      const stuck = bridge.invoke({ operation: "conversation.update_draft" } as never, {}).catch(e => e.code);
      await vi.advanceTimersByTimeAsync(5_001);
      expect(await stuck).toBe("wasm.invoke_timeout");
      const search = bridge.invoke({ operation: "message.search_in_conversation" } as never, {});
      await vi.advanceTimersByTimeAsync(5_001);
      await expect(search).resolves.toEqual({ messages: [] });
      expect(loadRuntime).toHaveBeenCalledTimes(1);
      expect(runtime.dispose).not.toHaveBeenCalled();
      expect(runtime.cancelPendingInvocations).toHaveBeenCalledTimes(1);
    } finally { vi.useRealTimers(); }
  });

  it("installs the storage host as one object whose methods the runtime reads by name", async () => {
    const host = storageHostStub();
    const runtime = { invoke: vi.fn(async () => null), setEventCallback: vi.fn(), setStorageHost: vi.fn() };
    const bridge = new WebProductionBridge({ loadRuntime: async () => ({ runtime: runtime as never }), createStorageHost: () => host as never });
    await bridge.invoke({ operation: "sdk.login" } as never, {});
    expect(runtime.setStorageHost).toHaveBeenCalledTimes(1);
    expect(runtime.setStorageHost).toHaveBeenCalledWith(host);
  });

  it("does not turn an authoritative false into true from cached ready state", async () => {
    const runtime = { invoke: async (op: string) => op === "sdk.login" ? null : false };
    const bridge = new WebProductionBridge({ loadRuntime: async () => ({ runtime: runtime as never }), createStorageHost: () => storageHostStub() as never });
    await bridge.invoke({ operation: "sdk.login" } as never, {});
    await expect(bridge.invoke({ operation: "sdk.session_active" } as never)).resolves.toBe(false);
    await expect(bridge.invoke({ operation: "sdk.is_connected" } as never)).resolves.toBe(false);
  });

  it("blocks without replacing a lifecycle that cannot acknowledge cancellation, then recovers when it settles", async () => {
    vi.useFakeTimers();
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    let finish!: (v: string) => void;
    const runtime = {
      invoke: vi.fn(async (op: string) => op === "sdk.connect" ? new Promise<string>(r => { finish = r; }) : { messages: [] }),
      cancelPendingInvocations: vi.fn(() => false),
    };
    const loader = vi.fn(async () => ({ runtime: runtime as never }));
    const bridge = new WebProductionBridge({ loadRuntime: loader, createStorageHost: () => storageHostStub() as never });
    try {
      const pending = bridge.invoke({ operation: "sdk.connect" } as never).catch(e => e.code);
      await vi.advanceTimersByTimeAsync(22_001);
      expect(await pending).toBe("wasm.invoke_timeout");
      await expect(bridge.invoke({ operation: "message.search" } as never)).rejects.toMatchObject({ code: "wasm.recovery_pending" });
      expect(loader).toHaveBeenCalledTimes(1);
      finish("null");
      await vi.advanceTimersByTimeAsync(1);
      await expect(bridge.invoke({ operation: "message.search" } as never)).resolves.toEqual({ messages: [] });
    } finally { log.mockRestore(); vi.useRealTimers(); }
  });
});
