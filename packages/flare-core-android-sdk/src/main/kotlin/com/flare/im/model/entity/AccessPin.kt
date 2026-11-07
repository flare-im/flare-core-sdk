package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** A manual access point pin. */
data class AccessPin(
    /** wire: `accessPointId`. The pinned access point. */
    val accessPointId: String = "",
    /** wire: `expiresAtMs`. When the pin lapses, Unix milliseconds; an app restart also clears it. */
    val expiresAtMs: Long = 0L,
)
