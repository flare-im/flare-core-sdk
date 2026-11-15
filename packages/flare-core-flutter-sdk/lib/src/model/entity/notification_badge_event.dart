// GENERATED. Do not edit by hand.

/// Payload of notification.badge: the app badge as an absolute value.
final class NotificationBadgeEvent {
  /// wire: `count`. Unread total, counted like the conversation list (archived conversations do not count, muted ones only with mentions).
  final int count;

  const NotificationBadgeEvent({
    this.count = 0,
  });
}
