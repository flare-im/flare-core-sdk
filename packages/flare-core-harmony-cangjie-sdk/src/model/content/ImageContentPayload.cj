package flare_core_harmony_cangjie_sdk.model.content

import flare_core_harmony_cangjie_sdk.model.media.MediaSourceInfo

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Image message payload.
public class ImageContentPayload {
    // wire: `imageId`. Optional. Uploaded image id.
    public let imageId: ?String
    // wire: `source`. Optional. Source descriptor.
    public let source: ?MediaSourceInfo
    // wire: `thumbnail`. Optional. Thumbnail descriptor.
    public let thumbnail: ?MediaSourceInfo
    // wire: `description`. Optional. Caption.
    public let description: ?String

    public init(imageId!: ?String, source!: ?MediaSourceInfo, thumbnail!: ?MediaSourceInfo, description!: ?String) {
        this.imageId = imageId
        this.source = source
        this.thumbnail = thumbnail
        this.description = description
    }
}
