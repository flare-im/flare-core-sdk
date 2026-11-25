package flare_core_harmony_cangjie_sdk.model.entity

import flare_core_harmony_cangjie_sdk.model.common.enums.MessageContentType

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Decoded content envelope. Type-specific payload lives in `data` until per-content models are generated.
public class MessageContent {
    // wire: `contentType`. Content discriminator.
    public let contentType: MessageContentType
    // wire: `data`. Content payload object.
    public let data: String

    public init(contentType!: MessageContentType, data!: String) {
        this.contentType = contentType
        this.data = data
    }
}
