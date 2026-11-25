package flare_core_harmony_cangjie_sdk.model.response

import flare_core_harmony_cangjie_sdk.model.entity.MessageSendStage

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Send acknowledgement returned by core-sdk.
public class SendMessageResponse {
    // wire: `ackId`. ACK id assigned by the transport layer, if present.
    public let ackId: String
    // wire: `serverId`. Server-assigned message id.
    public let serverId: String
    // wire: `clientMsgId`. Client message id acknowledged by the server.
    public let clientMsgId: String
    // wire: `conversationId`. Conversation id.
    public let conversationId: String
    // wire: `seq`. Assigned conversation sequence.
    public let seq: UInt64
    // wire: `timestamp`. Server send time in milliseconds.
    public let timestamp: UInt64
    // wire: `success`. Whether the SDK queued the message locally or the server accepted it. Check stage for persistence.
    public let success: Bool
    // wire: `stage`. Optional. Queued locally, accepted by the server, persisted by the server, or failed. Older engines omit this field.
    public let stage: ?MessageSendStage
    // wire: `errorCode`. Core ACK error code when success is false.
    public let errorCode: Int32
    // wire: `errorMessage`. Core ACK error message when success is false.
    public let errorMessage: String

    public init(ackId!: String, serverId!: String, clientMsgId!: String, conversationId!: String, seq!: UInt64, timestamp!: UInt64, success!: Bool, stage!: ?MessageSendStage, errorCode!: Int32, errorMessage!: String) {
        this.ackId = ackId
        this.serverId = serverId
        this.clientMsgId = clientMsgId
        this.conversationId = conversationId
        this.seq = seq
        this.timestamp = timestamp
        this.success = success
        this.stage = stage
        this.errorCode = errorCode
        this.errorMessage = errorMessage
    }
}
