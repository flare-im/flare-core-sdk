package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** The release on offer. */
data class UpdateReleaseSummary(
    /** wire: `releaseId`. Release id. */
    val releaseId: String = "",
    /** wire: `version`. Display version. */
    val version: String = "",
    /** wire: `build`. Build number. */
    val build: Long = 0L,
    /** wire: `notes`. Release notes, already in the chosen language. */
    val notes: List<String> = emptyList(),
    /** wire: `sizeBytes`. Size to download; absent for a store. */
    val sizeBytes: Long? = null,
    /** wire: `mandatory`. Forced update. */
    val mandatory: Boolean = false,
    /** wire: `recommended`. Recommended update. */
    val recommended: Boolean = false,
    /** wire: `kind`. store, package, webBundle or desktop. */
    val kind: String = "",
)
