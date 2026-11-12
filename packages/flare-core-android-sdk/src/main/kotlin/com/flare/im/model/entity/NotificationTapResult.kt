package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Where a tapped notification leads; every field is absent when the payload is not for the current account. */
data class NotificationTapResult(
    /** wire: `conversationId`. Conversation to open. */
    val conversationId: String? = null,
    /** wire: `messageId`. Message to scroll to, when the payload named one. */
    val messageId: String? = null,
    /** wire: `seq`. Conversation seq of that message. */
    val seq: Long? = null,
)
