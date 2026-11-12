package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Payload of notification.badge: the app badge as an absolute value.
public class NotificationBadgeEvent {
    // wire: `count`. Unread total, counted like the conversation list (archived conversations do not count, muted ones only with mentions).
    public let count: UInt32

    public init(count!: UInt32) {
        this.count = count
    }
}
