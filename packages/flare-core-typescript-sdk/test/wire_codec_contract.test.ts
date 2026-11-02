import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  conversationFromJson,
  conversationListQueryToMap,
  buildCardMessageRequestToMap,
  buildTextMessageRequestToMap,
  buildThreadReplyMessageRequestToMap,
  buildTypedMessageRequestToMap,
  conversationVersionFromJson,
  conversationTimelineSnapshotFromJson,
  homeTimelineSnapshotFromJson,
  listConversationsResponseFromJson,
  listMessagesResponseFromJson,
  messageContentToMap,
  messageFromJson,
  messageSearchQueryToMap,
  sendMessageRequestToMap,
  sendAckFromJson,
  syncConversationSummariesResponseFromJson,
  viewUpdateFromJson,
} from "../src/adapter/codec/wireCodec";
import { NativeCallMap } from "../src/contract/bridge_contract";
import { MESSAGE_BUILD_CATALOG } from "../src/model/message_build_catalog";
import { ConversationType } from "../src/model/conversation_type";
import { MessageBuildOp } from "../src/model/message_build_op";
import { MessageContentType } from "../src/model/message_content_type";
import { MessageSearchKind } from "../src/model/message_search_kind";
import type { SendMessageRequest } from "../src/model/send_message_request";
import { TimelineSyncState } from "../src/model/timeline_sync_state";
import type { BuildThreadReplyMessageRequest } from "../src/model/build_thread_reply_message_request";

const goldenDir = path.resolve(
  process.cwd(),
  "../../sdk-spec/golden/responses",
);
const requestGoldenDir = path.resolve(
  process.cwd(),
  "../../sdk-spec/golden/requests",
);
const eventGoldenDir = path.resolve(
  process.cwd(),
  "../../sdk-spec/golden/events",
);

function readGolden(name: string): Record<string, unknown> {
  return JSON.parse(
    fs.readFileSync(path.join(goldenDir, name), "utf8"),
  ) as Record<string, unknown>;
}

function readRequestGolden(name: string): Record<string, unknown> {
  return JSON.parse(
    fs.readFileSync(path.join(requestGoldenDir, name), "utf8"),
  ) as Record<string, unknown>;
}

function readEventGolden(name: string): Record<string, unknown> {
  return JSON.parse(
    fs.readFileSync(path.join(eventGoldenDir, name), "utf8"),
  ) as Record<string, unknown>;
}

function completeMessage(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    serverId: "server-msg-1",
    clientMsgId: "cm1",
    conversationId: "c1",
    conversationType: 1,
    channelId: "u2",
    senderId: "u2",
    source: 0,
    conversationSeq: 7,
    createdAt: 1000,
    clientCreatedAt: 999,
    messageType: 0,
    content: {
      contentType: "text",
      text: "hello",
      mentions: [],
    },
    senderName: "User Two",
    senderAvatar: "https://example.com/u2.png",
    senderDisplayName: "User Two",
    sender: { kind: "named", text: "User Two", source: "snapshot" },
    status: 2,
    isRead: false,
    isRecalled: false,
    isEdited: false,
    mentionUsers: [],
    mentionAll: false,
    attributes: {},
    extensions: {},
    reactions: [],
    textPreview: "hello",
    version: 1,
    updatedAt: 1000,
    timelineKey: "c1:7",
    timelineSortTs: 1000,
    ...overrides,
  };
}

describe("wireCodec conversation enum contract", () => {
  it("decodes Rust string conversationType values", () => {
    const conversation = conversationFromJson(
      readGolden("conversation_get_one.json"),
    );

    expect(conversation.conversationId).toBe("single-u2");
    expect(conversation.conversationType).toBe(ConversationType.Single);
  });

  it("decodes Rust string timeline sync state values", () => {
    const snapshot = homeTimelineSnapshotFromJson(
      readGolden("home_timeline_snapshot.json"),
    );

    expect(snapshot.syncState).toBe(TimelineSyncState.Synced);
    expect(snapshot.conversations[0]?.conversationType).toBe(
      ConversationType.Group,
    );
  });

  it("encodes conversationTypes as Rust serde enum strings", () => {
    const query = conversationListQueryToMap({
      conversationTypes: [ConversationType.Single, ConversationType.Group],
      hasDraftOnly: false,
      hasMarkedMessages: false,
      includeArchived: false,
      mentionMeOnly: false,
      pinnedOnly: false,
      unreadOnly: true,
    });

    expect(query.conversationTypes).toEqual(["single", "group"]);
  });

  it("does not decode legacy numeric enum values", () => {
    expect(() =>
      conversationFromJson({
        ...readGolden("conversation_get_one.json"),
        conversationType: 1,
      }),
    ).toThrow("invalid conversation type: <empty>");
    expect(() =>
      homeTimelineSnapshotFromJson({
        ...readGolden("home_timeline_snapshot.json"),
        syncState: 1,
      }),
    ).toThrow("invalid timeline sync state: <empty>");
  });

  it("requires conversationId and rejects malformed conversation collections", () => {
    expect(() =>
      conversationFromJson({
        conversationType: "single",
      }),
    ).toThrow("Conversation.conversationId is required");

    expect(() =>
      listConversationsResponseFromJson({
        conversations: [{ conversationType: "single" }],
      }),
    ).toThrow("Conversation.conversationId is required");

    expect(() =>
      listConversationsResponseFromJson({
        conversations: [null],
      }),
    ).toThrow("ListConversationsResponse.conversations[0] must be an object");

    expect(() =>
      homeTimelineSnapshotFromJson({
        ...readGolden("home_timeline_snapshot.json"),
        conversations: "bad",
      }),
    ).toThrow("HomeTimelineSnapshot.conversations must be an array");
  });
});

describe("wireCodec message timeline contract", () => {
  it("routes conversation search through the full MessageSearchQuery operation", () => {
    expect(NativeCallMap.messageSearchInConversation.operation).toBe("message.search_in_conversation");
    expect(NativeCallMap.messageSearchInConversation.dispatchOp).toBe("search_in_conversation");
  });

  it("encodes search kind filters as core serde enum strings", () => {
    expect(messageSearchQueryToMap({
      conversationId: "c1",
      keyword: "12",
      kinds: [MessageSearchKind.Image, MessageSearchKind.File],
      limit: 50,
      includeRecalled: false,
    })).toMatchObject({
      conversationId: "c1",
      keyword: "12",
      kinds: ["image", "file"],
      limit: 50,
      includeRecalled: false,
    });
  });

  it("requires message identity and sequence fields", () => {
    expect(() =>
      messageFromJson(completeMessage({ clientMsgId: undefined })),
    ).toThrow("Message.clientMsgId is required");

    expect(() =>
      messageFromJson(completeMessage({ conversationId: undefined })),
    ).toThrow("Message.conversationId is required");

    expect(() =>
      messageFromJson(completeMessage({ conversationSeq: "7" })),
    ).toThrow("Message.conversationSeq must be an unsigned integer");
  });

  it("requires the core timelineKey", () => {
    expect(() =>
      messageFromJson(completeMessage({ timelineKey: undefined })),
    ).toThrow("Message.timelineKey is required");
  });

  it("requires the core timelineSortTs", () => {
    expect(() =>
      messageFromJson(completeMessage({ timelineSortTs: undefined })),
    ).toThrow("Message.timelineSortTs is required");
  });

  it("parses core-provided timeline fields", () => {
    const message = messageFromJson(completeMessage());

    expect(message.timelineKey).toBe("c1:7");
    expect(message.timelineSortTs).toBe(1000);
  });

  it("preserves content payload fields named data for native resend", () => {
    const message = messageFromJson(completeMessage({
      messageType: 17,
      content: {
        contentType: "notification",
        title: "Notice",
        body: "Body",
        notificationType: "default",
        data: {},
        targetUserIds: [],
        requireAck: false,
        persistent: true,
      },
    }));

    expect(message.content?.data).toMatchObject({
      title: "Notice",
      body: "Body",
      data: {},
      persistent: true,
    });
    expect(sendMessageRequestToMap({ message }).message).toMatchObject({
      content: {
        contentType: "notification",
        title: "Notice",
        body: "Body",
        data: {},
        persistent: true,
      },
    });
  });

  it("does not decode legacy numeric contentType values", () => {
    expect(() =>
      messageFromJson(completeMessage({
        content: {
          contentType: 0,
          text: "hello",
        },
      })),
    ).toThrow("invalid message content type: <empty>");
    expect(() =>
      messageFromJson(completeMessage({
        content: {
          contentType: "link-card",
          text: "hello",
        },
      })),
    ).toThrow("invalid message content type: link-card");
  });

  it("requires sender display fields and reaction arrays from core", () => {
    expect(() =>
      messageFromJson(completeMessage({ senderDisplayName: undefined })),
    ).toThrow("Message.senderDisplayName is required");

    expect(() =>
      messageFromJson(completeMessage({ sender: undefined })),
    ).toThrow("Message.sender is required");

    expect(() =>
      messageFromJson(completeMessage({ reactions: undefined })),
    ).toThrow("Message.reactions must be an array");

    expect(() =>
      messageFromJson(completeMessage({ reactions: [null] })),
    ).toThrow("Message.reactions[0] must be an object");

    expect(() =>
      messageFromJson(completeMessage({ reactions: [{ emoji: "👍", userIds: [1], count: 1 }] })),
    ).toThrow("ReactionEntry.userIds[0] must be a string");
  });

  it("encodes message content and builder op as core enum strings", () => {
    expect(
      messageContentToMap({
        contentType: MessageContentType.LinkCard,
        data: { title: "hello" },
      }),
    ).toEqual({
      contentType: "link_card",
      data: { title: "hello" },
    });

    expect(
      buildTypedMessageRequestToMap({
        conversationId: "c1",
        op: MessageBuildOp.CreateImageGroup,
        data: { imageIds: ["i1"] },
      }),
    ).toEqual({
      conversationId: "c1",
      op: "create_image_group",
      data: { imageIds: ["i1"] },
    });
  });

  it("encodes text-builder mention fields for native message-build dispatch", () => {
    expect(
      buildTextMessageRequestToMap({
        conversationId: "c1",
        text: "hello",
      }),
    ).toEqual({
      conversationId: "c1",
      text: "hello",
      mentionUsers: [],
      mentionAll: false,
    });

    expect(
      buildTextMessageRequestToMap({
        conversationId: "c1",
        text: "@u2 hello @all",
        mentionUsers: ["u2"],
        mentionAll: true,
      }),
    ).toMatchObject({
      mentionUsers: ["u2"],
      mentionAll: true,
    });
  });

  it("keeps thread replies as typed threadId-scoped text messages", () => {
    const request = readRequestGolden(
      "build_thread_reply_message.json",
    ) as unknown as BuildThreadReplyMessageRequest;
    expect(buildThreadReplyMessageRequestToMap(request)).toEqual({
      conversationId: "group_001",
      threadId: "thread_root_msg_001",
      text: "reply inside the thread",
    });

    const catalogEntry = MESSAGE_BUILD_CATALOG.find(
      (entry) => entry.op === MessageBuildOp.CreateThreadReply,
    );
    expect(catalogEntry).toMatchObject({
      contentType: MessageContentType.Text,
      messageType: 1,
    });

    const message = messageFromJson(readGolden("build_thread_reply_message.json"));
    expect(message.threadId).toBe("thread_root_msg_001");
    expect(message.messageType).toBe(1);
    expect(message.content?.contentType).toBe(MessageContentType.Text);
    expect(message.attributes.thread_id).toBeUndefined();

    expect(sendMessageRequestToMap({ message }).message).toMatchObject({
      threadId: "thread_root_msg_001",
      messageType: 1,
      content: {
        contentType: "text",
        text: "reply inside the thread",
      },
    });
  });

  it("sends card attributes as the card elem's extra", () => {
    const card = { conversationId: "group_001", id: "user_007", cardType: "user", title: "Ann" };
    expect(JSON.parse(JSON.stringify(buildCardMessageRequestToMap({ ...card, attributes: { cardType: "user", referrerId: "user_009" } }))))
      .toEqual({ ...card, attributes: { cardType: "user", referrerId: "user_009" } });
    expect(JSON.parse(JSON.stringify(buildCardMessageRequestToMap(card)))).toEqual(card);
  });

  it("requires message arrays in list and timeline responses", () => {
    expect(() => listMessagesResponseFromJson({})).toThrow(
      "ListMessagesResponse.messages must be an array",
    );
    expect(() => listMessagesResponseFromJson({ messages: [null] })).toThrow(
      "ListMessagesResponse.messages[0] must be an object",
    );
    expect(() => conversationTimelineSnapshotFromJson({ messages: "bad" })).toThrow(
      "ConversationTimelineSnapshot.messages must be an array",
    );
  });
});

describe("wireCodec message ack and sync version contract", () => {
  it("encodes send-message request golden and decodes durable ack golden", () => {
    const request = readRequestGolden("send_message.json") as unknown as SendMessageRequest;
    const encoded = sendMessageRequestToMap(request);

    expect(encoded).toMatchObject({
      message: {
        serverId: "",
        clientMsgId: "client_msg_001",
        conversationId: "single_user_001_user_002",
        conversationType: 1,
        channelId: "user_002",
        senderId: "user_001",
        conversationSeq: 0,
        status: 0,
        timelineKey: "client:client_msg_001",
        content: {
          contentType: "text",
          text: "hello from send golden",
          mentions: [],
        },
      },
    });

    expect(sendAckFromJson(readGolden("send_message.json"))).toEqual({
      ackId: "ack_001",
      clientMsgId: "client_msg_001",
      serverId: "server_msg_001",
      conversationId: "single_user_001_user_002",
      seq: 1,
      timestamp: 1710000000000,
      success: true,
      errorCode: 0,
      errorMessage: "",
    });
  });

  it("requires send ack identity and sequence fields", () => {
    expect(() =>
      sendAckFromJson({
        serverId: "s1",
        clientMsgId: "cm1",
        conversationId: "c1",
        seq: 1,
        timestamp: 1000,
      }),
    ).toThrow("SendMessageResponse.ackId is required");

    expect(() =>
      sendAckFromJson({
        ackId: "ack1",
        serverId: "s1",
        clientMsgId: "cm1",
        conversationId: "c1",
        seq: "1",
        timestamp: 1000,
      }),
    ).toThrow("SendMessageResponse.seq must be an unsigned integer");
  });

  it("requires conversation version identity fields", () => {
    expect(() => conversationVersionFromJson({ version: 1 })).toThrow(
      "ConversationVersion.conversationId is required",
    );
    expect(() =>
      conversationVersionFromJson({ conversationId: "c1", version: "1" }),
    ).toThrow("ConversationVersion.version must be an unsigned integer");
    expect(() =>
      syncConversationSummariesResponseFromJson({ changedConversations: [null] }),
    ).toThrow(
      "SyncConversationSummariesResponse.changedConversations[0] must be an object",
    );
  });
});

describe("wireCodec view delta contract", () => {
  it("decodes shared core view delta golden without snapshot fallback", () => {
    const update = viewUpdateFromJson(readEventGolden("view_update_delta.json"));

    expect(update.kind).toBe("delta");
    expect(update.revision).toBe(4);
    expect(update.snapshot).toBeUndefined();
    expect(update.delta?.viewType).toBe("timeline");
    expect(update.delta?.append).toHaveLength(1);
    expect(update.delta?.append?.[0]?.clientMsgId).toBe("cm1");
    expect(update.delta?.append?.[0]?.content?.contentType).toBe(
      MessageContentType.Text,
    );
    expect(update.delta?.prepend).toEqual([]);
    expect(update.delta?.upsert).toEqual([]);
    expect(update.delta?.remove).toEqual([]);
    expect(update.delta?.reorder).toBeUndefined();
    expect(update.delta?.hasOlder).toBe(false);
    expect(update.delta?.hasNewer).toBe(false);
    expect(update.delta?.attachedToLatest).toBe(true);
  });

  it("requires explicit snapshot or delta kind", () => {
    expect(() => viewUpdateFromJson({ viewId: "v1", revision: 1, snapshot: {} })).toThrow(
      "invalid view update kind: <empty>",
    );
    expect(() =>
      viewUpdateFromJson({ viewId: "v1", revision: 1, kind: "replace", snapshot: {} }),
    ).toThrow("invalid view update kind: replace");
  });

  it("requires a revision", () => {
    expect(() =>
      viewUpdateFromJson({ viewId: "v1", kind: "delta", delta: { viewType: "timeline" } }),
    ).toThrow("ViewUpdate.revision is required");
  });

  it("reads timeline rows and row keys strictly", () => {
    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "timeline", append: [null], hasOlder: true, hasNewer: false, attachedToLatest: true },
      }),
    ).toThrow("ViewDelta.append[0] must be an object");
    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "timeline", remove: [1], hasOlder: true, hasNewer: false, attachedToLatest: true },
      }),
    ).toThrow("ViewDelta.remove must be a list of row keys");
    const reordered = viewUpdateFromJson({
      viewId: "v1",
      revision: 2,
      kind: "delta",
      delta: {
        viewType: "timeline",
        remove: ["cm-1"],
        reorder: ["cm-2", "cm-3"],
        hasOlder: false,
        hasNewer: true,
        attachedToLatest: false,
      },
    });
    expect(reordered.delta?.remove).toEqual(["cm-1"]);
    expect(reordered.delta?.reorder).toEqual(["cm-2", "cm-3"]);
    expect(reordered.delta?.append).toEqual([]);
    expect(reordered.delta?.hasNewer).toBe(true);
    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "timeline" },
      }),
    ).toThrow("wire field must be a boolean");
  });

  it("requires conversation-list delta ops as an object array", () => {
    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "conversationList" },
      }),
    ).toThrow("ViewDelta.ops must be an array");
    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "conversationList", ops: [null] },
      }),
    ).toThrow("ViewDelta.ops[0] must be an object");
  });

  it("requires strict view identity, type, and delta op fields", () => {
    expect(() =>
      viewUpdateFromJson({
        revision: 2,
        kind: "delta",
        delta: { viewType: "conversationList", ops: [] },
      }),
    ).toThrow("ViewUpdate.viewId is required");

    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "feed", ops: [] },
      }),
    ).toThrow("invalid view type: feed");

    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "conversationList", ops: [{ op: "append", key: "k1", index: 0 }] },
      }),
    ).toThrow("invalid view delta op: append");

    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "conversationList", ops: [{ op: "insert", index: 0 }] },
      }),
    ).toThrow("ViewDeltaOp.key is required");

    expect(() =>
      viewUpdateFromJson({
        viewId: "v1",
        revision: 2,
        kind: "delta",
        delta: { viewType: "conversationList", ops: [{ op: "insert", key: "k1", index: "0" }] },
      }),
    ).toThrow("ViewDeltaOp.index must be an unsigned integer");
  });
});
