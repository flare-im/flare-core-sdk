package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Payload of notification.clear: remove these notifications of the app. */
data class NotificationClearEvent(
    /** wire: `all`. Remove every notification of the app (the session ended); collapseIds is then empty. */
    val all: Boolean = false,
    /** wire: `collapseIds`. Collapse ids of the notifications to remove. */
    val collapseIds: List<String> = emptyList(),
)
