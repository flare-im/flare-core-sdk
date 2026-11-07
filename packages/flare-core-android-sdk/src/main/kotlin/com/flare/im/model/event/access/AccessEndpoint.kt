package com.flare.im.model.event.access

/** GENERATED. Do not edit by hand. */
/** One side of an access point switch. */
data class AccessEndpoint(
    /** wire: `ap`. Access point id. */
    val ap: String = "",
    /** wire: `protocol`. Transport: quic or ws. */
    val protocol: String = "",
)
