import Foundation

/// GENERATED. Do not edit by hand.
/// Skips one optional version.
public struct UpdateSkipRequest: Codable, Sendable {
    /// wire: `build`. Build to skip.
    public let build: UInt64

    public init(build: UInt64 = 0) {
        self.build = build
    }
}
