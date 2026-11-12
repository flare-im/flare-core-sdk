package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Payload of notification.badge: the app badge as an absolute value. */
data class NotificationBadgeEvent(
    /** wire: `count`. Unread total, counted like the conversation list (archived conversations do not count, muted ones only with mentions). */
    val count: Int = 0,
)
