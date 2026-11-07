package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** The running app. */
data class UpdateCurrentApp(
    /** wire: `version`. Display version. */
    val version: String? = null,
    /** wire: `build`. Build number. */
    val build: Long? = null,
    /** wire: `channel`. Update channel. */
    val channel: String = "",
    /** wire: `distribution`. Distribution channel. */
    val distribution: String? = null,
)
