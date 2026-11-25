package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.content.StickerContentPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build a sticker message.
public class BuildStickerMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `stickerId`. Sticker id.
    public let stickerId: String
    // wire: `packageId`. Optional. Sticker package id.
    public let packageId: ?String
    // wire: `payload`. Optional. Optional sticker payload.
    public let payload: ?StickerContentPayload

    public init(conversationId!: String, stickerId!: String, packageId!: ?String, payload!: ?StickerContentPayload) {
        this.conversationId = conversationId
        this.stickerId = stickerId
        this.packageId = packageId
        this.payload = payload
    }
}
