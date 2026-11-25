package flare_core_harmony_cangjie_sdk.model.catalog

import flare_core_harmony_cangjie_sdk.model.common.enums.MessageContentType

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One supported quick-build operation exposed on MessageBuilderApi.
public class MessageBuildCatalogEntry {
    // wire: `op`. Build dispatch op.
    public let op: MessageBuildOp
    // wire: `method`. Facade method name, e.g. buildText.
    public let method: String
    // wire: `requestType`. Typed request model name.
    public let requestType: String
    // wire: `contentType`. Decoded content discriminator.
    public let contentType: MessageContentType
    // wire: `messageType`. Core message type integer.
    public let messageType: Int32
    // wire: `summary`. Human-readable summary for UI/docs.
    public let summary: String
    // wire: `stability`. stable | beta | experimental
    public let stability: String

    public init(op!: MessageBuildOp, method!: String, requestType!: String, contentType!: MessageContentType, messageType!: Int32, summary!: String, stability!: String) {
        this.op = op
        this.method = method
        this.requestType = requestType
        this.contentType = contentType
        this.messageType = messageType
        this.summary = summary
        this.stability = stability
    }
}
