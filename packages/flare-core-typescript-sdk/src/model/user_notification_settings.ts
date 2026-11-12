/** GENERATED. Do not edit by hand. */
import type { MultiDeviceAlertPolicy } from './multi_device_alert_policy';
import type { NotificationPreview } from './notification_preview';
import type { QuietHours } from './quiet_hours';

/** The user's notification settings, shared by all of the user's devices. */
export interface UserNotificationSettings {
  /** wire: `multiDevice`. What a phone does while another device of the user is in use. */
  multiDevice: MultiDeviceAlertPolicy;
  /** wire: `preview`. How much a notification shows. */
  preview: NotificationPreview;
  /** wire: `quietHours`. Do-not-disturb hours; absent when the user has none. */
  quietHours?: QuietHours;
  /** wire: `settingsVersion`. Version of the settings; 0 when the user never changed them. Pass it back as baseSettingsVersion so a concurrent change elsewhere is not overwritten. */
  settingsVersion: number;
}
