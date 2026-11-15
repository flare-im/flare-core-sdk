import Foundation

/// GENERATED. Do not edit by hand.
/// Payload of notification.badge: the app badge as an absolute value.
public struct NotificationBadgeEvent: Codable, Sendable {
    /// wire: `count`. Unread total, counted like the conversation list (archived conversations do not count, muted ones only with mentions).
    public let count: UInt32

    public init(count: UInt32 = 0) {
        self.count = count
    }
}
