package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** CoreEndpoints */
data class CoreEndpoints(
    /** wire: `baseUrl`. Core API base URL, including any deployment path prefix. */
    val baseUrl: String = "",
    /** wire: `mediaBaseUrl`. Optional media API base. Defaults to the Core API base. */
    val mediaBaseUrl: String? = null,
    /** wire: `quicUrl`. Optional native QUIC gateway; WebSocket remains available. */
    val quicUrl: String? = null,
    /** wire: `websocketUrl`. Fully qualified WebSocket gateway URL. */
    val websocketUrl: String = "",
)
