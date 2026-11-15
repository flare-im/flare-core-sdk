package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** The conversation the user is looking at. */
data class SetNotificationFocusRequest(
    /** wire: `conversationId`. Conversation on screen; absent when no conversation is open. */
    val conversationId: String? = null,
)
