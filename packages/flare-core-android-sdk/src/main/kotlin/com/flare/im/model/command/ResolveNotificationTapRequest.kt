package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** The payload of a notification the user tapped. */
data class ResolveNotificationTapRequest(
    /** wire: `payload`. The push payload flattened to strings, as in handleRemoteMessage. */
    val payload: Map<String, String> = emptyMap(),
)
