import Foundation

/// 推送模块的应用配置：通知扩展与后台刷新。缺省什么都不开，与不给配置时一样。
///
/// ```swift
/// let push = PlatformPush(configuration: PlatformPushConfiguration(
///     appGroupIdentifier: "group.com.example.app",
///     hasNotificationServiceExtension: true,
///     backgroundRefreshTaskIdentifier: "com.example.app.refresh"
/// ))
/// ```
public struct PlatformPushConfiguration: Equatable, Sendable {
    /// 应用与通知扩展共享的 App Group（通常是 `group.<包名>`），应用与扩展的 entitlements 都要有它。
    /// 给了，模块在 `<容器>/flare-notify` 建好目录并交给宿主：引擎在那里写通知快照、读扩展记下的到达回执。
    public var appGroupIdentifier: String?
    /// 应用带着通知扩展（`FlareNotificationServiceBase` 的子类），并且扩展在同一个 App Group 里。
    /// App Group 可用且这里为 true 时，令牌登记才带 `serviceExtension`：服务端据此给提示推送加 `mutable-content`。
    public var hasNotificationServiceExtension: Bool
    /// 后台刷新任务（`BGAppRefreshTask`）的标识，通常是 `<包名>.refresh`。要列在 Info.plist 的
    /// `BGTaskSchedulerPermittedIdentifiers` 里，`UIBackgroundModes` 要有 `fetch`；`start()` 要在启动返回之前调。
    public var backgroundRefreshTaskIdentifier: String?

    public init(
        appGroupIdentifier: String? = nil,
        hasNotificationServiceExtension: Bool = false,
        backgroundRefreshTaskIdentifier: String? = nil
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.hasNotificationServiceExtension = hasNotificationServiceExtension
        self.backgroundRefreshTaskIdentifier = backgroundRefreshTaskIdentifier
    }

    /// 去掉首尾空白后的 App Group；没给或为空时为 nil。
    var appGroup: String? {
        Self.trimmed(appGroupIdentifier)
    }

    /// 去掉首尾空白后的后台刷新标识；没给或为空时为 nil。
    var backgroundRefreshTask: String? {
        Self.trimmed(backgroundRefreshTaskIdentifier)
    }

    private static func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

/// 应用配置与工程不符：模块照常工作，只是对应的能力不开。经 `onError` 报给应用，便于在开发时发现。
public enum PlatformPushConfigurationError: Error, Equatable, CustomStringConvertible {
    /// 取不到这个 App Group 的容器：应用的 entitlements 里没有它。通知扩展用不上快照，令牌也不带 `serviceExtension`。
    case appGroupUnavailable(String)
    /// 后台刷新标识没列在 Info.plist 的 `BGTaskSchedulerPermittedIdentifiers` 里，任务没有登记。
    case backgroundRefreshNotPermitted(String)

    public var description: String {
        switch self {
        case let .appGroupUnavailable(group):
            return "push configuration: no container for app group \(group); check the app's entitlements"
        case let .backgroundRefreshNotPermitted(identifier):
            return "push configuration: \(identifier) is not in BGTaskSchedulerPermittedIdentifiers"
        }
    }
}

extension PlatformPushToken {
    /// 令牌登记的能力：应用带着能读通知快照的通知扩展。
    public static let serviceExtensionCapability = "serviceExtension"
}
