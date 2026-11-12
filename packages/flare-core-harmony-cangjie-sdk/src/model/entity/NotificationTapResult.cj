package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Where a tapped notification leads; every field is absent when the payload is not for the current account.
public class NotificationTapResult {
    // wire: `conversationId`. Optional. Conversation to open.
    public let conversationId: ?String
    // wire: `messageId`. Optional. Message to scroll to, when the payload named one.
    public let messageId: ?String
    // wire: `seq`. Optional. Conversation seq of that message.
    public let seq: ?UInt64

    public init(conversationId!: ?String, messageId!: ?String, seq!: ?UInt64) {
        this.conversationId = conversationId
        this.messageId = messageId
        this.seq = seq
    }
}
