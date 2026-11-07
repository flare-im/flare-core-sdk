package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Result of importing a recovery link.
public class AccessRecoveryImport {
    // wire: `outcome`. adopted, unchanged (this link was already imported) or rejected.
    public let outcome: String
    // wire: `code`. Optional. Why a link was rejected: a code of AccessRefreshAttempt.code or developmentMode. Commonly rollback (the link is older than this device's manifest) or badSignature.
    public let code: ?String
    // wire: `serial`. Directory serial after the import.
    public let serial: UInt64

    public init(outcome!: String, code!: ?String, serial!: UInt64) {
        this.outcome = outcome
        this.code = code
        this.serial = serial
    }
}
