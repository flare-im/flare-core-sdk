import Foundation

/// GENERATED. Do not edit by hand.
/// Payload of access://changed: a new access manifest was accepted. Sent for every adoption; a periodic re-signature has empty changes.
public struct AccessChangedEvent: Codable, Sendable {
    /// wire: `serial`. Serial of the accepted manifest.
    public let serial: UInt64
    /// wire: `source`. Where it came from, in the form of AccessStatus.source.
    public let source: String
    /// wire: `stale`. Whether it is past its expiry.
    public let stale: Bool
    /// wire: `developmentMode`. Endpoints come from development-mode configuration.
    public let developmentMode: Bool
    /// wire: `changes`. What changed against the previous manifest.
    public let changes: AccessChanges

    public init(serial: UInt64 = 0, source: String = "", stale: Bool = false, developmentMode: Bool = false, changes: AccessChanges) {
        self.serial = serial
        self.source = source
        self.stale = stale
        self.developmentMode = developmentMode
        self.changes = changes
    }
}
