package flare_core_harmony_cangjie_sdk.model.command.message.build

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build a custom extension message.
public class BuildCustomMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `type`. Extension type key.
    public let typeValue: String

    public init(conversationId!: String, typeValue!: String) {
        this.conversationId = conversationId
        this.typeValue = typeValue
    }
}
