/** GENERATED. Do not edit by hand. */
import type { NotificationPresentation } from './notification_presentation';

/** How the platform should show one remote push. */
export interface RemoteMessageOutcome {
  /** wire: `action`. present (a new notification, may sound), update (silently replace the notification with the same collapse id), clear (remove the notifications in clearCollapseIds), badgeOnly (only set the badge) or ignore. */
  action: string;
  /** wire: `badge`. Absolute app badge, when the payload carried one. */
  badge?: number;
  /** wire: `clearCollapseIds`. Collapse ids of the notifications to remove, for clear. */
  clearCollapseIds: string[];
  /** wire: `presentation`. What to show, for present and update. */
  presentation?: NotificationPresentation;
  /** wire: `reason`. Why the push is ignored (diagnostic): otherAccount, notLoggedIn, stale, alreadyAlerted or malformed. */
  reason?: string;
}
