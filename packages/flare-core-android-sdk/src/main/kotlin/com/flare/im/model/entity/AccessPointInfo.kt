package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** One access point of the home cell with its health on the current network. */
data class AccessPointInfo(
    /** wire: `accessPointId`. Access point id. */
    val accessPointId: String = "",
    /** wire: `regionId`. Region the access point is in. */
    val regionId: String = "",
    /** wire: `host`. Host name shown on the diagnostics page. */
    val host: String = "",
    /** wire: `status`. Manifest status: active, draining, disabled or unknown. */
    val status: String = "",
    /** wire: `rttMs`. Smoothed round trip on the current network, when measured. */
    val rttMs: Double? = null,
    /** wire: `breaker`. Circuit breaker state: closed, open or halfOpen. */
    val breaker: String = "",
    /** wire: `protocolWinner`. Protocol that last won the race on this network: quic or ws. */
    val protocolWinner: String? = null,
    /** wire: `pinned`. Whether this access point is manually pinned. */
    val pinned: Boolean = false,
    /** wire: `current`. Whether the IM connection is on this access point. */
    val current: Boolean = false,
)
