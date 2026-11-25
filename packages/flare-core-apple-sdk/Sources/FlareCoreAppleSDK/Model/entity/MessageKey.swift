import Foundation

/// GENERATED. Do not edit by hand.
/// 
public struct MessageKey: Codable, Sendable {
    /// wire: `conversationId`. 
    public let conversationId: String
    /// wire: `senderId`. 
    public let senderId: String
    /// wire: `clientMsgId`. 
    public let clientMsgId: String

    public init(conversationId: String = "", senderId: String = "", clientMsgId: String = "") {
        self.conversationId = conversationId
        self.senderId = senderId
        self.clientMsgId = clientMsgId
    }
}
