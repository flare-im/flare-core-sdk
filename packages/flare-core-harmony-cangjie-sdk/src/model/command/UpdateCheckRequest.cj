package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Checks for an update.
public class UpdateCheckRequest {
    // wire: `manual`. The user asked: no frequency limit, and a failure lands in UpdateStatus.error.
    public let manual: Bool

    public init(manual!: Bool) {
        this.manual = manual
    }
}
