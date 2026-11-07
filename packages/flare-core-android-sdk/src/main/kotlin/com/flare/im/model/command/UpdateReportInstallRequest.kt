package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** What the platform package did with the install plan. */
data class UpdateReportInstallRequest(
    /** wire: `outcome`. started, completed, cancelled or failed. */
    val outcome: String = "",
    /** wire: `code`. update.* code when outcome is failed. */
    val code: String? = null,
)
