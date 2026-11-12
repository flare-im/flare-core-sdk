import Foundation

/// GENERATED. Do not edit by hand.
/// How the platform should show one remote push.
public struct RemoteMessageOutcome: Codable, Sendable {
    /// wire: `action`. present (a new notification, may sound), update (silently replace the notification with the same collapse id), clear (remove the notifications in clearCollapseIds), badgeOnly (only set the badge) or ignore.
    public let action: String
    /// wire: `badge`. Absolute app badge, when the payload carried one.
    public let badge: UInt32?
    /// wire: `clearCollapseIds`. Collapse ids of the notifications to remove, for clear.
    public let clearCollapseIds: [String]
    /// wire: `presentation`. What to show, for present and update.
    public let presentation: NotificationPresentation?
    /// wire: `reason`. Why the push is ignored (diagnostic): otherAccount, notLoggedIn, stale, alreadyAlerted or malformed.
    public let reason: String?

    public init(action: String = "", badge: UInt32? = nil, clearCollapseIds: [String] = [], presentation: NotificationPresentation? = nil, reason: String? = nil) {
        self.action = action
        self.badge = badge
        self.clearCollapseIds = clearCollapseIds
        self.presentation = presentation
        self.reason = reason
    }
}
