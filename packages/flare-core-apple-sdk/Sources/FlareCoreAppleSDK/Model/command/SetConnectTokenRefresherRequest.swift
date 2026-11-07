import Foundation

/// GENERATED. Do not edit by hand.
/// Installs or removes the host's connect token refresher at the native boundary. Platform packages build it from their one host function; hosts do not send it themselves.
public struct SetConnectTokenRefresherRequest: Codable, Sendable {
    /// wire: `enabled`. Whether a refresher is installed.
    public let enabled: Bool

    public init(enabled: Bool = false) {
        self.enabled = enabled
    }
}
