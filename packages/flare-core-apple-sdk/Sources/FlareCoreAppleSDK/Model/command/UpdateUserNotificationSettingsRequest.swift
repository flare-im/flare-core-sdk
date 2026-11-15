import Foundation

/// GENERATED. Do not edit by hand.
/// A partial update of the user's notification settings: items left out keep their value; at least one item must be given.
public struct UpdateUserNotificationSettingsRequest: Codable, Sendable {
    /// wire: `baseSettingsVersion`. The settingsVersion the change is based on; 0 skips the check. When the stored settings changed in the meantime the whole update is rejected: read them again and retry.
    public let baseSettingsVersion: UInt64
    /// wire: `clearQuietHours`. Remove the do-not-disturb hours. Rejected together with quietHours.
    public let clearQuietHours: Bool
    /// wire: `multiDevice`. New multi-device policy.
    public let multiDevice: MultiDeviceAlertPolicy?
    /// wire: `preview`. New preview mode.
    public let preview: NotificationPreview?
    /// wire: `quietHours`. New do-not-disturb hours, replacing the old ones.
    public let quietHours: QuietHours?

    public init(baseSettingsVersion: UInt64 = 0, clearQuietHours: Bool = false, multiDevice: MultiDeviceAlertPolicy? = nil, preview: NotificationPreview? = nil, quietHours: QuietHours? = nil) {
        self.baseSettingsVersion = baseSettingsVersion
        self.clearQuietHours = clearQuietHours
        self.multiDevice = multiDevice
        self.preview = preview
        self.quietHours = quietHours
    }
}
