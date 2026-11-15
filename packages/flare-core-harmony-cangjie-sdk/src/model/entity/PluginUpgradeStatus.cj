package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Whether an update reaching a plugin's minimum build is offered to this device.
public class PluginUpgradeStatus {
    // wire: `available`. A release at or above the floor is offered.
    public let available: Bool
    // wire: `build`. Optional. That release's build, when available.
    public let build: ?UInt64

    public init(available!: Bool, build!: ?UInt64) {
        this.available = available
        this.build = build
    }
}
