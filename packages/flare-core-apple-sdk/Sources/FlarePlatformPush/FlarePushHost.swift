import Foundation

/// 平台推送模块对引擎的全部要求。
///
/// 模块不依赖任何引擎包：核心 SDK（`CorePushHost`）与社交 SDK（`FlareSocialSdk.makePushHost()`）各自实现它，
/// 应用在会话恢复后用 `PlatformPush.attach(_:)` 接上。登记、去重、合并、提示决策都在引擎里，这里只搬运。
///
/// 模块给每次调用设上限（远程推送约 3 秒，其余约 15 秒）：超时的调用会被取消，答复晚到也不再用。
/// 经 JSON 透传的实现用 `PlatformPushWire` 读写契约形状。
public protocol FlarePushHost: Sendable {
    /// 登记或更新系统推送令牌及其绑定信息。
    func updatePushToken(_ token: PlatformPushToken) async throws
    /// 当前的系统通知权限，拒绝也要报：引擎每次进程启动都从未授权开始。
    func setPushPermission(allowed: Bool) async throws
    /// 对账：补做没有结果的登记与吊销。
    func reconcilePush() async throws
    /// 远程推送的无界面入口。引擎在 150ms 内给出提示意图，不等网络；`budgetMs` 大于 0 时另起一次有界唤醒。
    func handleRemoteMessage(provider: String, payload: [String: String], budgetMs: UInt32) async throws -> PlatformPushOutcome
    /// 点击通知要去的会话；载荷不属于当前账号时为 nil。
    func resolveNotificationTap(payload: [String: String]) async throws -> PlatformTapRoute?
    /// 引擎对已经发出的通知的更正（`notification.clear`、`notification.badge`）。
    ///
    /// 模块接上宿主时调一次，接着期间一直读这个流；摘下、换宿主、登出或停止时取消读取，流随之结束。
    /// 实现在流结束时（`onTermination`）退掉对引擎事件的订阅。没有更正可报的宿主返回一个已经结束的流。
    func notificationCorrections() -> AsyncStream<PlatformNotificationCorrection>
    /// 通知快照目录（App Group 容器里的 `flare-notify`）：引擎在那里写快照给通知扩展读，并读走扩展记下的到达回执。
    /// nil 停止写快照，已写的不删。模块在接上宿主时给一次，只在配置了可用的 App Group 时。
    func setNotificationSnapshotDirectory(_ path: String?) async
    /// 后台刷新任务：一次唤醒加增量同步，预算封顶 25000ms。同步在预算内做完时为 true；预算用完、
    /// 没有会话可连或出错时为 false。
    func backgroundRefresh(budgetMs: Int) async -> Bool
}

/// 没有通知扩展与后台刷新的宿主（例如只转发令牌、推送与点击的嵌入方）不用实现这两个方法：不写快照，
/// 后台刷新什么也不做、按未完成结束。核心客户端与社交 SDK 的宿主两个都实现。
extension FlarePushHost {
    public func setNotificationSnapshotDirectory(_ path: String?) async {}

    public func backgroundRefresh(budgetMs: Int) async -> Bool { false }
}

/// 引擎对已经发出的通知的一条更正，模块照办，应用什么都不用做。
public enum PlatformNotificationCorrection: Equatable, Sendable {
    /// 撤掉这些合并键的通知：会话读了或删了。
    case clear(collapseIds: [String])
    /// 撤掉本 SDK 的全部通知：会话结束（登出、换账号）。
    case clearAll
    /// 角标写成这个绝对值：未读总数变了、登录之后、回到前台。
    case badge(UInt32)
}

/// 一次令牌登记：系统令牌，加上服务端选择通道和渲染兜底文案要用的应用信息。
public struct PlatformPushToken: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// `apns`、`fcm` 或 `getui`。
    public var provider: String
    /// `ios`、`android` 或 `harmony`。
    public var platform: String
    /// 系统发的令牌，APNs 为十六进制。不写日志，不落盘。
    public var token: String
    /// iOS 包名：服务端拿它当 APNs topic。
    public var appBundle: String?
    /// 仅 APNs：`sandbox` 或 `production`。
    public var environment: String?
    /// BCP 47，服务端按它渲染兜底文案。
    public var locale: String?
    /// IANA 时区名。
    public var timeZone: String?
    public var appVersion: String?
    /// 已知值 `dataMessages`（Android FCM）、`serviceExtension`（iOS 通知扩展）。
    public var capabilities: [String]

    public init(
        provider: String,
        platform: String,
        token: String,
        appBundle: String? = nil,
        environment: String? = nil,
        locale: String? = nil,
        timeZone: String? = nil,
        appVersion: String? = nil,
        capabilities: [String] = []
    ) {
        self.provider = provider
        self.platform = platform
        self.token = token
        self.appBundle = appBundle
        self.environment = environment
        self.locale = locale
        self.timeZone = timeZone
        self.appVersion = appVersion
        self.capabilities = capabilities
    }

    /// 打印时不带令牌本身。
    public var description: String {
        "PlatformPushToken(provider: \(provider), platform: \(platform), appBundle: \(appBundle ?? "-"), "
            + "environment: \(environment ?? "-"), locale: \(locale ?? "-"), timeZone: \(timeZone ?? "-"), "
            + "appVersion: \(appVersion ?? "-"), capabilities: \(capabilities))"
    }

    public var debugDescription: String { description }
}

/// 引擎对一条远程推送的处理结果。
public struct PlatformPushOutcome: Equatable, Sendable {
    public enum Action: String, Equatable, Sendable {
        /// 新通知，可以响铃。
        case present
        /// 静默替换同一合并键的通知。
        case update
        /// 移除 `clearCollapseIds` 里的通知。
        case clear
        /// 只更新角标。
        case badgeOnly
        /// 什么都不做，原因见 `reason`。
        case ignore
    }

    public var action: Action
    public var presentation: PlatformNotificationPresentation?
    public var clearCollapseIds: [String]
    /// 角标绝对值，只在已知时给出。
    public var badge: UInt32?
    /// `ignore` 的原因：`otherAccount`、`notLoggedIn`、`stale`、`alreadyAlerted`、`malformed`。仅供诊断。
    public var reason: String?

    public init(
        action: Action,
        presentation: PlatformNotificationPresentation? = nil,
        clearCollapseIds: [String] = [],
        badge: UInt32? = nil,
        reason: String? = nil
    ) {
        self.action = action
        self.presentation = presentation
        self.clearCollapseIds = clearCollapseIds
        self.badge = badge
        self.reason = reason
    }
}

/// 要展示的那条通知。
public struct PlatformNotificationPresentation: Equatable, Sendable {
    public enum Channel: String, Equatable, Sendable {
        case messages, quiet, mentions, urgent
    }

    public enum Surface: String, Equatable, Sendable {
        /// 系统通知。
        case system
        /// 应用在前台，提示在应用内，不出系统横幅。
        case inApp
    }

    /// `c:` 加 32 位十六进制，一个会话一条通知；也是通知请求的标识。
    public var collapseId: String
    public var threadId: String
    public var conversationId: String
    public var messageId: String
    public var seq: UInt64
    public var title: String
    public var body: String
    /// 这条通知代表的未读条数，至少为 1。
    public var count: UInt32
    public var sound: Bool
    public var channel: Channel
    public var surface: Surface

    public init(
        collapseId: String,
        threadId: String,
        conversationId: String,
        messageId: String = "",
        seq: UInt64 = 0,
        title: String,
        body: String,
        count: UInt32 = 1,
        sound: Bool,
        channel: Channel = .messages,
        surface: Surface = .system
    ) {
        self.collapseId = collapseId
        self.threadId = threadId
        self.conversationId = conversationId
        self.messageId = messageId
        self.seq = seq
        self.title = title
        self.body = body
        self.count = count
        self.sound = sound
        self.channel = channel
        self.surface = surface
    }
}

/// 点击通知要打开的位置。
public struct PlatformTapRoute: Equatable, Sendable {
    public var conversationId: String
    public var messageId: String?
    public var seq: UInt64?

    public init(conversationId: String, messageId: String? = nil, seq: UInt64? = nil) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.seq = seq
    }
}
