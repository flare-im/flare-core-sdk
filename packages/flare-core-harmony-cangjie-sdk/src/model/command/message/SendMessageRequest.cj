package flare_core_harmony_cangjie_sdk.model.command.message

import flare_core_harmony_cangjie_sdk.model.entity.Message

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Send a fully built message.
public class SendMessageRequest {
    // wire: `message`. Message to send.
    public let message: Message
    // wire: `expectedUserId`. Optional. Optional active-user precondition; cannot override the authenticated sender.
    public let expectedUserId: ?String

    public init(message!: Message, expectedUserId!: ?String) {
        this.message = message
        this.expectedUserId = expectedUserId
    }
}
