import Foundation

/// GENERATED. Do not edit by hand.
/// The user's notification settings, shared by all of the user's devices.
public struct UserNotificationSettings: Codable, Sendable {
    /// wire: `multiDevice`. What a phone does while another device of the user is in use.
    public let multiDevice: MultiDeviceAlertPolicy
    /// wire: `preview`. How much a notification shows.
    public let preview: NotificationPreview
    /// wire: `quietHours`. Do-not-disturb hours; absent when the user has none.
    public let quietHours: QuietHours?
    /// wire: `settingsVersion`. Version of the settings; 0 when the user never changed them. Pass it back as baseSettingsVersion so a concurrent change elsewhere is not overwritten.
    public let settingsVersion: UInt64

    public init(multiDevice: MultiDeviceAlertPolicy, preview: NotificationPreview, quietHours: QuietHours? = nil, settingsVersion: UInt64 = 0) {
        self.multiDevice = multiDevice
        self.preview = preview
        self.quietHours = quietHours
        self.settingsVersion = settingsVersion
    }
}
