import Foundation

/// GENERATED. Do not edit by hand.
/// Send acknowledgement returned by core-sdk.
public struct SendMessageResponse: Codable, Sendable {
    /// wire: `ackId`. ACK id assigned by the transport layer, if present.
    public let ackId: String
    /// wire: `serverId`. Server-assigned message id.
    public let serverId: String
    /// wire: `clientMsgId`. Client message id acknowledged by the server.
    public let clientMsgId: String
    /// wire: `conversationId`. Conversation id.
    public let conversationId: String
    /// wire: `seq`. Assigned conversation sequence.
    public let seq: UInt64
    /// wire: `timestamp`. Server send time in milliseconds.
    public let timestamp: UInt64
    /// wire: `success`. Whether the SDK queued the message locally or the server accepted it. Check stage for persistence.
    public let success: Bool
    /// wire: `stage`. Queued locally, accepted by the server, persisted by the server, or failed. Older engines omit this field.
    public let stage: MessageSendStage?
    /// wire: `errorCode`. Core ACK error code when success is false.
    public let errorCode: Int32
    /// wire: `errorMessage`. Core ACK error message when success is false.
    public let errorMessage: String

    public init(ackId: String = "", serverId: String = "", clientMsgId: String = "", conversationId: String = "", seq: UInt64 = 0, timestamp: UInt64 = 0, success: Bool = false, stage: MessageSendStage? = nil, errorCode: Int32 = 0, errorMessage: String = "") {
        self.ackId = ackId
        self.serverId = serverId
        self.clientMsgId = clientMsgId
        self.conversationId = conversationId
        self.seq = seq
        self.timestamp = timestamp
        self.success = success
        self.stage = stage
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}
