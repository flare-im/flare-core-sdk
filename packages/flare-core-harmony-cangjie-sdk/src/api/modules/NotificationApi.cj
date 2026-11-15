package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events.
public interface NotificationApi {
    func setFocus(request: SetNotificationFocusRequest): Unit
    func getSettings(): UserNotificationSettings
    func updateSettings(request: UpdateUserNotificationSettingsRequest): UserNotificationSettings
    func setBackgroundPresenter(request: SetBackgroundPresenterRequest): Unit
    func setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Unit
    func backgroundRefresh(request: BackgroundRefreshRequest): BackgroundRefreshResult
}
