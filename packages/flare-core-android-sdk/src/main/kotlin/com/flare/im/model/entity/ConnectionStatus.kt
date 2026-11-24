package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Payload of connection://status and the value of connection.getStatus. Hosts replace their copy whole on every event. endpointRevision is present for host-selected endpoints. */
data class ConnectionStatus(
    /** wire: `phase`. Where the link supervisor is. */
    val phase: ConnectionPhase,
    /** wire: `quality`. Line quality; set only while online. */
    val quality: ConnectionQuality? = null,
    /** wire: `protocol`. Transport of the current connection: quic or ws. */
    val protocol: String? = null,
    /** wire: `endpointRevision`. Generation of the accepted host-selected address group. */
    val endpointRevision: Int? = null,
    /** wire: `rttMs`. Latest heartbeat round trip (the handshake time before the first sample). */
    val rttMs: Int? = null,
    /** wire: `attempt`. Which round of the current recovery this is; zero once online. */
    val attempt: Int = 0,
    /** wire: `nextRetryAt`. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay). */
    val nextRetryAt: Long? = null,
    /** wire: `reason`. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: drain or manual. Transport failure: transportUnavailable. */
    val reason: String? = null,
    /** wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase. */
    val developmentMode: Boolean = false,
)
