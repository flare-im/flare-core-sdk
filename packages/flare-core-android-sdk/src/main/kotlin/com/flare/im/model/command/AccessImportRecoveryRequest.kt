package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** Imports a recovery link. */
data class AccessImportRecoveryRequest(
    /** wire: `link`. The flare-recover:// deep link or QR code content, verbatim. */
    val link: String = "",
)
