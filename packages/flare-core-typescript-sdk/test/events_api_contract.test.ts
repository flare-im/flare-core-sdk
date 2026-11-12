import fs from "node:fs";
import path from "node:path";

import { describe, expect, it, vi } from "vitest";

import {
  DefaultEventsApi,
  eventTypeForWebChannel,
  nativeEventFromCode,
} from "../src/adapter/module/DefaultEventsApi";
import type { NativeBridge } from "../src/contract/bridge_contract";
import {
  ConversationType,
  ConversationEventName,
  ConnectionPhase,
  ConnectionQuality,
  MessageEventName,
  MessageContentType,
  PluginEventName,
  TimelineSyncState,
  type ConnectionStatus,
} from "../src/model";

const eventGoldenDir = path.resolve(
  process.cwd(),
  "../../sdk-spec/golden/events",
);

function readEventGolden(name: string): Record<string, unknown> {
  return JSON.parse(
    fs.readFileSync(path.join(eventGoldenDir, name), "utf8"),
  ) as Record<string, unknown>;
}

function webEventType(channel: string): number {
  const eventType = eventTypeForWebChannel(channel);
  if (eventType === undefined) {
    throw new Error(`missing web event channel mapping: ${channel}`);
  }
  return eventType;
}

function testBridge(): NativeBridge {
  return {
    invoke: vi.fn(async () => ({ subscriptionId: "test-subscription" })),
  };
}

describe("DefaultEventsApi direct event callbacks", () => {
  it("hands connection://status to the status callback as the payload alone", () => {
    const events = new DefaultEventsApi(testBridge());
    const statuses: ConnectionStatus[] = [];
    const switched: unknown[] = [];

    events.onConnectionStatusChanged((status) => statuses.push(status));
    events.onAccessSwitched((event) => switched.push(event));

    events.emitNativeEvent(webEventType("connection://status"), {
      phase: "online",
      quality: "good",
      accessPointId: "ap-sg-1",
      cellId: "cell-sg-a",
      regionId: "sg",
      protocol: "quic",
      rttMs: 42,
      attempt: 0,
      nextRetryAt: null,
      reason: null,
      developmentMode: false,
    });

    expect(statuses).toEqual([{
      phase: ConnectionPhase.Online,
      quality: ConnectionQuality.Good,
      accessPointId: "ap-sg-1",
      cellId: "cell-sg-a",
      regionId: "sg",
      protocol: "quic",
      rttMs: 42,
      attempt: 0,
      developmentMode: false,
    }]);
    expect(switched).toEqual([]);
  });

  it("dispatches message mutation callbacks by concrete event name", () => {
    const events = new DefaultEventsApi(testBridge());
    const recalled: string[] = [];
    const edited: string[] = [];

    events.onMessageRecalled((event) => recalled.push(event.name));
    events.onMessageEdited((event) => edited.push(event.name));

    events.emitNativeEvent(2005, {
      conversationId: "c1",
      serverMsgId: "m1",
    });
    events.emitNativeEvent(2008, {
      conversationId: "c1",
      serverMsgId: "m1",
    });
    events.emitNativeEvent(2010, {
      conversationId: "c1",
      serverMsgId: "m1",
    });

    expect(recalled).toEqual([MessageEventName.Recalled]);
    expect(edited).toEqual([MessageEventName.Edited]);
  });

  it("forwards plugin card state changes as a message update with its version", () => {
    const events = new DefaultEventsApi(testBridge());
    const changed: Array<Record<string, unknown>> = [];
    const edited: string[] = [];

    events.onMessagePluginStateChanged((event) => changed.push(event as unknown as Record<string, unknown>));
    events.onMessageEdited((event) => edited.push(event.name));

    events.emitNativeEvent(2022, { conversationId: "c1", messageId: "m1", version: 3 });

    expect(changed).toHaveLength(1);
    expect(changed[0]).toMatchObject({
      name: MessageEventName.PluginStateChanged,
      conversationId: "c1",
      messageId: "m1",
      version: 3,
    });
    expect(edited).toEqual([]);
  });

  it("rejects a status payload whose phase is not a connection phase", () => {
    expect(() => nativeEventFromCode(1010, { phase: "ready", attempt: 0, developmentMode: false }))
      .toThrow("invalid event payload field: phase");
  });

  it("keeps unknown native event codes as raw forward-compatible events", () => {
    expect(nativeEventFromCode(999_999, { value: 1 })).toEqual({
      type: "unknown",
      name: "unknown",
      event: "unknown",
      eventType: 999_999,
      payload: { value: 1 },
    });
  });

  it("isolates listener failures and continues fan-out", () => {
    const events = new DefaultEventsApi(testBridge());
    const received: string[] = [];
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});

    try {
      events.onConnectionStatusChanged(() => {
        throw new Error("listener broke");
      });
      events.onConnectionStatusChanged((status) => received.push(status.phase));

      events.emitNativeEvent(1010, { phase: "reconnecting", attempt: 2, nextRetryAt: 1_762_250_000_000, developmentMode: false });

      expect(received).toEqual([ConnectionPhase.Reconnecting]);
      expect(consoleError).toHaveBeenCalledWith(
        "[flare-core] event listener failed",
        expect.any(Error),
      );
    } finally {
      consoleError.mockRestore();
    }
  });

  it("rejects message batch events without the required messages array", () => {
    expect(() => nativeEventFromCode(2002, {})).toThrow(
      "invalid event payload field: messages",
    );
  });

  it("decodes message batch golden from the Web push channel into the typed listener", () => {
    const events = new DefaultEventsApi(testBridge());
    const batches: number[] = [];
    const singles: string[] = [];

    events.onMessageReceivedBatch((event) => batches.push(event.messages.length));
    events.onMessageReceived((event) => singles.push(event.message.serverId));

    events.emitNativeEvent(
      webEventType("im://message_batch"),
      readEventGolden("message_received_batch.json"),
    );

    expect(batches).toEqual([2]);
    expect(singles).toEqual([]);

    const decoded = nativeEventFromCode(
      webEventType("im://message_batch"),
      readEventGolden("message_received_batch.json"),
    );

    expect(decoded).toMatchObject({
      type: "message",
      event: MessageEventName.ReceivedBatch,
      messages: [
        {
          conversationId: "group-100",
          conversationSeq: 100,
          content: { contentType: MessageContentType.Text },
        },
        {
          conversationId: "group-100",
          conversationSeq: 101,
          content: { contentType: MessageContentType.Text },
        },
      ],
    });
  });

  it("rejects typing events with missing or non-boolean protocol fields", () => {
    expect(() =>
      nativeEventFromCode(2006, {
        conversationId: "c1",
        userId: "u1",
      }),
    ).toThrow("invalid event payload field: typing");

    expect(() =>
      nativeEventFromCode(2006, {
        conversationId: "c1",
        userId: "u1",
        typing: "true",
      }),
    ).toThrow("invalid event payload field: typing");
  });

  it("decodes typing aggregate and read receipt goldens into collaboration listeners", () => {
    const events = new DefaultEventsApi(testBridge());
    const typing: string[] = [];
    const typingAggregates: string[] = [];
    const reads: number[] = [];

    events.onInputStatusChanged((event) => {
      typing.push(`${event.conversationId}:${event.userId}:${event.typing}`);
    });
    events.onTypingAggregateChanged((event) => {
      typingAggregates.push(
        `${event.conversationId}:${event.typingCount}:${event.typingUserIds.join(",")}`,
      );
    });
    events.onMessageReadReceipt((event) => reads.push(event.readSeq));

    events.emitNativeEvent(
      webEventType("im://typing"),
      readEventGolden("typing.json"),
    );
    events.emitNativeEvent(
      webEventType("im://message_typing_aggregate"),
      readEventGolden("typing_aggregate.json"),
    );
    events.emitNativeEvent(
      webEventType("im://message_read_receipt"),
      readEventGolden("read_receipt.json"),
    );

    expect(typing).toEqual(["group-100:user-a:true"]);
    expect(typingAggregates).toEqual(["group-100:2:user-a,user-b"]);
    expect(reads).toEqual([101]);

    expect(nativeEventFromCode(
      webEventType("im://message_typing_aggregate"),
      readEventGolden("typing_aggregate.json"),
    )).toMatchObject({
      type: "message",
      event: MessageEventName.TypingAggregate,
      name: MessageEventName.TypingAggregate,
      conversationId: "group-100",
      typingUserIds: ["user-a", "user-b"],
      typingCount: 2,
    });
  });

  it("rejects read receipt events unless readSeq is a finite number", () => {
    expect(() =>
      nativeEventFromCode(2011, {
        conversationId: "c1",
        userId: "u1",
        readSeq: "7",
      }),
    ).toThrow("invalid event payload field: readSeq");

    const event = nativeEventFromCode(2011, {
      conversationId: "c1",
      userId: "u1",
      readSeq: 7,
    }) as { readSeq: number };

    expect(event.readSeq).toBe(7);
  });

  it("decodes unread-count conversation goldens into conversation refresh listeners", () => {
    const events = new DefaultEventsApi(testBridge());
    const unreadCounts: number[] = [];
    const changedConversationIds: string[][] = [];

    events.onTotalUnreadMessageCountChanged((event) => {
      unreadCounts.push(event.unreadCount ?? -1);
    });
    events.onConversationChanged((event) => {
      changedConversationIds.push(event.conversationIds);
    });

    events.emitNativeEvent(
      webEventType("im://unread_count_changed"),
      readEventGolden("conversation_unread_count_changed.json"),
    );

    expect(unreadCounts).toEqual([2]);
    expect(changedConversationIds).toEqual([["group-100"]]);

    const decoded = nativeEventFromCode(
      webEventType("im://unread_count_changed"),
      readEventGolden("conversation_unread_count_changed.json"),
    );

    expect(decoded).toMatchObject({
      type: "conversation",
      event: "unread_count_changed",
      name: ConversationEventName.UnreadCountChanged,
      conversationId: "group-100",
      conversationIds: ["group-100"],
      unreadCount: 2,
    });
  });

  it("decodes conversation snapshot and view delta goldens into view listeners", () => {
    const events = new DefaultEventsApi(testBridge());
    const updates: Array<{
      kind: string;
      viewType: string;
      totalUnread: number | null;
      syncState: string | null;
      firstConversationId: string | null;
      revision: number;
      appendCount: number;
      firstAppendKey: string | null;
    }> = [];

    events.onViewUpdated((event) => {
      const snapshotData = event.snapshot?.data as {
        conversations?: Array<{ conversationId: string }>;
        totalUnread?: number;
        syncState?: string;
      } | undefined;
      updates.push({
        kind: event.kind,
        viewType: event.snapshot?.viewType ?? event.delta?.viewType ?? "",
        totalUnread: snapshotData?.totalUnread ?? event.delta?.totalUnread ?? null,
        syncState: snapshotData?.syncState ?? event.delta?.syncState ?? null,
        firstConversationId:
          snapshotData?.conversations?.[0]?.conversationId ??
          event.delta?.conversation?.conversationId ??
          null,
        revision: event.revision,
        appendCount: event.delta?.append?.length ?? 0,
        firstAppendKey: event.delta?.append?.[0]?.clientMsgId ?? null,
      });
    });

    events.emitNativeEvent(
      webEventType("im://view_updated"),
      readEventGolden("conversation_snapshot.json"),
    );
    events.emitNativeEvent(
      webEventType("im://view_updated"),
      readEventGolden("view_update_delta.json"),
    );

    expect(updates).toEqual([
      {
        kind: "snapshot",
        viewType: "conversationList",
        totalUnread: 2,
        syncState: TimelineSyncState.Synced,
        firstConversationId: "group-100",
        revision: 1,
        appendCount: 0,
        firstAppendKey: null,
      },
      {
        kind: "delta",
        viewType: "timeline",
        totalUnread: null,
        syncState: null,
        firstConversationId: null,
        revision: 4,
        appendCount: 1,
        firstAppendKey: "cm1",
      },
    ]);

    const decodedSnapshot = nativeEventFromCode(
      webEventType("im://view_updated"),
      readEventGolden("conversation_snapshot.json"),
    );
    const decodedDelta = nativeEventFromCode(
      webEventType("im://view_updated"),
      readEventGolden("view_update_delta.json"),
    );

    expect(decodedSnapshot).toMatchObject({
      type: "view",
      event: "updated",
      kind: "snapshot",
      snapshot: {
        viewType: "conversationList",
        data: {
          totalUnread: 2,
          syncState: TimelineSyncState.Synced,
          conversations: [
            {
              conversationId: "group-100",
              conversationType: ConversationType.Group,
              maxSeq: 101,
            },
          ],
        },
      },
    });
    expect(decodedDelta).toMatchObject({
      type: "view",
      event: "updated",
      revision: 4,
      kind: "delta",
      delta: {
        viewType: "timeline",
        prepend: [],
        append: [{ clientMsgId: "cm1", serverId: "server-msg-1" }],
        upsert: [],
        remove: [],
        hasOlder: false,
        hasNewer: false,
        attachedToLatest: true,
      },
    });
  });

  it("rejects malformed send-failed and reaction events instead of filling defaults", () => {
    expect(() =>
      nativeEventFromCode(2004, {
        clientMsgId: "",
        reason: "timeout",
      }),
    ).toThrow("invalid event payload field: clientMsgId");

    expect(() =>
      nativeEventFromCode(2009, {
        conversationId: "c1",
        serverMsgId: "m1",
        userId: "u1",
        emoji: "👍",
        action: "1",
      }),
    ).toThrow("invalid event payload field: action");
  });

  it("decodes plugin realtime and catalog goldens into the plugin listeners", () => {
    const events = new DefaultEventsApi(testBridge());
    const realtime: string[] = [];
    const catalog: string[] = [];
    const listened: string[] = [];

    events.onPluginRealtime((event) => {
      realtime.push(`${event.pluginId}:${event.packetType}:${String(event.payload.callId)}:${event.expiresAtMs}`);
    });
    events.onPluginCatalogChanged((event) => {
      catalog.push(event.version);
    });
    events.addEventListener({
      onPluginRealtime: (event) => listened.push(`realtime:${event.deliveryId}`),
      onPluginCatalogChanged: (event) => listened.push(`catalog:${event.version}`),
    });

    events.emitNativeEvent(webEventType("im://plugin_realtime"), readEventGolden("plugin_realtime.json"));
    events.emitNativeEvent(
      webEventType("im://plugin_catalog_changed"),
      readEventGolden("plugin_catalog_changed.json"),
    );

    expect(realtime).toEqual(["flare.call:call.snapshot:call-1:1730000060000"]);
    expect(catalog).toEqual(["42"]);
    expect(listened).toEqual(["realtime:delivery-1", "catalog:42"]);
    expect(nativeEventFromCode(webEventType("im://plugin_realtime"), readEventGolden("plugin_realtime.json"))).toMatchObject({
      type: "plugin",
      event: PluginEventName.Realtime,
      conversationId: "single-u2",
      payload: { callId: "call-1", version: 3 },
    });
  });

  it("hands notification present, clear and badge events to the notification listeners", () => {
    const events = new DefaultEventsApi(testBridge());
    const seen: string[] = [];
    const listened: string[] = [];

    events.onNotificationPresent((event) => {
      seen.push(`present:${event.collapseId}:${event.conversationId}:${event.surface}:${event.sound}`);
    });
    events.onNotificationClear((event) => seen.push(`clear:${event.collapseIds.join(",")}:${event.all}`));
    events.onNotificationBadge((event) => seen.push(`badge:${event.count}`));
    events.addEventListener({
      onNotificationPresent: (event) => listened.push(`present:${event.collapseId}`),
      onNotificationClear: (event) => listened.push(`clear:${event.all}`),
      onNotificationBadge: (event) => listened.push(`badge:${event.count}`),
    });

    events.emitNativeEvent(webEventType("im://notification_present"), {
      collapseId: "c:0123456789abcdef0123456789abcdef",
      threadId: "c:0123456789abcdef0123456789abcdef",
      conversationId: "conv-1",
      messageId: "m-9",
      seq: 42,
      title: "Ann",
      body: "hi",
      count: 2,
      sound: true,
      channel: "mentions",
      surface: "system",
    });
    events.emitNativeEvent(webEventType("im://notification_clear"), {
      collapseIds: ["c:0123456789abcdef0123456789abcdef"],
      all: false,
    });
    events.emitNativeEvent(webEventType("im://notification_clear"), { collapseIds: [], all: true });
    events.emitNativeEvent(webEventType("im://notification_badge"), { count: 7 });

    expect(seen).toEqual([
      "present:c:0123456789abcdef0123456789abcdef:conv-1:system:true",
      "clear:c:0123456789abcdef0123456789abcdef:false",
      "clear::true",
      "badge:7",
    ]);
    expect(listened).toEqual([
      "present:c:0123456789abcdef0123456789abcdef",
      "clear:false",
      "clear:true",
      "badge:7",
    ]);
  });

  it("rejects a plugin realtime payload that is not a JSON object", () => {
    expect(() =>
      nativeEventFromCode(webEventType("im://plugin_realtime"), {
        ...readEventGolden("plugin_realtime.json"),
        payload: [1, 2],
      }),
    ).toThrow("invalid event payload field: payload");
  });

  it("decodes a server rejection with its typed reason as the core emits it", () => {
    const golden = readEventGolden("send_failed_with_error.json");
    const failed = nativeEventFromCode(webEventType("im://send_failed"), golden) as {
      clientMsgId: string;
      reason: string;
      error?: Record<string, unknown>;
    };

    expect(failed.clientMsgId).toBe(golden.clientMsgId);
    expect(failed.reason).toBe(golden.reason);
    expect(failed.error).toEqual(golden.error);
    expect(failed.error?.machineReason).toBe("SOCIAL_CARD_SCOPE_FRIENDS");
  });

  it("reads the empty typed reason of a local send failure as no reason", () => {
    const failed = nativeEventFromCode(2004, {
      clientMsgId: "cm1",
      reason: "send timed out",
      error: {
        code: "OPERATION_TIMEOUT",
        machineReason: "",
        message: "send timed out",
        operation: "message.send",
        retryable: false,
        details: {},
      },
    }) as { error?: { code: string; machineReason?: string } };

    expect(failed.error?.code).toBe("OPERATION_TIMEOUT");
    expect(failed.error?.machineReason).toBeUndefined();

    expect(() =>
      nativeEventFromCode(2004, {
        clientMsgId: "cm1",
        reason: "send timed out",
        error: { code: "OPERATION_TIMEOUT", machineReason: 21, message: "send timed out" },
      }),
    ).toThrow("invalid event payload field: error.machineReason");
  });

  it("decodes SDK error payloads without filling missing code or message", () => {

    const event = nativeEventFromCode(2004, {
      clientMsgId: "cm1",
      reason: "timeout",
      error: {
        code: "timeout",
        message: "send timed out",
        operation: "message.send",
        retryable: true,
        details: { phase: "flush" },
      },
    }) as { error?: { code: string; message: string; details: Record<string, string> } };

    expect(event.error?.code).toBe("timeout");
    expect(event.error?.message).toBe("send timed out");
    expect(event.error?.details).toEqual({ phase: "flush" });

    expect(() =>
      nativeEventFromCode(2004, {
        clientMsgId: "cm1",
        reason: "timeout",
        error: { code: "timeout" },
      }),
    ).toThrow("invalid event payload field: error.message");

    const stringError = nativeEventFromCode(2004, {
      clientMsgId: "cm1",
      reason: "timeout",
      error: "timeout",
    }) as { reason: string; error?: unknown };

    expect(stringError.reason).toBe("timeout");
    expect(stringError.error).toBeUndefined();

    const syncStringError = nativeEventFromCode(4003, {
      task: "single_conversation",
      error: "sync forward: user settings version conflict or participant not found",
    }) as { message?: string; error?: unknown };

    expect(syncStringError.message).toBe(
      "sync forward: user settings version conflict or participant not found",
    );
    expect(syncStringError.error).toBeUndefined();

    expect(() =>
      nativeEventFromCode(2004, {
        clientMsgId: "cm1",
        reason: "timeout",
        error: 3,
      }),
    ).toThrow("invalid event payload field: error");

    expect(() =>
      nativeEventFromCode(2004, {
        clientMsgId: "cm1",
        reason: "timeout",
        error: {
          code: "timeout",
          message: "send timed out",
          details: { retryAfter: 3 },
        },
      }),
    ).toThrow("invalid event payload field: error.details.retryAfter");
  });
});
