package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// A partial update of the user's notification settings: items left out keep their value; at least one item must be given.
public class UpdateUserNotificationSettingsRequest {
    // wire: `baseSettingsVersion`. The settingsVersion the change is based on; 0 skips the check. When the stored settings changed in the meantime the whole update is rejected: read them again and retry.
    public let baseSettingsVersion: UInt64
    // wire: `clearQuietHours`. Remove the do-not-disturb hours. Rejected together with quietHours.
    public let clearQuietHours: Bool
    // wire: `multiDevice`. Optional. New multi-device policy.
    public let multiDevice: ?MultiDeviceAlertPolicy
    // wire: `preview`. Optional. New preview mode.
    public let preview: ?NotificationPreview
    // wire: `quietHours`. Optional. New do-not-disturb hours, replacing the old ones.
    public let quietHours: ?QuietHours

    public init(baseSettingsVersion!: UInt64, clearQuietHours!: Bool, multiDevice!: ?MultiDeviceAlertPolicy, preview!: ?NotificationPreview, quietHours!: ?QuietHours) {
        this.baseSettingsVersion = baseSettingsVersion
        this.clearQuietHours = clearQuietHours
        this.multiDevice = multiDevice
        this.preview = preview
        this.quietHours = quietHours
    }
}
