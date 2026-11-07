package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** Pins one access point of the home cell. */
data class AccessPinRequest(
    /** wire: `accessPointId`. Access point to pin, as listed by access.listAccessPoints. */
    val accessPointId: String = "",
)
