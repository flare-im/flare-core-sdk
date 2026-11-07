package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Diagnostics the gateway returned in CONNECT_ACK for the current connection; shown only, nothing acts on them. */
data class AccessConnectAck(
    /** wire: `gatewayId`. Gateway instance serving the connection. */
    val gatewayId: String? = null,
    /** wire: `accessPointId`. Access point the server reports for the connection, when its gateway is configured with one. */
    val accessPointId: String? = null,
    /** wire: `accessSerial`. Newest access manifest serial the server knows. */
    val accessSerial: Long? = null,
    /** wire: `heartbeatIntervalHintSec`. Gateway heartbeat interval in seconds; the heartbeat itself follows the access policy. */
    val heartbeatIntervalHintSec: Int? = null,
    /** wire: `accessPointMismatch`. The server reports a different access point than the client chose; logged and counted, the connection stays up. */
    val accessPointMismatch: Boolean = false,
)
