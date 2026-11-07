package com.flare.im.model.event.access

/** GENERATED. Do not edit by hand. */
/** Payload of access://switched: the IM connection moved to another access point (sent once, when the new connection is ready). */
data class AccessSwitchedEvent(
    /** wire: `from`. Where the connection was. */
    val from: AccessEndpoint,
    /** wire: `to`. Where the connection is now. */
    val to: AccessEndpoint,
    /** wire: `reason`. Why: failure, drain, failback, manual or manifest. */
    val reason: String = "",
)
