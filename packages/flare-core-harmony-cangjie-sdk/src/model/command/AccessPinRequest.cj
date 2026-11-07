package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Pins one access point of the home cell.
public class AccessPinRequest {
    // wire: `accessPointId`. Access point to pin, as listed by access.listAccessPoints.
    public let accessPointId: String

    public init(accessPointId!: String) {
        this.accessPointId = accessPointId
    }
}
