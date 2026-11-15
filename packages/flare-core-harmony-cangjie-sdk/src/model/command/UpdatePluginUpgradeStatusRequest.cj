package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// A plugin's minimum build to reach.
public class UpdatePluginUpgradeStatusRequest {
    // wire: `minBuild`. Optional. The placeholder's minBuild; absent asks for any build newer than this one.
    public let minBuild: ?UInt64

    public init(minBuild!: ?UInt64) {
        this.minBuild = minBuild
    }
}
