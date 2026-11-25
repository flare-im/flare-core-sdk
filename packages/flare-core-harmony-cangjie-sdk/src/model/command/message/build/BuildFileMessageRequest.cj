package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.content.FileContentPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build a file message.
public class BuildFileMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `fileId`. Uploaded file id.
    public let fileId: String
    // wire: `payload`. Optional. Optional file payload.
    public let payload: ?FileContentPayload

    public init(conversationId!: String, fileId!: String, payload!: ?FileContentPayload) {
        this.conversationId = conversationId
        this.fileId = fileId
        this.payload = payload
    }
}
