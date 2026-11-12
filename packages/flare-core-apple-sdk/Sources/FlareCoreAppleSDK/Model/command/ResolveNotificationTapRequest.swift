import Foundation

/// GENERATED. Do not edit by hand.
/// The payload of a notification the user tapped.
public struct ResolveNotificationTapRequest: Codable, Sendable {
    /// wire: `payload`. The push payload flattened to strings, as in handleRemoteMessage.
    public let payload: [String: String]

    public init(payload: [String: String] = [:]) {
        self.payload = payload
    }
}
