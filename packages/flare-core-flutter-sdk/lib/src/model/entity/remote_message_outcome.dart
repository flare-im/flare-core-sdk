// GENERATED. Do not edit by hand.
import 'notification_presentation.dart';

/// How the platform should show one remote push.
final class RemoteMessageOutcome {
  /// wire: `action`. present (a new notification, may sound), update (silently replace the notification with the same collapse id), clear (remove the notifications in clearCollapseIds), badgeOnly (only set the badge) or ignore.
  final String action;
  /// wire: `badge`. Absolute app badge, when the payload carried one.
  final int? badge;
  /// wire: `clearCollapseIds`. Collapse ids of the notifications to remove, for clear.
  final List<String> clearCollapseIds;
  /// wire: `presentation`. What to show, for present and update.
  final NotificationPresentation? presentation;
  /// wire: `reason`. Why the push is ignored (diagnostic): otherAccount, notLoggedIn, stale, alreadyAlerted or malformed.
  final String? reason;

  const RemoteMessageOutcome({
    this.action = '',
    this.badge,
    this.clearCollapseIds = const [],
    this.presentation,
    this.reason,
  });
}
