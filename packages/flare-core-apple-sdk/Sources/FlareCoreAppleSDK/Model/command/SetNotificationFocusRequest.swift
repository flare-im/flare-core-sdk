import Foundation

/// GENERATED. Do not edit by hand.
/// The conversation the user is looking at.
public struct SetNotificationFocusRequest: Codable, Sendable {
    /// wire: `conversationId`. Conversation on screen; absent when no conversation is open.
    public let conversationId: String?

    public init(conversationId: String? = nil) {
        self.conversationId = conversationId
    }
}
