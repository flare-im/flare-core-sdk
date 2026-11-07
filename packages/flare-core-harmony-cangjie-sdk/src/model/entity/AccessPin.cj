package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// A manual access point pin.
public class AccessPin {
    // wire: `accessPointId`. The pinned access point.
    public let accessPointId: String
    // wire: `expiresAtMs`. When the pin lapses, Unix milliseconds; an app restart also clears it.
    public let expiresAtMs: Int64

    public init(accessPointId!: String, expiresAtMs!: Int64) {
        this.accessPointId = accessPointId
        this.expiresAtMs = expiresAtMs
    }
}
