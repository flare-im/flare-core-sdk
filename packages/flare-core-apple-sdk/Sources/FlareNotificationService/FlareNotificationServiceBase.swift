import Foundation
#if canImport(UserNotifications)
import UserNotifications

/// 通知扩展（Notification Service Extension）的基类：按主应用写在 App Group 里的通知快照重渲染标题与正文，
/// 并记下到达回执。
///
/// 应用加一个通知扩展目标，主类继承它，只给出 App Group：
///
/// ```swift
/// import FlareNotificationService
///
/// final class NotificationService: FlareNotificationServiceBase {
///     override var appGroupIdentifier: String { "group.com.example.app" }
/// }
/// ```
///
/// 主应用在 `PlatformPushConfiguration` 里给同一个 App Group，并声明带了扩展：令牌登记随之带上 `serviceExtension`，
/// 服务端才给提示推送加 `mutable-content`，系统才把推送交给扩展。
///
/// 扩展是独立进程，内存上限很低：这里只读一次快照文件（典型 50ms 以内、8 MiB 以内），不打开主数据库、不连网、
/// 不写日志（不让通知文字落到任何地方）。快照不在、坏掉、或属于别的账号时，推送按服务端文案原样展示，回执照记。
/// 不是本 SDK 的推送原样放过，也不记回执。系统要收回时间时（`serviceExtensionTimeWillExpire`）交出已有的最好结果。
open class FlareNotificationServiceBase: UNNotificationServiceExtension {
    /// 与主应用共享的 App Group，子类覆盖。为空时不读快照、不记回执，推送原样展示。
    open var appGroupIdentifier: String { "" }

    /// 一个请求等着交回的处理函数，和交不出新结果时的退路（原样的内容）。
    private struct Pending {
        let contentHandler: (UNNotificationContent) -> Void
        let bestAttempt: UNNotificationContent
    }

    /// 快照目录在 App Group 容器里的名字，与主应用的推送模块一致。
    static let directoryName = "flare-notify"

    private static let queue = DispatchQueue(label: "im.flare.notification-service", qos: .userInitiated)

    private let lock = NSLock()
    /// 系统可能在同一个实例上接连交来几条通知：每次调用各记一份，各自交回。
    private var pending: [UUID: Pending] = [:]

    override open func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let receivedAtMs = Int64((Date().timeIntervalSince1970 * 1000).rounded())
        let key = UUID()
        let content = request.content
        lock.lock()
        pending[key] = Pending(contentHandler: contentHandler, bestAttempt: content)
        lock.unlock()

        let directory = Self.directory(appGroupIdentifier: appGroupIdentifier)
        Self.queue.async {
            let rendered = Self.process(content, directory: directory, receivedAtMs: receivedAtMs)
            self.deliver(key, content: rendered)
        }
    }

    /// 系统要收回时间：还没交回的请求一律交出已有的最好结果（原样的内容）。
    override open func serviceExtensionTimeWillExpire() {
        lock.lock()
        let remaining = pending
        pending = [:]
        lock.unlock()
        for entry in remaining.values {
            entry.contentHandler(entry.bestAttempt)
        }
    }

    /// 交回一次；系统先收回了时间（已经按原样交过）就什么也不做。
    private func deliver(_ key: UUID, content: UNNotificationContent) {
        lock.lock()
        let entry = pending.removeValue(forKey: key)
        lock.unlock()
        entry?.contentHandler(content)
    }

    /// App Group 容器里的快照目录；没给 App Group、或应用没有这个 App Group 的权限时为 nil。
    static func directory(appGroupIdentifier: String) -> URL? {
        let group = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !group.isEmpty,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            return nil
        }
        return container.appendingPathComponent(directoryName, isDirectory: true)
    }

    /// 处理一条推送：读快照、重渲染、记回执，返回要展示的内容。只改标题与正文，其余（声音、角标、分组、载荷）原样。
    static func process(_ content: UNNotificationContent, directory: URL?, receivedAtMs: Int64) -> UNNotificationContent {
        let payload = NotificationPayload(userInfo: content.userInfo)
        guard payload.isFlare, let directory else { return content }
        let snapshot = NotificationSnapshot.read(directory: directory)
        NotificationReceiptLog.append(NotificationReceipt(payload: payload, receivedAtMs: receivedAtMs), directory: directory)
        guard let text = NotificationRenderer.render(
                  title: content.title,
                  body: content.body,
                  payload: payload,
                  snapshot: snapshot
              ),
              text.title != content.title || text.body != content.body,
              let mutable = content.mutableCopy() as? UNMutableNotificationContent else {
            return content
        }
        mutable.title = text.title
        mutable.body = text.body
        return mutable
    }
}
#endif
