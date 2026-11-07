import Foundation

/// GENERATED. Do not edit by hand.
/// Connection event name: the one status event, and the coarse sync state hint.
public enum ConnectionEventName: String, Codable, Sendable {
    case status = "status"
    case syncStateChanged = "sync_state_changed"
}
