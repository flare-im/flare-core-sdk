import Foundation

/// GENERATED. Do not edit by hand.
/// Downloads the package of the offered release.
public struct UpdateDownloadRequest: Codable, Sendable {
    /// wire: `allowMetered`. The user agreed to download on a metered network.
    public let allowMetered: Bool

    public init(allowMetered: Bool = false) {
        self.allowMetered = allowMetered
    }
}
