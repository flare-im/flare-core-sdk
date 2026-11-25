package flare_core_harmony_cangjie_sdk.model.response

import flare_core_harmony_cangjie_sdk.model.entity.Message

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// A local lookup within one conversation and sender. Missing or ambiguous messages have no value.
public class MessageByKeyResponse {
    // wire: `message`. Optional. 
    public let message: ?Message

    public init(message!: ?Message) {
        this.message = message
    }
}
