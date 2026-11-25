package flare_core_harmony_cangjie_sdk.model.content

import flare_core_harmony_cangjie_sdk.model.media.MediaSourceInfo

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Audio message payload.
public class AudioContentPayload {
    // wire: `audioId`. Optional. Uploaded audio id.
    public let audioId: ?String
    // wire: `source`. Optional. Audio source.
    public let source: ?MediaSourceInfo
    // wire: `durationMs`. Optional. Duration.
    public let durationMs: ?Int32

    public init(audioId!: ?String, source!: ?MediaSourceInfo, durationMs!: ?Int32) {
        this.audioId = audioId
        this.source = source
        this.durationMs = durationMs
    }
}
