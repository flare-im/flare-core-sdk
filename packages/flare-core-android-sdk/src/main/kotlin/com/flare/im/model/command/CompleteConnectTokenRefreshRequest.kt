package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** Answer to one connect token refresh request. */
data class CompleteConnectTokenRefreshRequest(
    /** wire: `requestId`. Request id the core asked with. */
    val requestId: Long = 0L,
    /** wire: `token`. The new connect token; omitted or empty when none could be obtained. */
    val token: String? = null,
)
