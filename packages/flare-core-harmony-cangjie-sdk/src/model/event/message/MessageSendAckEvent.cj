package flare_core_harmony_cangjie_sdk.model.event.message

import flare_core_harmony_cangjie_sdk.model.response.SendMessageResponse

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Message send acknowledgement notification.
public class MessageSendAckEvent {
    // wire: `ack`. Send acknowledgement.
    public let ack: SendMessageResponse

    public init(ack!: SendMessageResponse) {
        this.ack = ack
    }
}
