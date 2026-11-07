import Foundation

/// GENERATED. Do not edit by hand.
/// Payload of access://switched: the IM connection moved to another access point (sent once, when the new connection is ready).
public struct AccessSwitchedEvent: Codable, Sendable {
    /// wire: `from`. Where the connection was.
    public let from: AccessEndpoint
    /// wire: `to`. Where the connection is now.
    public let to: AccessEndpoint
    /// wire: `reason`. Why: failure, drain, failback, manual or manifest.
    public let reason: String

    public init(from: AccessEndpoint, to: AccessEndpoint, reason: String = "") {
        self.from = from
        self.to = to
        self.reason = reason
    }
}
