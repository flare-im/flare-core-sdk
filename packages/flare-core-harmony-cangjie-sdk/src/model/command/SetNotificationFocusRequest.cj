package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The conversation the user is looking at.
public class SetNotificationFocusRequest {
    // wire: `conversationId`. Optional. Conversation on screen; absent when no conversation is open.
    public let conversationId: ?String

    public init(conversationId!: ?String) {
        this.conversationId = conversationId
    }
}
