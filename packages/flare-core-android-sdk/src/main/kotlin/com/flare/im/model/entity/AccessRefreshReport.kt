package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Result of one refresh round. */
data class AccessRefreshReport(
    /** wire: `outcome`. adopted (a new manifest was taken), upToDate (a source confirmed there is no update), oldValues (notified mode only got old values; a manual refresh never reports it), failed (no source gave a trusted answer) or skipped (development mode). */
    val outcome: String = "",
    /** wire: `mode`. Round mode: background, notified or recovering. */
    val mode: String = "",
    /** wire: `serial`. Directory serial when the round ended. */
    val serial: Long = 0L,
    /** wire: `source`. Source of the adopted manifest, in the form of AccessStatus.source; absent when nothing was adopted. */
    val source: String? = null,
    /** wire: `keystateSerial`. Serial of the current key state document. */
    val keystateSerial: Long? = null,
    /** wire: `attempts`. Every source tried, in order. */
    val attempts: List<AccessRefreshAttempt> = emptyList(),
)
