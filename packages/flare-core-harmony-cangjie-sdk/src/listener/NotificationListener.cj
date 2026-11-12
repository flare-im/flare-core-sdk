package flare_core_harmony_cangjie_sdk.listener

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Notification listener callbacks.
public interface NotificationEventListener {
    // Show a notification, or replace the one with the same collapseId: an in-app banner (surface inApp) while the app is in the foreground, a system notification (surface system) while it is in the background and the platform presents alerts itself. Title and body are rendered in the app's language; sound says whether to play one.
    func onNotificationPresent(event: NotificationPresentation): Unit
    // Remove the notifications with these collapse ids (their conversations were read or deleted), or every notification of the app when all is true (the session ended).
    func onNotificationClear(event: NotificationClearEvent): Unit
    // Set the app badge to count, the unread total as the conversation list counts it. Reported when the total changes, after login and when the app returns to the foreground.
    func onNotificationBadge(event: NotificationBadgeEvent): Unit
}
