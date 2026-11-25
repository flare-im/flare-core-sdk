package flare_core_harmony_cangjie_sdk.model.event.sync

import flare_core_harmony_cangjie_sdk.model.common.error.SdkErrorPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Sync orchestration notification payload.
public class SyncEvent {
    // wire: `name`. Sync event name.
    public let name: SyncEventName
    // wire: `runId`. Optional. Stable sync run id used to correlate readiness, progress, and completion.
    public let runId: ?String
    // wire: `trigger`. Optional. Sync trigger.
    public let trigger: ?String
    // wire: `scope`. Optional. Sync scope.
    public let scope: ?String
    // wire: `visibility`. Optional. Sync visibility policy.
    public let visibility: ?String
    // wire: `reason`. Optional. Sync reason for diagnostics and startup wait reports.
    public let reason: ?String
    // wire: `phase`. Optional. Sync phase.
    public let phase: ?String
    // wire: `task`. Optional. Sync task name.
    public let task: ?String
    // wire: `stage`. Optional. Readiness stage for sync.readiness events.
    public let stage: ?String
    // wire: `progress`. Optional. Progress percentage from 0 to 100.
    public let progress: ?UInt32
    // wire: `error`. Optional. Failure details for failed sync events.
    public let error: ?SdkErrorPayload

    public init(name!: SyncEventName, runId!: ?String, trigger!: ?String, scope!: ?String, visibility!: ?String, reason!: ?String, phase!: ?String, task!: ?String, stage!: ?String, progress!: ?UInt32, error!: ?SdkErrorPayload) {
        this.name = name
        this.runId = runId
        this.trigger = trigger
        this.scope = scope
        this.visibility = visibility
        this.reason = reason
        this.phase = phase
        this.task = task
        this.stage = stage
        this.progress = progress
        this.error = error
    }
}
