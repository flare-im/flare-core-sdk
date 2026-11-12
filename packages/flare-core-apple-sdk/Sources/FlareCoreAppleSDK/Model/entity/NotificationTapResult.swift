import Foundation

/// GENERATED. Do not edit by hand.
/// Where a tapped notification leads; every field is absent when the payload is not for the current account.
public struct NotificationTapResult: Codable, Sendable {
    /// wire: `conversationId`. Conversation to open.
    public let conversationId: String?
    /// wire: `messageId`. Message to scroll to, when the payload named one.
    public let messageId: String?
    /// wire: `seq`. Conversation seq of that message.
    public let seq: UInt64?

    public init(conversationId: String? = nil, messageId: String? = nil, seq: UInt64? = nil) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.seq = seq
    }
}
