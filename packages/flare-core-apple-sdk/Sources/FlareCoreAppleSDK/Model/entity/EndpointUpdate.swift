import Foundation

/// GENERATED. Do not edit by hand.
/// Result of accepting a new set of addresses. Link readiness is reported separately through normal connection status.
public struct EndpointUpdate: Codable, Sendable {
    /// wire: `changed`. 
    public let changed: Bool
    /// wire: `revision`. Accepted endpoint generation for this initialized client.
    public let revision: UInt32

    public init(changed: Bool = false, revision: UInt32 = 0) {
        self.changed = changed
        self.revision = revision
    }
}
