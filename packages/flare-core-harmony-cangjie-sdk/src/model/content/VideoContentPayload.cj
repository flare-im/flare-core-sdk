package flare_core_harmony_cangjie_sdk.model.content

import flare_core_harmony_cangjie_sdk.model.media.MediaSourceInfo

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Video message payload.
public class VideoContentPayload {
    // wire: `videoId`. Optional. Uploaded video id.
    public let videoId: ?String
    // wire: `source`. Optional. Video source.
    public let source: ?MediaSourceInfo
    // wire: `cover`. Optional. Cover image.
    public let cover: ?MediaSourceInfo
    // wire: `description`. Optional. Caption.
    public let description: ?String

    public init(videoId!: ?String, source!: ?MediaSourceInfo, cover!: ?MediaSourceInfo, description!: ?String) {
        this.videoId = videoId
        this.source = source
        this.cover = cover
        this.description = description
    }
}
