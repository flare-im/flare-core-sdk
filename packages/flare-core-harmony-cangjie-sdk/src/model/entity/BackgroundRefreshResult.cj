package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// How a background refresh ended.
public class BackgroundRefreshResult {
    // wire: `completed`. The link came up and the incremental sync finished within the budget. False when the budget ran out or no session could connect.
    public let completed: Bool

    public init(completed!: Bool) {
        this.completed = completed
    }
}
