package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Update center state: the update://state payload and the answer of every update.* call but install.
public class UpdateStatus {
    // wire: `state`. idle, checking, upToDate, available, required, downloading, verifying, readyToInstall, installing or failed.
    public let state: String
    // wire: `current`. The running app.
    public let current: UpdateCurrentApp
    // wire: `release`. Optional. The release on offer. Can be absent in required: the server rejected this build and no manifest arrived yet.
    public let release: ?UpdateReleaseSummary
    // wire: `progress`. Optional. Present while downloading.
    public let progress: ?UpdateProgress
    // wire: `prompt`. none, badge, sheet, modal or fullscreen. The core keeps it through the whole flow; bind to it directly.
    public let prompt: String
    // wire: `blockUi`. A forced update blocks the interface.
    public let blockUi: Bool
    // wire: `readOnly`. The connection was refused with UPGRADE_REQUIRED or REST answered 426.
    public let readOnly: Bool
    // wire: `lastCheckedAt`. Optional. Last successful check, Unix milliseconds.
    public let lastCheckedAt: ?Int64
    // wire: `error`. Optional. Why the last action did not go through.
    public let error: ?UpdateErrorInfo
    // wire: `blockReason`. Optional. Why this build is blocked, in the chosen language. Present when the current build falls in blockedBuilds and the range gives a reason; a forced prompt shows it ahead of the fixed text.
    public let blockReason: ?String

    public init(state!: String, current!: UpdateCurrentApp, release!: ?UpdateReleaseSummary, progress!: ?UpdateProgress, prompt!: String, blockUi!: Bool, readOnly!: Bool, lastCheckedAt!: ?Int64, error!: ?UpdateErrorInfo, blockReason!: ?String) {
        this.state = state
        this.current = current
        this.release = release
        this.progress = progress
        this.prompt = prompt
        this.blockUi = blockUi
        this.readOnly = readOnly
        this.lastCheckedAt = lastCheckedAt
        this.error = error
        this.blockReason = blockReason
    }
}
