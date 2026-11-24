package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** Select the IM connection transport. */
data class SetProtocolModeRequest(
    /** wire: `mode`. Transport mode: ws, quic, or race. */
    val mode: String = "",
)
