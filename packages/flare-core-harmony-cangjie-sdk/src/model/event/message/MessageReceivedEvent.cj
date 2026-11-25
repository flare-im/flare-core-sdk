package flare_core_harmony_cangjie_sdk.model.event.message

import flare_core_harmony_cangjie_sdk.model.entity.Message

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Single message received notification.
public class MessageReceivedEvent {
    // wire: `message`. Received message.
    public let message: Message

    public init(message!: Message) {
        this.message = message
    }
}
