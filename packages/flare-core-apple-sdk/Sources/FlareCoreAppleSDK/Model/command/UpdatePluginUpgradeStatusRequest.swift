import Foundation

/// GENERATED. Do not edit by hand.
/// A plugin's minimum build to reach.
public struct UpdatePluginUpgradeStatusRequest: Codable, Sendable {
    /// wire: `minBuild`. The placeholder's minBuild; absent asks for any build newer than this one.
    public let minBuild: UInt64?

    public init(minBuild: UInt64? = nil) {
        self.minBuild = minBuild
    }
}
