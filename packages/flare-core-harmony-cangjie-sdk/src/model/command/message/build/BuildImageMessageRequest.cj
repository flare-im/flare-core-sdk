package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.content.ImageContentPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build an image message.
public class BuildImageMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `imageId`. Uploaded image id.
    public let imageId: String
    // wire: `payload`. Optional. Optional rich image payload for UI preview.
    public let payload: ?ImageContentPayload

    public init(conversationId!: String, imageId!: String, payload!: ?ImageContentPayload) {
        this.conversationId = conversationId
        this.imageId = imageId
        this.payload = payload
    }
}
