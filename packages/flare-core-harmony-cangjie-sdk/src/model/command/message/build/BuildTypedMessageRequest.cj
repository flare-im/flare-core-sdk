package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.catalog.MessageBuildOp

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Generic typed build request used by composer helpers.
public class BuildTypedMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `op`. Build operation.
    public let op: MessageBuildOp
    // wire: `data`. Optional. Operation-specific payload; prefer typed buildXxx requests.
    public let data: ?String

    public init(conversationId!: String, op!: MessageBuildOp, data!: ?String) {
        this.conversationId = conversationId
        this.op = op
        this.data = data
    }
}
