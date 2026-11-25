package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.content.VideoContentPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build a video message.
public class BuildVideoMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `videoId`. Uploaded video id.
    public let videoId: String
    // wire: `payload`. Optional. Optional video payload.
    public let payload: ?VideoContentPayload

    public init(conversationId!: String, videoId!: String, payload!: ?VideoContentPayload) {
        this.conversationId = conversationId
        this.videoId = videoId
        this.payload = payload
    }
}
