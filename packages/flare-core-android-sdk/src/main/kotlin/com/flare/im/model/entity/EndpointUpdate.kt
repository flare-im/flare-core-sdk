package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Result of accepting a new set of addresses. Link readiness is reported separately through normal connection status. */
data class EndpointUpdate(
    /** wire: `changed`.  */
    val changed: Boolean = false,
    /** wire: `revision`. Accepted endpoint generation for this initialized client. */
    val revision: Int = 0,
)
