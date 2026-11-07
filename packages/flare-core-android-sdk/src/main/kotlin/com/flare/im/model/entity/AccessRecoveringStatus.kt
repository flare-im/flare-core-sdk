package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Recovery state while every access point has failed. */
data class AccessRecoveringStatus(
    /** wire: `sinceMs`. When recovery began, Unix milliseconds. */
    val sinceMs: Long = 0L,
    /** wire: `rounds`. Bootstrap rounds run so far. */
    val rounds: Int = 0,
    /** wire: `nextRoundAtMs`. When the next round runs, Unix milliseconds; absent while the device has no network. */
    val nextRoundAtMs: Long? = null,
)
