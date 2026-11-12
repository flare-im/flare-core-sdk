// GENERATED. Do not edit by hand.
import { NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation } from '../model';

/** Notification listener callbacks. */
export interface NotificationEventListener {
  /** Show a notification, or replace the one with the same collapseId: an in-app banner (surface inApp) while the app is in the foreground, a system notification (surface system) while it is in the background and the platform presents alerts itself. Title and body are rendered in the app's language; sound says whether to play one. */
  onNotificationPresent?(event: NotificationPresentation): void;
  /** Remove the notifications with these collapse ids (their conversations were read or deleted), or every notification of the app when all is true (the session ended). */
  onNotificationClear?(event: NotificationClearEvent): void;
  /** Set the app badge to count, the unread total as the conversation list counts it. Reported when the total changes, after login and when the app returns to the foreground. */
  onNotificationBadge?(event: NotificationBadgeEvent): void;
}
