import Foundation

/// GENERATED. Do not edit by hand.
/// Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events.
public protocol NotificationApiProtocol: AnyObject {
    func setFocus(_ request: SetNotificationFocusRequest) async throws -> Void
    func getSettings() async throws -> UserNotificationSettings
    func updateSettings(_ request: UpdateUserNotificationSettingsRequest) async throws -> UserNotificationSettings
    func setBackgroundPresenter(_ request: SetBackgroundPresenterRequest) async throws -> Void
    func setSnapshotDirectory(_ request: SetNotificationSnapshotDirectoryRequest) async throws -> Void
    func backgroundRefresh(_ request: BackgroundRefreshRequest) async throws -> BackgroundRefreshResult
}
