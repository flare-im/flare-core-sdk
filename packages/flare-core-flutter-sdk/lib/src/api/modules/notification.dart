// GENERATED. Do not edit by hand.
// Module API: `notification` — Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events.
import '../../model/model.dart';

/// Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events.
abstract interface class NotificationApi {
  /// setFocus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.set_focus`.
  Future<void> setFocus(SetNotificationFocusRequest request);
  /// getSettings maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.get_settings`.
  Future<UserNotificationSettings> getSettings();
  /// updateSettings maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.update_settings`.
  Future<UserNotificationSettings> updateSettings(UpdateUserNotificationSettingsRequest request);
  /// setBackgroundPresenter maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.set_background_presenter`.
  Future<void> setBackgroundPresenter(SetBackgroundPresenterRequest request);
  /// setSnapshotDirectory maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.set_snapshot_directory`.
  Future<void> setSnapshotDirectory(SetNotificationSnapshotDirectoryRequest request);
  /// backgroundRefresh maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.background_refresh`.
  Future<BackgroundRefreshResult> backgroundRefresh(BackgroundRefreshRequest request);
}
