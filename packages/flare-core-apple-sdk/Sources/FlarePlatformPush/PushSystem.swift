import Foundation
import UserNotifications
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 应用代码运行时补的一条本地通知。
public struct PlatformLocalNotification: Equatable, Sendable {
    /// 取合并键：与带同一 `apns-collapse-id` 的 APNs 通知互相替换。
    public var identifier: String
    public var threadId: String
    public var title: String
    public var body: String
    public var sound: Bool
    /// 静默更新：进通知中心，不亮屏、不响。
    public var passive: Bool
    /// 推送载荷原样带上，点击时据此路由。
    public var userInfo: [String: String]

    public init(
        identifier: String,
        threadId: String,
        title: String,
        body: String,
        sound: Bool,
        passive: Bool,
        userInfo: [String: String]
    ) {
        self.identifier = identifier
        self.threadId = threadId
        self.title = title
        self.body = body
        self.sound = sound
        self.passive = passive
        self.userInfo = userInfo
    }
}

/// 系统通知权限的三种情形。
public enum PlatformPushPermissionStatus: String, Equatable, Sendable {
    /// 还没问过：可以弹系统授权框。
    case notDetermined
    /// 拒绝过，或在系统设置里关掉了：只能引导去系统设置。
    case denied
    /// 能收到通知。临时授权（静默送达通知中心）与 App Clip 的短期授权也算：通知照样送得到。
    case granted
}

/// 通知中心里的一条通知：已经展示的，或本模块补的、还在等展示的。
public struct PlatformDeliveredNotification: Equatable, Sendable {
    public var identifier: String
    /// 载荷里的 `collapse_id`：APNs 送达的通知，请求标识不保证等于合并键。
    public var collapseId: String?
    /// 是本 SDK 的通知（载荷带合并键或会话）。登出时只清这些，应用自己的通知不动。
    public var isFlare: Bool

    /// - Parameter isFlare: 不给时按有没有合并键判断。
    public init(identifier: String, collapseId: String?, isFlare: Bool? = nil) {
        self.identifier = identifier
        self.collapseId = collapseId
        self.isFlare = isFlare ?? (collapseId != nil)
    }
}

/// 系统通知中心里本模块用到的部分。
public protocol PlatformNotificationCenter: AnyObject, Sendable {
    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate)
    /// 代理仍是它时才卸下。
    func removeDelegate(_ delegate: any UNUserNotificationCenterDelegate)
    /// 当前的系统通知权限。
    func permissionStatus() async -> PlatformPushPermissionStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ notification: PlatformLocalNotification) async throws
    func deliveredNotifications() async -> [PlatformDeliveredNotification]
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    /// 还没展示出来的通知请求。
    func pendingNotifications() async -> [PlatformDeliveredNotification]
    func removePendingNotifications(withIdentifiers identifiers: [String])
    func setBadge(_ count: Int) async throws
}

/// `UNUserNotificationCenter.current()`。
public final class SystemNotificationCenter: PlatformNotificationCenter {
    public init() {}

    // 每次用时再取：没有应用包的进程（测试、命令行）一取就抛异常，构造它不能碰系统通知中心
    private var center: UNUserNotificationCenter { .current() }

    public func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) {
        center.delegate = delegate
    }

    public func removeDelegate(_ delegate: any UNUserNotificationCenterDelegate) {
        let center = self.center
        if center.delegate === delegate {
            center.delegate = nil
        }
    }

    public func permissionStatus() async -> PlatformPushPermissionStatus {
        let settings = await center.notificationSettings()
        return Self.permissionStatus(for: settings.authorizationStatus)
    }

    static func permissionStatus(for status: UNAuthorizationStatus) -> PlatformPushPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        default:
            // 已授权、临时授权，以及 App Clip 的短期授权，都能收到通知；以后新增的状态也按能收到算，提示不因此被拦下
            return .granted
        }
    }

    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    public func add(_ notification: PlatformLocalNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.threadIdentifier = notification.threadId
        content.userInfo = notification.userInfo
        content.sound = notification.sound ? .default : nil
        content.interruptionLevel = notification.passive ? .passive : .active
        try await center.add(UNNotificationRequest(identifier: notification.identifier, content: content, trigger: nil))
    }

    public func deliveredNotifications() async -> [PlatformDeliveredNotification] {
        await center.deliveredNotifications().map { Self.record($0.request) }
    }

    public func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    public func pendingNotifications() async -> [PlatformDeliveredNotification] {
        await center.pendingNotificationRequests().map(Self.record)
    }

    public func removePendingNotifications(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func record(_ request: UNNotificationRequest) -> PlatformDeliveredNotification {
        let payload = PlatformPushPayload.flatten(request.content.userInfo)
        return PlatformDeliveredNotification(
            identifier: request.identifier,
            collapseId: payload["collapse_id"],
            isFlare: PlatformPushPayload.isFlare(payload: payload)
        )
    }

    public func setBadge(_ count: Int) async throws {
        if #available(iOS 16.0, macOS 13.0, *) {
            try await center.setBadgeCount(count)
        } else {
            await Self.setLegacyBadge(count)
        }
    }

    @MainActor
    private static func setLegacyBadge(_ count: Int) {
        #if canImport(UIKit) && !os(watchOS)
        SharedApplication.current?.applicationIconBadgeNumber = count
        #elseif canImport(AppKit)
        NSApp?.dockTile.badgeLabel = count > 0 ? String(count) : nil
        #endif
    }
}

/// 应用对象里本模块用到的部分。
public protocol PlatformPushApplication: AnyObject, Sendable {
    /// 向 APNs 要令牌，结果经 App Delegate 转给 `PlatformPush.didRegisterForRemoteNotifications(deviceToken:)`。
    @MainActor func registerForRemoteNotifications()
    /// 打开系统设置里本应用的通知页；打不开时返回 false。
    @MainActor func openNotificationSettings() async -> Bool
}

/// iOS 的 `UIApplication`。macOS 不登记 APNs：桌面端没有推送绑定，靠在线连接提示。
public final class SystemPushApplication: PlatformPushApplication {
    public init() {}

    @MainActor
    public func registerForRemoteNotifications() {
        #if os(iOS)
        SharedApplication.current?.registerForRemoteNotifications()
        #endif
    }

    /// iOS 16 起直达本应用的通知页，更早的系统是本应用的设置页。macOS 没有对应的页面，返回 false。
    @MainActor
    public func openNotificationSettings() async -> Bool {
        #if os(iOS)
        guard let application = SharedApplication.current else { return false }
        let address: String
        if #available(iOS 16.0, *) {
            address = UIApplication.openNotificationSettingsURLString
        } else {
            address = UIApplication.openSettingsURLString
        }
        guard let url = URL(string: address) else { return false }
        return await withCheckedContinuation { continuation in
            application.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
        #else
        return false
        #endif
    }
}

#if canImport(UIKit) && !os(watchOS)
enum SharedApplication {
    /// `UIApplication.shared` 对应用扩展不可用；运行时查找，包仍能链接进扩展（扩展里取到 nil）。
    static var current: UIApplication? {
        let selector = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: selector),
              let application = UIApplication.perform(selector)?.takeUnretainedValue() as? UIApplication else {
            return nil
        }
        return application
    }
}
#endif
