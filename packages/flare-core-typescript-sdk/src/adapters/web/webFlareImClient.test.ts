import { describe, expect, it, vi } from "vitest";

import type { DefaultEventsApi } from "../../adapter/module/DefaultEventsApi";
import type { NativeBridge } from "../../contract/bridge_contract";
import { WebMediaApi } from "./media/WebMediaApi";
import { WebProductionBridge } from "./webProductionBridge";
import { WebFlareImClient } from "./webFlareImClient";

function messageFixture(text: string) {
  const now = Date.now();
  return {
    serverId: "srv-1",
    clientMsgId: "cli-1",
    conversationId: "c1",
    conversationType: 1,
    channelId: "bob",
    senderId: "alice",
    source: 1,
    conversationSeq: 1,
    createdAt: now,
    clientCreatedAt: now,
    messageType: 1,
    senderName: "alice",
    senderAvatar: "",
    senderDisplayName: "Alice",
    sender: { kind: "named", text: "alice", source: "snapshot" },
    status: 2,
    isRead: false,
    isRecalled: false,
    isEdited: false,
    mentionUsers: [],
    mentionAll: false,
    attributes: {},
    extensions: {},
    reactions: [],
    textPreview: text,
    version: 1,
    updatedAt: now,
    timelineKey: "1",
    timelineSortTs: now,
  };
}

describe("WebFlareImClient", () => {
  it("wraps media module with WebMediaApi", () => {
    const bridge: NativeBridge = {
      invoke: vi.fn(async () => ({})),
    };
    const client = new WebFlareImClient(bridge);
    expect(client.media).toBeInstanceOf(WebMediaApi);
    expect(typeof client.media.cacheRemoteMedia).toBe("function");
    expect(typeof client.media.resolveMediaAccess).toBe("function");
  });

  it("attaches events api so WASM push envelopes reach typed listeners", async () => {
    let eventCallback: ((event: unknown) => void) | null = null;
    const runtime = {
      invoke: vi.fn(async () => null),
      setEventCallback: vi.fn((callback: ((event: unknown) => void) | null) => {
        eventCallback = callback;
      }),
      setStorageHost: vi.fn(),
    };
    const bridge = new WebProductionBridge({
      loadRuntime: async () => ({ runtime: runtime as never }),
      createStorageHost: () => ({
        loadSnapshot: async () => "{}",
        saveMessage: async () => {},
        saveConversation: async () => {},
        saveCursor: async () => {},
        savePendingSend: async () => {},
        deleteMessage: async () => {},
        deleteConversation: async () => {},
        deletePendingSend: async () => {},
      }),
    });
    const client = new WebFlareImClient(bridge);
    const received: string[] = [];

    client.events.onMessageReceivedBatch((event) => {
      received.push(...event.messages.map((message) => message.textPreview));
    });
    await client.events.subscribeEvents({ sources: ["message"] });
    eventCallback?.({
      channel: "im://message_batch",
      payload: { messages: [messageFixture("hello from wasm")] },
    });

    expect(runtime.setEventCallback).toHaveBeenCalledTimes(1);
    expect(received).toEqual(["hello from wasm"]);
  });

  it("does not start another WASM runtime invoke while a timed-out invoke is still running", async () => {
    vi.useFakeTimers();
    try {
      let finishSlowInvoke: ((value: unknown) => void) | undefined;
      const runtime = {
        invoke: vi.fn((operation: string) => {
          if (operation === "sync.conversation") {
            return new Promise((resolve) => {
              finishSlowInvoke = resolve;
            });
          }
          return Promise.resolve(null);
        }),
        setEventCallback: vi.fn(),
        setStorageHost: vi.fn(),
      };
      const bridge = new WebProductionBridge({
        loadRuntime: async () => ({ runtime: runtime as never }),
        createStorageHost: () => ({
          loadSnapshot: async () => "{}",
          saveMessage: async () => {},
          saveConversation: async () => {},
          saveCursor: async () => {},
          savePendingSend: async () => {},
          deleteMessage: async () => {},
          deleteConversation: async () => {},
          deletePendingSend: async () => {},
        }),
      });

      const slow = bridge.invoke(
        { operation: "sync.conversation", transport: "wasm-production" },
        { conversationId: "c1" },
      ).catch((error) => error);
      await vi.advanceTimersByTimeAsync(8_001);
      await expect(slow).resolves.toMatchObject({
        code: "wasm.invoke_timeout",
        operation: "sync.conversation",
      });

      const next = bridge.invoke(
        { operation: "message_builder.dispatch", transport: "wasm-production" },
        { op: "create_text" },
      );
      await Promise.resolve();
      expect(runtime.invoke).toHaveBeenCalledTimes(1);

      finishSlowInvoke?.(null);
      await Promise.resolve();
      await expect(next).resolves.toBeNull();
      expect(runtime.invoke).toHaveBeenCalledTimes(2);
    } finally {
      vi.useRealTimers();
    }
  });

  it("does not treat remote draft updates as realtime typing controls", async () => {
    vi.useFakeTimers();
    try {
      let finishDraftUpdate: ((value: unknown) => void) | undefined;
      const runtime = {
        invoke: vi.fn((operation: string) => {
          if (operation === "conversation.update_draft") {
            return new Promise((resolve) => {
              finishDraftUpdate = resolve;
            });
          }
          return Promise.resolve(null);
        }),
        setEventCallback: vi.fn(),
        setStorageHost: vi.fn(),
      };
      const bridge = new WebProductionBridge({
        loadRuntime: async () => ({ runtime: runtime as never }),
        createStorageHost: () => ({
          loadSnapshot: async () => "{}",
          saveMessage: async () => {},
          saveConversation: async () => {},
          saveCursor: async () => {},
          savePendingSend: async () => {},
          deleteMessage: async () => {},
          deleteConversation: async () => {},
          deletePendingSend: async () => {},
        }),
      });

      const draftUpdate = bridge.invoke(
        { operation: "conversation.update_draft", transport: "wasm-production" },
        { conversationId: "c1", draft: "" },
      ).then(
        (value) => ({ ok: true, value }),
        (error) => ({ ok: false, error }),
      );
      await vi.advanceTimersByTimeAsync(1_501);
      let draftUpdateSettled = false;
      void draftUpdate.then(() => {
        draftUpdateSettled = true;
      });
      await Promise.resolve();

      expect(runtime.invoke).toHaveBeenCalledTimes(1);
      expect(draftUpdateSettled).toBe(false);

      finishDraftUpdate?.(null);
      await expect(draftUpdate).resolves.toEqual({ ok: true, value: null });
    } finally {
      vi.useRealTimers();
    }
  });

  it("passes events api to attachable bridges", () => {
    const bridge: NativeBridge & { attachEventEmitter: (api: DefaultEventsApi) => void } = {
      invoke: vi.fn(async () => ({})),
      attachEventEmitter: vi.fn(),
    };
    const client = new WebFlareImClient(bridge);

    expect(bridge.attachEventEmitter).toHaveBeenCalledWith(client.events);
  });
});
