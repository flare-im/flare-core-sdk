/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `notification` — Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events.
 */
import type { BackgroundRefreshRequest, BackgroundRefreshResult, SetBackgroundPresenterRequest, SetNotificationFocusRequest, SetNotificationSnapshotDirectoryRequest, UpdateUserNotificationSettingsRequest, UserNotificationSettings } from '../../model';

/** Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events. */
export interface NotificationApi {
  /** setFocus maps to `flare_sdk_invoke_json`. Operation: `notification.set_focus`. */
  setFocus(request: SetNotificationFocusRequest): Promise<void>;
  /** getSettings maps to `flare_sdk_invoke_json`. Operation: `notification.get_settings`. */
  getSettings(): Promise<UserNotificationSettings>;
  /** updateSettings maps to `flare_sdk_invoke_json`. Operation: `notification.update_settings`. */
  updateSettings(request: UpdateUserNotificationSettingsRequest): Promise<UserNotificationSettings>;
  /** setBackgroundPresenter maps to `flare_sdk_invoke_json`. Operation: `notification.set_background_presenter`. */
  setBackgroundPresenter(request: SetBackgroundPresenterRequest): Promise<void>;
  /** setSnapshotDirectory maps to `flare_sdk_invoke_json`. Operation: `notification.set_snapshot_directory`. */
  setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Promise<void>;
  /** backgroundRefresh maps to `flare_sdk_invoke_json`. Operation: `notification.background_refresh`. */
  backgroundRefresh(request: BackgroundRefreshRequest): Promise<BackgroundRefreshResult>;
}
