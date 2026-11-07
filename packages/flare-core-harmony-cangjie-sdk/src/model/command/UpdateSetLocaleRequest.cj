package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Chooses the language of the release notes and blockReason.
public class UpdateSetLocaleRequest {
    // wire: `locale`. BCP 47 tag, for example zh-Hant-TW.
    public let locale: String

    public init(locale!: String) {
        this.locale = locale
    }
}
