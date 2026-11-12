// GENERATED. Do not edit by hand.
import { MultiDeviceAlertPolicy } from '../entity/multi_device_alert_policy';
import { NotificationPreview } from '../entity/notification_preview';
import { QuietHours } from '../entity/quiet_hours';

/** A partial update of the user's notification settings: items left out keep their value; at least one item must be given. */
export interface UpdateUserNotificationSettingsRequest {
  /** wire: `baseSettingsVersion`. The settingsVersion the change is based on; 0 skips the check. When the stored settings changed in the meantime the whole update is rejected: read them again and retry. */
  baseSettingsVersion: number;
  /** wire: `clearQuietHours`. Remove the do-not-disturb hours. Rejected together with quietHours. */
  clearQuietHours: boolean;
  /** wire: `multiDevice`. New multi-device policy. */
  multiDevice?: MultiDeviceAlertPolicy;
  /** wire: `preview`. New preview mode. */
  preview?: NotificationPreview;
  /** wire: `quietHours`. New do-not-disturb hours, replacing the old ones. */
  quietHours?: QuietHours;
}
