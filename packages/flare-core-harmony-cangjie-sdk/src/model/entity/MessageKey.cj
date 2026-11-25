package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// 
public class MessageKey {
    // wire: `conversationId`. 
    public let conversationId: String
    // wire: `senderId`. 
    public let senderId: String
    // wire: `clientMsgId`. 
    public let clientMsgId: String

    public init(conversationId!: String, senderId!: String, clientMsgId!: String) {
        this.conversationId = conversationId
        this.senderId = senderId
        this.clientMsgId = clientMsgId
    }
}
