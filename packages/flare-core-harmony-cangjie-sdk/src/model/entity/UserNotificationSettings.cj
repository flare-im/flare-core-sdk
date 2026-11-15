package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The user's notification settings, shared by all of the user's devices.
public class UserNotificationSettings {
    // wire: `multiDevice`. What a phone does while another device of the user is in use.
    public let multiDevice: MultiDeviceAlertPolicy
    // wire: `preview`. How much a notification shows.
    public let preview: NotificationPreview
    // wire: `quietHours`. Optional. Do-not-disturb hours; absent when the user has none.
    public let quietHours: ?QuietHours
    // wire: `settingsVersion`. Version of the settings; 0 when the user never changed them. Pass it back as baseSettingsVersion so a concurrent change elsewhere is not overwritten.
    public let settingsVersion: UInt64

    public init(multiDevice!: MultiDeviceAlertPolicy, preview!: NotificationPreview, quietHours!: ?QuietHours, settingsVersion!: UInt64) {
        this.multiDevice = multiDevice
        this.preview = preview
        this.quietHours = quietHours
        this.settingsVersion = settingsVersion
    }
}
