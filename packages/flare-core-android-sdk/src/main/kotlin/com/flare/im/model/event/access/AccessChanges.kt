package com.flare.im.model.event.access

/** GENERATED. Do not edit by hand. */
/** What a newly accepted access manifest changed. */
data class AccessChanges(
    /** wire: `accessPointsAdded`. Access points that appeared. */
    val accessPointsAdded: List<String> = emptyList(),
    /** wire: `accessPointsRemoved`. Access points that disappeared. */
    val accessPointsRemoved: List<String> = emptyList(),
    /** wire: `policyChanged`. Whether the client link policy changed. */
    val policyChanged: Boolean = false,
)
