import Foundation

/// GENERATED. Do not edit by hand.
/// A manual access point pin.
public struct AccessPin: Codable, Sendable {
    /// wire: `accessPointId`. The pinned access point.
    public let accessPointId: String
    /// wire: `expiresAtMs`. When the pin lapses, Unix milliseconds; an app restart also clears it.
    public let expiresAtMs: Int64

    public init(accessPointId: String = "", expiresAtMs: Int64 = 0) {
        self.accessPointId = accessPointId
        self.expiresAtMs = expiresAtMs
    }
}
