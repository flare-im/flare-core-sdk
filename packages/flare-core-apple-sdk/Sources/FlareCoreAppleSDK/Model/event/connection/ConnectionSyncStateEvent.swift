import Foundation

/// GENERATED. Do not edit by hand.
/// Payload of the coarse sync state hint (connection.sync_state_changed). Connection status itself arrives as ConnectionStatus.
public struct ConnectionSyncStateEvent: Codable, Sendable {
    /// wire: `state`. The core sync state name.
    public let state: String

    public init(state: String = "") {
        self.state = state
    }
}
