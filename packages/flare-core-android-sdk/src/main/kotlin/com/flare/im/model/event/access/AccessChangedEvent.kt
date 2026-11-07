package com.flare.im.model.event.access

/** GENERATED. Do not edit by hand. */
/** Payload of access://changed: a new access manifest was accepted. Sent for every adoption; a periodic re-signature has empty changes. */
data class AccessChangedEvent(
    /** wire: `serial`. Serial of the accepted manifest. */
    val serial: Long = 0L,
    /** wire: `source`. Where it came from, in the form of AccessStatus.source. */
    val source: String = "",
    /** wire: `stale`. Whether it is past its expiry. */
    val stale: Boolean = false,
    /** wire: `developmentMode`. Endpoints come from development-mode configuration. */
    val developmentMode: Boolean = false,
    /** wire: `changes`. What changed against the previous manifest. */
    val changes: AccessChanges,
)
