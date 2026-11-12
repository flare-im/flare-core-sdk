// GENERATED. Do not edit by hand.

/// Payload of notification.clear: remove these notifications of the app.
final class NotificationClearEvent {
  /// wire: `all`. Remove every notification of the app (the session ended); collapseIds is then empty.
  final bool all;
  /// wire: `collapseIds`. Collapse ids of the notifications to remove.
  final List<String> collapseIds;

  const NotificationClearEvent({
    this.all = false,
    this.collapseIds = const [],
  });
}
