import Foundation

/// GENERATED. Do not edit by hand.
/// Pins one access point of the home cell.
public struct AccessPinRequest: Codable, Sendable {
    /// wire: `accessPointId`. Access point to pin, as listed by access.listAccessPoints.
    public let accessPointId: String

    public init(accessPointId: String = "") {
        self.accessPointId = accessPointId
    }
}
