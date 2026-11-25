package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.entity.MessageContent

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build from an existing MessageContent envelope.
public class BuildWithContentMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `content`. Decoded content envelope.
    public let content: MessageContent

    public init(conversationId!: String, content!: MessageContent) {
        this.conversationId = conversationId
        this.content = content
    }
}
