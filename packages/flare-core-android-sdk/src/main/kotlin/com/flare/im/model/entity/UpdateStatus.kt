package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Update center state: the update://state payload and the answer of every update.* call but install. */
data class UpdateStatus(
    /** wire: `state`. idle, checking, upToDate, available, required, downloading, verifying, readyToInstall, installing or failed. */
    val state: String = "",
    /** wire: `current`. The running app. */
    val current: UpdateCurrentApp,
    /** wire: `release`. The release on offer. Can be absent in required: the server rejected this build and no manifest arrived yet. */
    val release: UpdateReleaseSummary? = null,
    /** wire: `progress`. Present while downloading. */
    val progress: UpdateProgress? = null,
    /** wire: `prompt`. none, badge, sheet, modal or fullscreen. The core keeps it through the whole flow; bind to it directly. */
    val prompt: String = "",
    /** wire: `blockUi`. A forced update blocks the interface. */
    val blockUi: Boolean = false,
    /** wire: `readOnly`. The connection was refused with UPGRADE_REQUIRED or REST answered 426. */
    val readOnly: Boolean = false,
    /** wire: `lastCheckedAt`. Last successful check, Unix milliseconds. */
    val lastCheckedAt: Long? = null,
    /** wire: `error`. Why the last action did not go through. */
    val error: UpdateErrorInfo? = null,
    /** wire: `blockReason`. Why this build is blocked, in the chosen language. Present when the current build falls in blockedBuilds and the range gives a reason; a forced prompt shows it ahead of the fixed text. */
    val blockReason: String? = null,
)
