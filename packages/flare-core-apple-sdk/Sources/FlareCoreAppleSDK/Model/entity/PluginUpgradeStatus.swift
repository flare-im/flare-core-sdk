import Foundation

/// GENERATED. Do not edit by hand.
/// Whether an update reaching a plugin's minimum build is offered to this device.
public struct PluginUpgradeStatus: Codable, Sendable {
    /// wire: `available`. A release at or above the floor is offered.
    public let available: Bool
    /// wire: `build`. That release's build, when available.
    public let build: UInt64?

    public init(available: Bool = false, build: UInt64? = nil) {
        self.available = available
        self.build = build
    }
}
