import Foundation

/// GENERATED. Do not edit by hand.
/// What a newly accepted access manifest changed.
public struct AccessChanges: Codable, Sendable {
    /// wire: `accessPointsAdded`. Access points that appeared.
    public let accessPointsAdded: [String]
    /// wire: `accessPointsRemoved`. Access points that disappeared.
    public let accessPointsRemoved: [String]
    /// wire: `policyChanged`. Whether the client link policy changed.
    public let policyChanged: Bool

    public init(accessPointsAdded: [String] = [], accessPointsRemoved: [String] = [], policyChanged: Bool = false) {
        self.accessPointsAdded = accessPointsAdded
        self.accessPointsRemoved = accessPointsRemoved
        self.policyChanged = policyChanged
    }
}
