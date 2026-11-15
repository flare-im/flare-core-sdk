package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** How the platform should show one remote push. */
data class RemoteMessageOutcome(
    /** wire: `action`. present (a new notification, may sound), update (silently replace the notification with the same collapse id), clear (remove the notifications in clearCollapseIds), badgeOnly (only set the badge) or ignore. */
    val action: String = "",
    /** wire: `badge`. Absolute app badge, when the payload carried one. */
    val badge: Int? = null,
    /** wire: `clearCollapseIds`. Collapse ids of the notifications to remove, for clear. */
    val clearCollapseIds: List<String> = emptyList(),
    /** wire: `presentation`. What to show, for present and update. */
    val presentation: NotificationPresentation? = null,
    /** wire: `reason`. Why the push is ignored (diagnostic): otherAccount, notLoggedIn, stale, alreadyAlerted or malformed. */
    val reason: String? = null,
)
