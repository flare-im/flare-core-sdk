// GENERATED. Do not edit by hand.
import 'multi_device_alert_policy.dart';
import 'notification_preview.dart';
import 'quiet_hours.dart';

/// The user's notification settings, shared by all of the user's devices.
final class UserNotificationSettings {
  /// wire: `multiDevice`. What a phone does while another device of the user is in use.
  final MultiDeviceAlertPolicy multiDevice;
  /// wire: `preview`. How much a notification shows.
  final NotificationPreview preview;
  /// wire: `quietHours`. Do-not-disturb hours; absent when the user has none.
  final QuietHours? quietHours;
  /// wire: `settingsVersion`. Version of the settings; 0 when the user never changed them. Pass it back as baseSettingsVersion so a concurrent change elsewhere is not overwritten.
  final int settingsVersion;

  const UserNotificationSettings({
    required this.multiDevice,
    required this.preview,
    this.quietHours,
    this.settingsVersion = 0,
  });
}
