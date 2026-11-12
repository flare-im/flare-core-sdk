// GENERATED. Do not edit by hand.
import { NativeBridge } from '../../contract/BridgeContract';
import { SdkErrorCodes } from '../../contract/SdkContract';
import { FlareSdkException } from '../../bridge/FlareSdkException';
import type { NotificationApi } from '../../api/modules/notification';
import type { BackgroundRefreshRequest, BackgroundRefreshResult, SetBackgroundPresenterRequest, SetNotificationFocusRequest, SetNotificationSnapshotDirectoryRequest, UpdateUserNotificationSettingsRequest, UserNotificationSettings } from '../../model';

/** HarmonyOS has no notification presenter yet: these calls are not handed to the core. */
export class DefaultNotificationApi implements NotificationApi {
  constructor(private readonly bridge: NativeBridge) {}

  async setFocus(request: SetNotificationFocusRequest): Promise<void> {
    throw new FlareSdkException(
      SdkErrorCodes.capabilityUnavailable,
      'notification is not available on HarmonyOS yet',
      "notification.set_focus",
    );
  }

  async getSettings(): Promise<UserNotificationSettings> {
    throw new FlareSdkException(
      SdkErrorCodes.capabilityUnavailable,
      'notification is not available on HarmonyOS yet',
      "notification.get_settings",
    );
  }

  async updateSettings(request: UpdateUserNotificationSettingsRequest): Promise<UserNotificationSettings> {
    throw new FlareSdkException(
      SdkErrorCodes.capabilityUnavailable,
      'notification is not available on HarmonyOS yet',
      "notification.update_settings",
    );
  }

  async setBackgroundPresenter(request: SetBackgroundPresenterRequest): Promise<void> {
    throw new FlareSdkException(
      SdkErrorCodes.capabilityUnavailable,
      'notification is not available on HarmonyOS yet',
      "notification.set_background_presenter",
    );
  }

  async setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Promise<void> {
    throw new FlareSdkException(
      SdkErrorCodes.capabilityUnavailable,
      'notification is not available on HarmonyOS yet',
      "notification.set_snapshot_directory",
    );
  }

  async backgroundRefresh(request: BackgroundRefreshRequest): Promise<BackgroundRefreshResult> {
    throw new FlareSdkException(
      SdkErrorCodes.capabilityUnavailable,
      'notification is not available on HarmonyOS yet',
      "notification.background_refresh",
    );
  }
}
