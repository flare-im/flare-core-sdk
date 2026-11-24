import Foundation

/// GENERATED. Do not edit by hand.
/// Stage reached by an outbound message.
public enum MessageSendStage: String, Codable, Sendable {
    case queued = "queued"
    case accepted = "accepted"
    case persisted = "persisted"
    case failed = "failed"
}
