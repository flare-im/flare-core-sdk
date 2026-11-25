package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.content.AudioContentPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build an audio message.
public class BuildAudioMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `audioId`. Uploaded audio id.
    public let audioId: String
    // wire: `payload`. Optional. Optional audio payload.
    public let payload: ?AudioContentPayload

    public init(conversationId!: String, audioId!: String, payload!: ?AudioContentPayload) {
        this.conversationId = conversationId
        this.audioId = audioId
        this.payload = payload
    }
}
