package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Imports a recovery link.
public class AccessImportRecoveryRequest {
    // wire: `link`. The flare-recover:// deep link or QR code content, verbatim.
    public let link: String

    public init(link!: String) {
        this.link = link
    }
}
