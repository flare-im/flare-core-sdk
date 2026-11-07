import Foundation

/// GENERATED. Do not edit by hand.
/// The running app.
public struct UpdateCurrentApp: Codable, Sendable {
    /// wire: `version`. Display version.
    public let version: String?
    /// wire: `build`. Build number.
    public let build: UInt64?
    /// wire: `channel`. Update channel.
    public let channel: String
    /// wire: `distribution`. Distribution channel.
    public let distribution: String?

    public init(version: String? = nil, build: UInt64? = nil, channel: String = "", distribution: String? = nil) {
        self.version = version
        self.build = build
        self.channel = channel
        self.distribution = distribution
    }
}
