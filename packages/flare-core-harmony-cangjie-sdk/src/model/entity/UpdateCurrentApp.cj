package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The running app.
public class UpdateCurrentApp {
    // wire: `version`. Optional. Display version.
    public let version: ?String
    // wire: `build`. Optional. Build number.
    public let build: ?UInt64
    // wire: `channel`. Update channel.
    public let channel: String
    // wire: `distribution`. Optional. Distribution channel.
    public let distribution: ?String

    public init(version!: ?String, build!: ?UInt64, channel!: String, distribution!: ?String) {
        this.version = version
        this.build = build
        this.channel = channel
        this.distribution = distribution
    }
}
