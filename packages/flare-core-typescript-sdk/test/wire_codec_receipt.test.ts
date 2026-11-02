import { describe, expect, it } from "vitest";
import { messageFromJson, messageReceiptViewFromJson } from "../src/adapter/codec/wireCodec";
import { MessageReceiptStatus } from "../src/model";

const wire = {
  serverId: "s1", clientMsgId: "c1", conversationId: "g1", conversationType: 2, channelId: "g1", senderId: "me",
  source: 1, conversationSeq: 5, createdAt: 1, clientCreatedAt: 1, messageType: 1, senderName: "", senderAvatar: "",
  senderDisplayName: "", sender: { kind: "unnamed", entity: "person", idTail: "me" }, status: 3, isRead: false, isRecalled: false, isEdited: false, mentionUsers: [], mentionAll: false,
  attributes: {}, extensions: {}, reactions: [], textPreview: "hi", version: 1, updatedAt: 1, timelineKey: "k", timelineSortTs: 5,
};

describe("receipt projection on the wire", () => {
  it("decodes the core's receipt and its group read summary", () => {
    const message = messageFromJson({ ...wire, receipt: { status: "sent", readSummary: { readCount: 2, unreadCount: 3, total: 5 } } });
    expect(message.receipt).toEqual({ status: MessageReceiptStatus.Sent, readSummary: { readCount: 2, unreadCount: 3, total: 5 } });
  });
  it("drops what an older core or a malformed value would give", () => {
    expect(messageFromJson(wire).receipt).toBeUndefined();
    expect(messageReceiptViewFromJson({ status: "delivered" })).toBeUndefined();
    expect(messageReceiptViewFromJson({ status: "read", readSummary: { readCount: 0, unreadCount: 0, total: 0 } }))
      .toEqual({ status: MessageReceiptStatus.Read });
    expect(messageReceiptViewFromJson({ status: "sent", readSummary: { readCount: -1, unreadCount: 1, total: 1 } }))
      .toEqual({ status: MessageReceiptStatus.Sent });
  });
});
