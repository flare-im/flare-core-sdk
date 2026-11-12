import AppKit
import Foundation
import UserNotifications

/// 一条要展示的通知：引擎 `NotificationPresentation` 的线上形状（驼峰键），Dart 原样转来。
struct DesktopPresentation {
    let collapseId: String
    let threadId: String
    let conversationId: String
    let messageId: String
    let seq: Int64
    let title: String
    let body: String
    let sound: Bool
    let channel: String

    /// 没有合并键的落不成通知（nil）。
    init?(wire: [String: Any]) {
        guard let collapseId = wire["collapseId"] as? String, !collapseId.isEmpty else { return nil }
        self.collapseId = collapseId
        let thread = wire["threadId"] as? String ?? ""
        threadId = thread.isEmpty ? collapseId : thread
        conversationId = wire["conversationId"] as? String ?? ""
        messageId = wire["messageId"] as? String ?? ""
        seq = (wire["seq"] as? NSNumber)?.int64Value ?? 0
        title = wire["title"] as? String ?? ""
        body = wire["body"] as? String ?? ""
        sound = wire["sound"] as? Bool ?? false
        channel = wire["channel"] as? String ?? "messages"
    }

    /// 不响铃的（静默替换、`quiet` 渠道）只进通知中心，不弹横幅：与 Android 的「只提示一次」一致，一阵连发的消息
    /// 只在第一条弹出。
    var passive: Bool { !sound || channel == "quiet" }
}

/// 桌面系统通知（macOS）：把引擎的系统展示面落到通知中心。
///
/// 一个会话一条通知：请求标识取合并键，同一会话的新通知替换通知中心里的旧的；分组取 threadId。撤除按标识，
/// 全撤只撤本插件出的（userInfo 里带标记），应用自己的通知不动。角标写在 Dock 图标上。
///
/// 点击：通知中心代理在插件注册时装上（早于启动结束，点通知把应用拉起来的那一下也收得到），点击把窗口带到前面，
/// 去向交给 [onTap]。装上之前已经有代理时，不是本插件的通知交还给它。
final class DesktopNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DesktopNotificationPresenter()

    /// userInfo 里标出本插件的通知。
    private static let marker = "flare.presenter"

    /// 点击要去的会话 `{conversationId, messageId?, seq?}`，在主线程上调。摘要通知不属于哪个会话，不调。
    var onTap: (([String: Any]) -> Void)?

    private var prepared = false
    private weak var previousDelegate: UNUserNotificationCenterDelegate?

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    /// 装上通知中心代理；再调一次什么也不做。
    func prepare() {
        guard !prepared else { return }
        prepared = true
        if let current = center.delegate, current !== self {
            previousDelegate = current
        }
        center.delegate = self
    }

    /// 展示，或替换同一合并键的那条。没授权时系统丢掉这条：不重试，也不记内容。
    func present(_ presentation: DesktopPresentation) {
        let content = UNMutableNotificationContent()
        content.title = presentation.title
        content.body = presentation.body
        content.threadIdentifier = presentation.threadId
        content.sound = presentation.sound ? .default : nil
        var info: [String: Any] = [Self.marker: true, "collapseId": presentation.collapseId]
        if !presentation.conversationId.isEmpty { info["conversationId"] = presentation.conversationId }
        if !presentation.messageId.isEmpty { info["messageId"] = presentation.messageId }
        if presentation.seq > 0 { info["seq"] = NSNumber(value: presentation.seq) }
        content.userInfo = info
        if #available(macOS 12.0, *) {
            content.interruptionLevel = presentation.passive ? .passive : .active
        }
        let request = UNNotificationRequest(identifier: presentation.collapseId, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    /// 撤掉这些合并键的通知（已送达的与还没送达的）。
    func clear(_ collapseIds: [String]) {
        let identifiers = collapseIds.filter { !$0.isEmpty }
        guard !identifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// 撤掉本插件出的全部通知，应用自己的不动。
    func clearAll() {
        let center = self.center
        center.getDeliveredNotifications { delivered in
            let identifiers = delivered.filter { Self.isOurs($0) }.map { $0.request.identifier }
            guard !identifiers.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    /// Dock 图标上的未读数；0 去掉。
    func setBadge(_ count: Int) {
        DispatchQueue.main.async {
            NSApplication.shared.dockTile.badgeLabel = count > 0 ? String(count) : nil
        }
    }

    /// `notDetermined`、`granted`（含临时授权）或 `denied`，在主线程上答。
    func permissionStatus(_ done: @escaping (String) -> Void) {
        center.getNotificationSettings { settings in
            let status: String
            switch settings.authorizationStatus {
            case .notDetermined:
                status = "notDetermined"
            case .denied:
                status = "denied"
            default:
                status = "granted"
            }
            DispatchQueue.main.async { done(status) }
        }
    }

    /// 还没决定时弹系统授权框，答之后的权限；决定过的不再弹，直接答现状。
    func requestPermission(_ done: @escaping (String) -> Void) {
        permissionStatus { [weak self] status in
            guard let self, status == "notDetermined" else {
                done(status)
                return
            }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                self.permissionStatus(done)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard Self.isOurs(notification) else {
            if let previous = previousDelegate,
               previous.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler) != nil {
                return
            }
            completionHandler([])
            return
        }
        // 引擎只在窗口不在前台时给系统展示面：应用虽然还是活跃的（窗口被挡住、最小化），也照样展示
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard Self.isOurs(response.notification) else {
            if let previous = previousDelegate,
               previous.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler) != nil {
                return
            }
            completionHandler()
            return
        }
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            let info = response.notification.request.content.userInfo
            DispatchQueue.main.async { [weak self] in
                Self.bringToFront()
                guard let conversationId = info["conversationId"] as? String, !conversationId.isEmpty else { return }
                var route: [String: Any] = ["conversationId": conversationId]
                if let messageId = info["messageId"] as? String, !messageId.isEmpty { route["messageId"] = messageId }
                if let seq = info["seq"] as? NSNumber { route["seq"] = seq }
                self?.onTap?(route)
            }
        }
        completionHandler()
    }

    private static func isOurs(_ notification: UNNotification) -> Bool {
        notification.request.content.userInfo[marker] != nil
    }

    /// 点击时把窗口带到前面：最小化的还原，关掉（隐藏）的重新显示。
    private static func bringToFront() {
        let app = NSApplication.shared
        app.activate(ignoringOtherApps: true)
        guard let window = app.mainWindow ?? app.windows.first(where: { $0.canBecomeMain }) else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }
}
