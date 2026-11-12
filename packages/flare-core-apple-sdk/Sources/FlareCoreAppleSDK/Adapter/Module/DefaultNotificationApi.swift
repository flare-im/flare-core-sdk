import Foundation

/// GENERATED. Do not edit by hand.
public final class DefaultNotificationApi: NotificationApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func setFocus(_ request: SetNotificationFocusRequest) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.notificationSetFocus, request: AnySendable(setNotificationFocusRequestToMap(request)))
    }

    public func getSettings() async throws -> UserNotificationSettings {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.notificationGetSettings, request: nil)
        return try userNotificationSettingsFromJson(raw)
    }

    public func updateSettings(_ request: UpdateUserNotificationSettingsRequest) async throws -> UserNotificationSettings {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.notificationUpdateSettings, request: updateUserNotificationSettingsRequestToMap(request))
        return try userNotificationSettingsFromJson(raw)
    }

    public func setBackgroundPresenter(_ request: SetBackgroundPresenterRequest) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.notificationSetBackgroundPresenter, request: AnySendable(setBackgroundPresenterRequestToMap(request)))
    }

    public func setSnapshotDirectory(_ request: SetNotificationSnapshotDirectoryRequest) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.notificationSetSnapshotDirectory, request: AnySendable(setNotificationSnapshotDirectoryRequestToMap(request)))
    }

    public func backgroundRefresh(_ request: BackgroundRefreshRequest) async throws -> BackgroundRefreshResult {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.notificationBackgroundRefresh, request: backgroundRefreshRequestToMap(request))
        return try backgroundRefreshResultFromJson(raw)
    }
}
