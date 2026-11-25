package flare_core_harmony_cangjie_sdk.model.response

import flare_core_harmony_cangjie_sdk.model.entity.HomeTimelineSnapshot

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// First usable home snapshot plus diagnostics about the startup sync path.
public class StartupHomeSyncResponse {
    // wire: `backgroundConvergenceStarted`. 
    public let backgroundConvergenceStarted: Bool
    // wire: `coldSyncPerformed`. 
    public let coldSyncPerformed: Bool
    // wire: `degradedReason`. Optional. 
    public let degradedReason: ?String
    // wire: `servedFromLocal`. 
    public let servedFromLocal: Bool
    // wire: `snapshot`. 
    public let snapshot: HomeTimelineSnapshot

    public init(backgroundConvergenceStarted!: Bool, coldSyncPerformed!: Bool, degradedReason!: ?String, servedFromLocal!: Bool, snapshot!: HomeTimelineSnapshot) {
        this.backgroundConvergenceStarted = backgroundConvergenceStarted
        this.coldSyncPerformed = coldSyncPerformed
        this.degradedReason = degradedReason
        this.servedFromLocal = servedFromLocal
        this.snapshot = snapshot
    }
}
