package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// MessagePreview
public class MessagePreview {
    // wire: `messageId`. 
    public let messageId: String
    // wire: `senderId`. 
    public let senderId: String
    // wire: `text`. 
    public let text: String
    // wire: `time`. 毫秒时间戳
    public let time: UInt64
    // wire: `type`. 
    public let typeValue: Int32

    public init(messageId!: String, senderId!: String, text!: String, time!: UInt64, typeValue!: Int32) {
        this.messageId = messageId
        this.senderId = senderId
        this.text = text
        this.time = time
        this.typeValue = typeValue
    }
}
