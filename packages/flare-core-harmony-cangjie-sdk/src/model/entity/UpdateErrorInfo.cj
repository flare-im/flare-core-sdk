package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Why the last update action did not go through.
public class UpdateErrorInfo {
    // wire: `code`. update.* code.
    public let code: String
    // wire: `retryable`. Retrying can help.
    public let retryable: Bool
    // wire: `fallbackUrl`. Optional. Page to send the user to; absent on the web.
    public let fallbackUrl: ?String

    public init(code!: String, retryable!: Bool, fallbackUrl!: ?String) {
        this.code = code
        this.retryable = retryable
        this.fallbackUrl = fallbackUrl
    }
}
