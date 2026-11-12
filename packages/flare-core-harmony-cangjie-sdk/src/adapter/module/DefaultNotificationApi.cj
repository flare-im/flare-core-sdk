package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// HarmonyOS has no notification presenter yet: these calls are not handed to the core.
public class DefaultNotificationApi <: NotificationApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func setFocus(request: SetNotificationFocusRequest): Unit {
        throw Exception("FlareSdkException(code=capabilityUnavailable, operation=notification.set_focus, message=notification is not available on HarmonyOS yet.)")
    }

    public func getSettings(): UserNotificationSettings {
        throw Exception("FlareSdkException(code=capabilityUnavailable, operation=notification.get_settings, message=notification is not available on HarmonyOS yet.)")
    }

    public func updateSettings(request: UpdateUserNotificationSettingsRequest): UserNotificationSettings {
        throw Exception("FlareSdkException(code=capabilityUnavailable, operation=notification.update_settings, message=notification is not available on HarmonyOS yet.)")
    }

    public func setBackgroundPresenter(request: SetBackgroundPresenterRequest): Unit {
        throw Exception("FlareSdkException(code=capabilityUnavailable, operation=notification.set_background_presenter, message=notification is not available on HarmonyOS yet.)")
    }

    public func setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Unit {
        throw Exception("FlareSdkException(code=capabilityUnavailable, operation=notification.set_snapshot_directory, message=notification is not available on HarmonyOS yet.)")
    }

    public func backgroundRefresh(request: BackgroundRefreshRequest): BackgroundRefreshResult {
        throw Exception("FlareSdkException(code=capabilityUnavailable, operation=notification.background_refresh, message=notification is not available on HarmonyOS yet.)")
    }
}
