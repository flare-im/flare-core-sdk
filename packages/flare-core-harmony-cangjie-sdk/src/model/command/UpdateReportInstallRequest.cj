package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// What the platform package did with the install plan.
public class UpdateReportInstallRequest {
    // wire: `outcome`. started, completed, cancelled or failed.
    public let outcome: String
    // wire: `code`. Optional. update.* code when outcome is failed.
    public let code: ?String

    public init(outcome!: String, code!: ?String) {
        this.outcome = outcome
        this.code = code
    }
}
