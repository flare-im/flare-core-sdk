package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One background refresh the platform granted the app (iOS BGAppRefreshTask).
public class BackgroundRefreshRequest {
    // wire: `budgetMs`. Time the platform grants, in milliseconds; the engine uses at most 25000 of it.
    public let budgetMs: UInt32

    public init(budgetMs!: UInt32) {
        this.budgetMs = budgetMs
    }
}
