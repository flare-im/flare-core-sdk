import Foundation

/// GENERATED. Do not edit by hand.
/// Update center state: the update://state payload and the answer of every update.* call but install.
public struct UpdateStatus: Codable, Sendable {
    /// wire: `state`. idle, checking, upToDate, available, required, downloading, verifying, readyToInstall, installing or failed.
    public let state: String
    /// wire: `current`. The running app.
    public let current: UpdateCurrentApp
    /// wire: `release`. The release on offer. Can be absent in required: the server rejected this build and no manifest arrived yet.
    public let release: UpdateReleaseSummary?
    /// wire: `progress`. Present while downloading.
    public let progress: UpdateProgress?
    /// wire: `prompt`. none, badge, sheet, modal or fullscreen. The core keeps it through the whole flow; bind to it directly.
    public let prompt: String
    /// wire: `blockUi`. A forced update blocks the interface.
    public let blockUi: Bool
    /// wire: `readOnly`. The connection was refused with UPGRADE_REQUIRED or REST answered 426.
    public let readOnly: Bool
    /// wire: `lastCheckedAt`. Last successful check, Unix milliseconds.
    public let lastCheckedAt: Int64?
    /// wire: `error`. Why the last action did not go through.
    public let error: UpdateErrorInfo?
    /// wire: `blockReason`. Why this build is blocked, in the chosen language. Present when the current build falls in blockedBuilds and the range gives a reason; a forced prompt shows it ahead of the fixed text.
    public let blockReason: String?

    public init(state: String = "", current: UpdateCurrentApp, release: UpdateReleaseSummary? = nil, progress: UpdateProgress? = nil, prompt: String = "", blockUi: Bool = false, readOnly: Bool = false, lastCheckedAt: Int64? = nil, error: UpdateErrorInfo? = nil, blockReason: String? = nil) {
        self.state = state
        self.current = current
        self.release = release
        self.progress = progress
        self.prompt = prompt
        self.blockUi = blockUi
        self.readOnly = readOnly
        self.lastCheckedAt = lastCheckedAt
        self.error = error
        self.blockReason = blockReason
    }
}
