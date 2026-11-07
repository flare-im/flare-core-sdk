package flare_core_harmony_cangjie_sdk.model.event.access

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// What a newly accepted access manifest changed.
public class AccessChanges {
    // wire: `accessPointsAdded`. Access points that appeared.
    public let accessPointsAdded: String
    // wire: `accessPointsRemoved`. Access points that disappeared.
    public let accessPointsRemoved: String
    // wire: `policyChanged`. Whether the client link policy changed.
    public let policyChanged: Bool

    public init(accessPointsAdded!: String, accessPointsRemoved!: String, policyChanged!: Bool) {
        this.accessPointsAdded = accessPointsAdded
        this.accessPointsRemoved = accessPointsRemoved
        this.policyChanged = policyChanged
    }
}
