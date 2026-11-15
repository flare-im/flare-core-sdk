package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// How the platform should show one remote push.
public class RemoteMessageOutcome {
    // wire: `action`. present (a new notification, may sound), update (silently replace the notification with the same collapse id), clear (remove the notifications in clearCollapseIds), badgeOnly (only set the badge) or ignore.
    public let action: String
    // wire: `badge`. Optional. Absolute app badge, when the payload carried one.
    public let badge: ?UInt32
    // wire: `clearCollapseIds`. Collapse ids of the notifications to remove, for clear.
    public let clearCollapseIds: String
    // wire: `presentation`. Optional. What to show, for present and update.
    public let presentation: ?NotificationPresentation
    // wire: `reason`. Optional. Why the push is ignored (diagnostic): otherAccount, notLoggedIn, stale, alreadyAlerted or malformed.
    public let reason: ?String

    public init(action!: String, badge!: ?UInt32, clearCollapseIds!: String, presentation!: ?NotificationPresentation, reason!: ?String) {
        this.action = action
        this.badge = badge
        this.clearCollapseIds = clearCollapseIds
        this.presentation = presentation
        this.reason = reason
    }
}
