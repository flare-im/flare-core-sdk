import Foundation
import FlarePlatformPush

/// 平台推送模块的宿主：令牌、权限、远程推送与点击交给核心客户端，客户端的 `notification.clear` 与
/// `notification.badge` 事件转成更正交给模块，通知中心与角标由模块照办。
///
/// ```swift
/// push.attach(CorePushHost(client: client))
/// ```
///
/// 事件经客户端本地的监听者转来：应用照常打开的那一路原生事件订阅（`client.events.subscribeEvents`）要开着。
public final class CorePushHost: FlarePushHost, @unchecked Sendable {
    // 生成的客户端只持有桥，任何任务里调用都安全
    private let client: any FlareImClientProtocol

    public init(client: any FlareImClientProtocol) {
        self.client = client
    }

    public func updatePushToken(_ token: PlatformPushToken) async throws {
        _ = try await client.updatePushToken(PushTokenInput(
            appBundle: token.appBundle,
            appVersion: token.appVersion,
            capabilities: token.capabilities,
            environment: token.environment,
            locale: token.locale,
            platform: token.platform,
            provider: token.provider,
            timeZone: token.timeZone,
            token: token.token
        ))
    }

    public func setPushPermission(allowed: Bool) async throws {
        _ = try await client.setPushPermission(SetPushPermissionRequest(allowed: allowed))
    }

    public func reconcilePush() async throws {
        _ = try await client.reconcilePush()
    }

    public func handleRemoteMessage(
        provider: String,
        payload: [String: String],
        budgetMs: UInt32
    ) async throws -> PlatformPushOutcome {
        let outcome = try await client.handleRemoteMessage(HandleRemoteMessageRequest(
            budgetMs: budgetMs,
            payload: payload,
            provider: provider
        ))
        return PlatformPushOutcome(
            // 认不出的动作当作什么都不做：宁可不提示，也不按猜测提示
            action: PlatformPushOutcome.Action(rawValue: outcome.action) ?? .ignore,
            presentation: outcome.presentation.map { presentation in
                PlatformNotificationPresentation(
                    collapseId: presentation.collapseId,
                    threadId: presentation.threadId,
                    conversationId: presentation.conversationId,
                    messageId: presentation.messageId,
                    seq: presentation.seq,
                    title: presentation.title,
                    body: presentation.body,
                    count: presentation.count,
                    sound: presentation.sound,
                    channel: PlatformNotificationPresentation.Channel(rawValue: presentation.channel) ?? .messages,
                    surface: PlatformNotificationPresentation.Surface(rawValue: presentation.surface) ?? .system
                )
            },
            clearCollapseIds: outcome.clearCollapseIds,
            badge: outcome.badge,
            reason: outcome.reason
        )
    }

    public func resolveNotificationTap(payload: [String: String]) async throws -> PlatformTapRoute? {
        let result = try await client.resolveNotificationTap(ResolveNotificationTapRequest(payload: payload))
        guard let conversationId = result.conversationId, !conversationId.isEmpty else { return nil }
        return PlatformTapRoute(conversationId: conversationId, messageId: result.messageId, seq: result.seq)
    }

    /// 交给 `notification.setSnapshotDirectory`。失败只是这次不写快照（通知扩展照服务端文案展示），不往外抛。
    public func setNotificationSnapshotDirectory(_ path: String?) async {
        _ = try? await client.notification.setSnapshotDirectory(SetNotificationSnapshotDirectoryRequest(directory: path))
    }

    /// 交给 `notification.backgroundRefresh`；出错按未完成算。
    public func backgroundRefresh(budgetMs: Int) async -> Bool {
        let budget = UInt32(clamping: max(budgetMs, 0))
        guard let result = try? await client.notification.backgroundRefresh(BackgroundRefreshRequest(budgetMs: budget)) else {
            return false
        }
        return result.completed
    }

    /// 模块读这个流期间监听客户端的清除与角标事件；模块取消读取时退掉监听。
    public func notificationCorrections() -> AsyncStream<PlatformNotificationCorrection> {
        let events = client.events
        return AsyncStream { continuation in
            let listeners = PushEventListeners([
                events.onNotificationClear { event in
                    continuation.yield(event.all ? .clearAll : .clear(collapseIds: event.collapseIds))
                },
                events.onNotificationBadge { event in
                    continuation.yield(.badge(event.count))
                },
            ])
            continuation.onTermination = { _ in listeners.unsubscribe() }
        }
    }
}

/// 一组本地事件监听，流结束时一起退掉（只退一次）。
private final class PushEventListeners: @unchecked Sendable {
    private let lock = NSLock()
    private var subscriptions: [any EventSubscription]

    init(_ subscriptions: [any EventSubscription]) {
        self.subscriptions = subscriptions
    }

    func unsubscribe() {
        lock.lock()
        let current = subscriptions
        subscriptions = []
        lock.unlock()
        current.forEach { $0.unsubscribe() }
    }
}
