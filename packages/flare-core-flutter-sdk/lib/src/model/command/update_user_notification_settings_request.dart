// GENERATED. Do not edit by hand.
import '../entity/multi_device_alert_policy.dart';
import '../entity/notification_preview.dart';
import '../entity/quiet_hours.dart';

/// A partial update of the user's notification settings: items left out keep their value; at least one item must be given.
final class UpdateUserNotificationSettingsRequest {
  /// wire: `baseSettingsVersion`. The settingsVersion the change is based on; 0 skips the check. When the stored settings changed in the meantime the whole update is rejected: read them again and retry.
  final int baseSettingsVersion;
  /// wire: `clearQuietHours`. Remove the do-not-disturb hours. Rejected together with quietHours.
  final bool clearQuietHours;
  /// wire: `multiDevice`. New multi-device policy.
  final MultiDeviceAlertPolicy? multiDevice;
  /// wire: `preview`. New preview mode.
  final NotificationPreview? preview;
  /// wire: `quietHours`. New do-not-disturb hours, replacing the old ones.
  final QuietHours? quietHours;

  const UpdateUserNotificationSettingsRequest({
    this.baseSettingsVersion = 0,
    this.clearQuietHours = false,
    this.multiDevice,
    this.preview,
    this.quietHours,
  });
}
