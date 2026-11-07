package com.flare.im.model.event.connection

/** GENERATED. Do not edit by hand. */
/** Payload of the coarse sync state hint (connection.sync_state_changed). Connection status itself arrives as ConnectionStatus. */
data class ConnectionSyncStateEvent(
    /** wire: `state`. The core sync state name. */
    val state: String = "",
)
