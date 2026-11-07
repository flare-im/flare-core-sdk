package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Downloads the package of the offered release.
public class UpdateDownloadRequest {
    // wire: `allowMetered`. The user agreed to download on a metered network.
    public let allowMetered: Bool

    public init(allowMetered!: Bool) {
        this.allowMetered = allowMetered
    }
}
