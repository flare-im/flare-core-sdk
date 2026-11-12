import Foundation
import UserNotifications
import FlarePlatformLifecycle
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// 静默推送处理完的结果，iOS 上对应 `UIBackgroundFetchResult`。
public enum PlatformRemoteMessageResult: Equatable, Sendable {
    case newData
    case noData
    case failed
}

/// 宿主在上限内没有答复。远程推送据此改按载荷提示，令牌、权限与点击留到下次同步。
public struct PlatformPushHostTimeout: Error, Equatable, CustomStringConvertible {
    /// 超时的宿主方法，例如 `handleRemoteMessage`。
    public let call: String
    public let limitMs: UInt32

    public init(call: String, limitMs: UInt32) {
        self.call = call
        self.limitMs = limitMs
    }

    public var description: String { "push host \(call) did not answer within \(limitMs) ms" }
}

/// iOS 推送接入：通知权限、APNs 令牌、静默推送、前台展示、点击路由与角标。
///
/// 它不依赖引擎，提示怎么出都问宿主（`FlarePushHost`）。接法：
/// - `application(_:didFinishLaunchingWithOptions:)` 里建好并 `start()`：系统通知中心的代理要在它返回之前装上，
///   冷启动的点击才送得到。系统只弱引用代理，应用要一直持有这个对象。
/// - 会话恢复后 `attach(_:)` 宿主；在这之前到的静默推送按载荷原样提示，点击先留着，接上后再路由。
///   接着宿主期间，引擎对已发通知的更正（会话读了撤掉、会话结束全撤、角标）由模块直接落到通知中心，
///   角标在应用运行时始终跟着引擎报的未读总数。
///   登出时 `signOut()`：摘下宿主，清掉本 SDK 的通知与角标，下一个账号重新登记令牌。
/// - App Delegate 的令牌、登记失败、远程推送三个回调原样转进来。
/// - 应用选好时机（不是启动时）调 `requestAuthorization()`；权限状态从 `permissionStatus()` 与
///   `permissionChanges()` 读，启动、申请之后与每次回到前台都会重读并报给宿主。
/// - 应用内切语言时 `setLocale(_:)`：令牌登记带应用的语言，变了立刻重登。
/// - 从 `routes()` 读点击要去的会话。
/// - 通知扩展与后台刷新由配置（`PlatformPushConfiguration`）打开：给了 App Group，接上宿主时把快照目录
///   （`<容器>/flare-notify`）交给它，声明带了扩展时令牌登记带 `serviceExtension`；给了后台刷新标识，`start()`
///   登记 `BGAppRefreshTask`，登录后每次进后台排一次（不早于 15 分钟后），运行时交给宿主做一次 25 秒的刷新。
///
/// 宿主调用都有上限：远程推送约 3 秒（超时按载荷提示），其余约 15 秒；卡住的宿主拖不住系统回调。
///
/// 不做方法交换：应用自己当通知中心代理时 `start(installDelegate: false)`，把两个代理方法转进来。
public final class PlatformPush: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    /// 静默推送交给引擎的唤醒预算。
    public static let silentPushBudgetMs: UInt32 = 20_000
    /// 等宿主处理一条远程推送的上限，超过就按载荷提示。系统回调要尽快答复。
    public static let remoteMessageTimeoutMs: UInt32 = 3_000
    /// 其余宿主调用（令牌、权限、对账、点击）的上限，超过的留到下次同步。
    public static let hostCallTimeoutMs: UInt32 = 15_000
    /// 预算到期后引擎重新托管链路的上限。系统给静默推送约 30 秒，回调之前进程要活到托管完成。
    static let parkingGraceMs: UInt32 = 3_500
    /// 后台刷新交给引擎的预算。系统给一次后台刷新约 30 秒。
    public static let backgroundRefreshBudgetMs = 25_000
    /// 两次后台刷新至少隔这么久（系统还会按使用习惯再往后推）。
    public static let backgroundRefreshInterval: TimeInterval = 15 * 60
    /// 后台刷新把进程冷启动起来时，等应用恢复会话、接上宿主的上限；等不到这次按未完成结束。
    static let backgroundRefreshHostWaitMs: UInt32 = 3_000
    /// App Group 容器里通知快照目录的名字，与通知扩展（`FlareNotificationServiceBase`）一致。
    public static let notificationDirectoryName = "flare-notify"

    private struct Attached {
        let host: any FlarePushHost
        let generation: UInt64
    }

    private let center: any PlatformNotificationCenter
    private let application: any PlatformPushApplication
    private let appState: any PlatformAppStateSource
    private let deviceInfo: @Sendable () -> PlatformPushDeviceInfo
    private let wait: @Sendable (_ milliseconds: UInt32) async -> Void
    private let remoteMessageLimitMs: UInt32
    private let hostCallLimitMs: UInt32
    private let configuration: PlatformPushConfiguration
    private let backgroundRefresh: any PlatformBackgroundRefreshScheduler
    /// App Group 的容器目录；取不到（没有权限）时为 nil。
    private let appGroupContainer: @Sendable (_ appGroupIdentifier: String) -> URL?
    private let hostWaitLimitMs: UInt32
    private let onError: @Sendable (Error) -> Void

    private let lock = NSLock()
    private var host: (any FlarePushHost)?
    private var generation: UInt64 = 0
    private var apnsToken: String?
    private var sentToken: PlatformPushToken?
    private var localeOverride: String?
    private var pendingTap: [String: String]?
    private var lastAppState: PlatformAppState?
    private var lastPermission: PlatformPushPermissionStatus?
    private var started = false
    private var stopped = false
    private var delegateInstalled = false
    private var syncRequests: AsyncStream<Void>.Continuation?
    private var syncWorker: Task<Void, Never>?
    private var routeSubscribers: [UUID: AsyncStream<PlatformTapRoute>.Continuation] = [:]
    private var permissionSubscribers: [UUID: AsyncStream<PlatformPushPermissionStatus>.Continuation] = [:]
    private var heldRoute: PlatformTapRoute?
    /// 读当前宿主更正流的任务；摘下、换宿主、登出与停止时取消。
    private var corrections: Task<Void, Never>?
    /// 解析过的通知快照目录：外层 nil 是还没解析，内层 nil 是没有可用的 App Group。
    private var resolvedNotificationDirectory: String??
    /// 等宿主接上的后台刷新；接上、等到上限或停止时各自交回。
    private var hostWaiters: [UUID: CheckedContinuation<(any FlarePushHost)?, Never>] = [:]

    /// - Parameter configuration: 通知扩展与后台刷新；缺省都不开。
    /// - Parameter onError: 宿主调用或系统接口失败时调用；推送接入尽力而为，不抛给应用。错误里不带令牌与载荷。
    public convenience init(
        configuration: PlatformPushConfiguration = PlatformPushConfiguration(),
        center: any PlatformNotificationCenter = SystemNotificationCenter(),
        application: any PlatformPushApplication = SystemPushApplication(),
        appState: any PlatformAppStateSource = SystemAppStateSource(),
        backgroundRefresh: any PlatformBackgroundRefreshScheduler = SystemBackgroundRefreshScheduler(),
        onError: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.init(
            center: center,
            application: application,
            appState: appState,
            deviceInfo: { PlatformPushDeviceInfo.current() },
            wait: { milliseconds in try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000) },
            configuration: configuration,
            backgroundRefresh: backgroundRefresh,
            onError: onError
        )
    }

    init(
        center: any PlatformNotificationCenter,
        application: any PlatformPushApplication,
        appState: any PlatformAppStateSource,
        deviceInfo: @escaping @Sendable () -> PlatformPushDeviceInfo,
        wait: @escaping @Sendable (_ milliseconds: UInt32) async -> Void,
        remoteMessageLimitMs: UInt32 = PlatformPush.remoteMessageTimeoutMs,
        hostCallLimitMs: UInt32 = PlatformPush.hostCallTimeoutMs,
        configuration: PlatformPushConfiguration = PlatformPushConfiguration(),
        backgroundRefresh: any PlatformBackgroundRefreshScheduler = SystemBackgroundRefreshScheduler(),
        appGroupContainer: @escaping @Sendable (_ appGroupIdentifier: String) -> URL? = PlatformPush.systemAppGroupContainer,
        hostWaitLimitMs: UInt32 = PlatformPush.backgroundRefreshHostWaitMs,
        onError: @escaping @Sendable (Error) -> Void
    ) {
        self.center = center
        self.application = application
        self.appState = appState
        self.deviceInfo = deviceInfo
        self.wait = wait
        self.remoteMessageLimitMs = remoteMessageLimitMs
        self.hostCallLimitMs = hostCallLimitMs
        self.configuration = configuration
        self.backgroundRefresh = backgroundRefresh
        self.appGroupContainer = appGroupContainer
        self.hostWaitLimitMs = hostWaitLimitMs
        self.onError = onError
        super.init()
    }

    deinit {
        // 系统通知中心对代理是弱引用，走到这里时它已经指不到这个对象，不用卸
        _ = shutDown()
    }

    // MARK: - 启停与宿主

    /// `start()` 跑过、还没 `stop()`。只有应用进程才碰系统通知中心（没有应用包的进程一碰就抛异常），
    /// 应用与测试据此判断，不用自己再记一份。
    public var isStarted: Bool {
        locked { started && !stopped }
    }

    /// 装上通知中心代理、开始跟踪前后台、向 APNs 要令牌，读权限并报给宿主；配置了后台刷新时登记任务
    /// （iOS 只在启动返回之前接受登记，所以要在 `didFinishLaunching` 里调）。再调一次什么也不做。
    /// - Parameter installDelegate: 应用自己当通知中心代理时传 false，再把两个代理方法转进来。
    @discardableResult
    public func start(installDelegate: Bool = true) -> Self {
        var captured: AsyncStream<Void>.Continuation?
        // 正在同步时再来的请求并成一次
        let requests = AsyncStream<Void>(bufferingPolicy: .bufferingNewest(1)) { captured = $0 }
        let continuation = captured!
        let worker = Task { [weak self] in
            for await _ in requests {
                guard let self else { return }
                await self.sync()
            }
        }
        let accepted: Bool = locked {
            guard !started, !stopped else { return false }
            started = true
            delegateInstalled = installDelegate
            syncRequests = continuation
            syncWorker = worker
            return true
        }
        guard accepted else {
            continuation.finish()
            worker.cancel()
            return self
        }
        if installDelegate {
            center.setDelegate(self)
        }
        // 同步登记：系统可能就是为这次后台刷新把进程拉起来的，启动返回之后再登记就晚了
        registerBackgroundRefresh()
        appState.start { [weak self] state in self?.appStateChanged(state) }
        continuation.yield(())
        let application = self.application
        Task { await application.registerForRemoteNotifications() }
        return self
    }

    /// 停止跟踪、卸下自己装的代理、结束 `routes()` 与 `permissionChanges()` 的流。停了不能再启动。
    public func stop() {
        if shutDown() {
            center.removeDelegate(self)
        }
    }

    /// 接上宿主：补报令牌与权限，路由接上之前留下的那次点击，并开始照办宿主报来的通知更正。
    /// 配置了可用的 App Group 时把通知快照目录交给它；等着宿主的后台刷新接着做。
    /// 换宿主时令牌会重新登记，上一个宿主的更正不再照办。
    public func attach(_ host: any FlarePushHost) {
        let (tap, generation, waiters, inBackground):
            ([String: String]?, UInt64, [CheckedContinuation<(any FlarePushHost)?, Never>], Bool) = locked {
                self.host = host
                self.generation &+= 1
                sentToken = nil
                let pending = pendingTap
                pendingTap = nil
                let waiting = Array(hostWaiters.values)
                hostWaiters = [:]
                return (pending, self.generation, waiting, lastAppState == .background)
            }
        followCorrections(of: host, generation: generation)
        handOverNotificationDirectory(to: host, generation: generation)
        requestSync()
        if let tap {
            Task { await self.resolveTap(tap, with: host, generation: generation) }
        }
        waiters.forEach { $0.resume(returning: host) }
        // 在后台恢复的会话（后台刷新或推送把进程拉起来）也排上下一次刷新
        if inBackground {
            scheduleBackgroundRefresh()
        }
    }

    /// 摘下宿主（客户端释放、但账号没有退出时）。之后的推送按载荷原样提示，点击留到下次接上，更正不再照办。
    public func detach() {
        let reader: Task<Void, Never>? = locked {
            host = nil
            generation &+= 1
            sentToken = nil
            return takeCorrections()
        }
        reader?.cancel()
    }

    /// 登出：摘下宿主，丢掉留着的点击，清掉通知中心里本 SDK 的通知（已展示的与等待展示的）并把角标归零；
    /// 已登记的令牌也忘掉，下一个账号接上时重新登记；排着的后台刷新撤掉。没 `start()` 时不碰系统通知中心。
    public func signOut() async {
        let (active, reader): (Bool, Task<Void, Never>?) = locked {
            host = nil
            generation &+= 1
            sentToken = nil
            pendingTap = nil
            heldRoute = nil
            return (started && !stopped, takeCorrections())
        }
        reader?.cancel()
        guard active else { return }
        if let identifier = configuration.backgroundRefreshTask {
            backgroundRefresh.cancel(identifier: identifier)
        }
        await removeAllFlareNotifications()
        await report { try await self.center.setBadge(0) }
    }

    // MARK: - 通知更正

    /// 撤掉这些合并键的通知。已展示的按请求标识与载荷里的 `collapse_id` 找（APNs 送达的通知，请求标识不保证等于
    /// 合并键），还在等展示的按请求标识。宿主报来的更正模块自己照办，应用不用调；没 `start()` 时什么也不做。
    public func clearNotifications(collapseIds: [String]) async {
        guard isStarted else { return }
        await removeNotifications(collapseIds: collapseIds)
    }

    /// 撤掉本 SDK 的全部通知（已展示的与等待展示的），应用自己的通知不动。没 `start()` 时什么也不做。
    public func clearAllNotifications() async {
        guard isStarted else { return }
        await removeAllFlareNotifications()
    }

    /// 把应用角标写成 `count`（负数按 0）。宿主报来的角标模块自己写，应用不用调；没 `start()` 时什么也不做。
    public func setBadge(_ count: Int) async {
        guard isStarted else { return }
        await report { try await self.center.setBadge(max(count, 0)) }
    }

    /// 读宿主的更正流并照办，直到被取消；换了宿主或摘下之后读到的不再照办。
    private func followCorrections(of host: any FlarePushHost, generation: UInt64) {
        let stream = host.notificationCorrections()
        let reader = Task { [weak self] in
            for await correction in stream {
                guard let self, self.locked({ self.generation == generation }) else { return }
                await self.applyCorrection(correction)
            }
        }
        // 已经换了宿主或停了：这个读取者作废；否则顶掉上一个
        let cancelled: Task<Void, Never>? = locked {
            guard self.generation == generation, !stopped else { return reader }
            let previous = corrections
            corrections = reader
            return previous
        }
        cancelled?.cancel()
    }

    /// 在锁里调用：拿走读更正的任务，由调用方在锁外取消。
    private func takeCorrections() -> Task<Void, Never>? {
        let reader = corrections
        corrections = nil
        return reader
    }

    private func applyCorrection(_ correction: PlatformNotificationCorrection) async {
        switch correction {
        case let .clear(collapseIds):
            await clearNotifications(collapseIds: collapseIds)
        case .clearAll:
            await clearAllNotifications()
        case let .badge(count):
            await setBadge(Int(count))
        }
    }

    private func removeAllFlareNotifications() async {
        let delivered = await center.deliveredNotifications().filter(\.isFlare).map(\.identifier)
        if !delivered.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
        let pending = await center.pendingNotifications().filter(\.isFlare).map(\.identifier)
        if !pending.isEmpty {
            center.removePendingNotifications(withIdentifiers: pending)
        }
    }

    // MARK: - 权限与令牌

    /// 当前的系统通知权限；没 `start()`（不是应用进程）时为 nil，不碰系统通知中心。
    public func permissionStatus() async -> PlatformPushPermissionStatus? {
        guard isStarted else { return nil }
        let status = await center.permissionStatus()
        publishPermission(status)
        return status
    }

    /// 权限的变化。订阅时先给已知的当前值，之后在启动、申请之后与每次回到前台重读，变了才发；
    /// 多个订阅者各收一份，`stop()` 时结束。
    public func permissionChanges() -> AsyncStream<PlatformPushPermissionStatus> {
        let id = UUID()
        var captured: AsyncStream<PlatformPushPermissionStatus>.Continuation?
        let stream = AsyncStream<PlatformPushPermissionStatus>(bufferingPolicy: .bufferingNewest(1)) { captured = $0 }
        let continuation = captured!
        continuation.onTermination = { [weak self] _ in
            self?.removePermissionSubscriber(id)
        }
        // 登记与补发当前值在同一把锁里：与并发的变化之间不会把旧值排在新值后面
        lock.lock()
        let subscribed = !stopped
        if subscribed {
            permissionSubscribers[id] = continuation
            if let current = lastPermission {
                continuation.yield(current)
            }
        }
        lock.unlock()
        if !subscribed {
            continuation.finish()
        }
        return stream
    }

    /// 申请通知权限。模块自己从不弹窗：应用在用户能理解的时机调用它。返回是否允许；没 `start()` 时为 false。
    /// 结果（包括拒绝）随后报给宿主，`permissionChanges()` 也会收到。
    @discardableResult
    public func requestAuthorization(options: UNAuthorizationOptions = [.alert, .badge, .sound]) async -> Bool {
        guard isStarted else { return false }
        var granted = false
        do {
            granted = try await center.requestAuthorization(options: options)
        } catch {
            onError(error)
        }
        await application.registerForRemoteNotifications()
        requestSync()
        return granted
    }

    /// 打开系统设置里本应用的通知页（iOS 16 以前是本应用的设置页）；打不开时返回 false。
    public func openNotificationSettings() async -> Bool {
        await application.openNotificationSettings()
    }

    /// 应用内选的语言（BCP 47，例如 `zh-CN`），令牌登记用它代替系统语言：服务端兜底文案要和界面一致。
    /// 变了立刻重新登记，不等回到前台；nil 或空白回到系统语言。
    public func setLocale(_ languageTag: String?) {
        let trimmed = languageTag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let tag = trimmed.isEmpty ? nil : trimmed
        let changed: Bool = locked {
            guard localeOverride != tag else { return false }
            localeOverride = tag
            return true
        }
        if changed {
            requestSync()
        }
    }

    /// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`。
    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = PlatformPushToken.hex(deviceToken)
        locked { apnsToken = token }
        requestSync()
    }

    /// `application(_:didFailToRegisterForRemoteNotificationsWithError:)`。没有令牌时引擎停在等令牌，下次启动再要。
    public func didFailToRegisterForRemoteNotifications(error: Error) {
        onError(error)
    }

    // MARK: - 远程推送

    /// 静默推送（`content-available`）。应用在后台时，返回前进程会一直保持到引擎的唤醒结束。
    public func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> PlatformRemoteMessageResult {
        await handleRemoteMessage(
            PlatformPushPayload.flatten(userInfo),
            shownBySystem: PlatformPushPayload.carriesAlert(userInfo)
        )
    }

    #if canImport(UIKit) && !os(watchOS)
    /// `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`：处理完才回调系统。
    public func didReceiveRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let payload = PlatformPushPayload.flatten(userInfo)
        let shownBySystem = PlatformPushPayload.carriesAlert(userInfo)
        Task {
            let result = await self.handleRemoteMessage(payload, shownBySystem: shownBySystem)
            completionHandler(result.backgroundFetchResult)
        }
    }
    #endif

    func handleRemoteMessage(_ payload: [String: String], shownBySystem: Bool) async -> PlatformRemoteMessageResult {
        guard PlatformPushPayload.isFlare(payload: payload) else { return .noData }
        guard let host = attached()?.host else {
            // 推送把进程冷启动起来时会话还没恢复：按载荷原样提示，提示不丢
            await apply(PlatformPushPayload.outcome(fromPayload: payload), payload: payload, shownBySystem: shownBySystem)
            return .newData
        }
        let outcome: PlatformPushOutcome
        do {
            outcome = try await callHost("handleRemoteMessage", limitMs: remoteMessageLimitMs) {
                try await host.handleRemoteMessage(provider: "apns", payload: payload, budgetMs: Self.silentPushBudgetMs)
            }
        } catch {
            // 宿主出错或超时：按载荷原样提示
            onError(error)
            await apply(PlatformPushPayload.outcome(fromPayload: payload), payload: payload, shownBySystem: shownBySystem)
            return .failed
        }
        await apply(outcome, payload: payload, shownBySystem: shownBySystem)
        if Self.startsWake(outcome) {
            // 引擎在预算内连上、同步，到期后重新托管。回调系统之前进程不能被挂起，否则留下一条僵尸连接
            await self.wait(Self.silentPushBudgetMs + Self.parkingGraceMs)
        }
        return outcome.action == .ignore ? .noData : .newData
    }

    /// 不属于当前账号、没登录、载荷坏掉的推送，引擎不唤醒。
    private static func startsWake(_ outcome: PlatformPushOutcome) -> Bool {
        guard outcome.action == .ignore else { return true }
        switch outcome.reason {
        case "otherAccount", "notLoggedIn", "malformed":
            return false
        default:
            return true
        }
    }

    private func apply(_ outcome: PlatformPushOutcome, payload: [String: String], shownBySystem: Bool) async {
        if !outcome.clearCollapseIds.isEmpty {
            await removeNotifications(collapseIds: outcome.clearCollapseIds)
        }
        if let badge = outcome.badge {
            await report { try await self.center.setBadge(Int(badge)) }
        }
        // 带 `aps.alert` 的推送系统自己展示（前台由 willPresent 决定），只给静默推送补本地通知
        guard !shownBySystem,
              outcome.action == .present || outcome.action == .update,
              let presentation = outcome.presentation,
              presentation.surface == .system,
              !presentation.title.isEmpty || !presentation.body.isEmpty else {
            return
        }
        let notification = PlatformLocalNotification(
            identifier: presentation.collapseId.isEmpty ? UUID().uuidString : presentation.collapseId,
            threadId: presentation.threadId,
            title: presentation.title,
            body: presentation.body,
            sound: outcome.action == .present && presentation.sound,
            passive: outcome.action == .update,
            userInfo: payload
        )
        await report { try await self.center.add(notification) }
    }

    private func removeNotifications(collapseIds: [String]) async {
        let wanted = Set(collapseIds.filter { !$0.isEmpty })
        guard !wanted.isEmpty else { return }
        // APNs 送达的通知，请求标识不保证等于合并键：再按载荷里的 collapse_id 找一遍
        let delivered = await center.deliveredNotifications()
        let matched = delivered
            .filter { notification in
                if wanted.contains(notification.identifier) { return true }
                guard let collapseId = notification.collapseId else { return false }
                return wanted.contains(collapseId)
            }
            .map(\.identifier)
        center.removeDeliveredNotifications(withIdentifiers: wanted.union(matched).sorted())
        // 本模块补的本地通知以合并键为请求标识，还没展示出来的一并撤掉
        let pending = await center.pendingNotifications().map(\.identifier).filter(wanted.contains)
        if !pending.isEmpty {
            center.removePendingNotifications(withIdentifiers: pending.sorted())
        }
    }

    // MARK: - 通知中心代理

    /// 前台收到通知。本 SDK 的远程推送问宿主：应用内提示时不出系统横幅；其余通知按系统默认展示。
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let request = notification.request
        let payload = PlatformPushPayload.flatten(request.content.userInfo)
        let remote = request.trigger is UNPushNotificationTrigger
        Task {
            completionHandler(await self.presentationOptions(payload, remote: remote))
        }
    }

    /// 点击通知（含冷启动）。只处理默认动作。
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        let payload = PlatformPushPayload.flatten(response.notification.request.content.userInfo)
        Task {
            await self.handleTap(payload)
            completionHandler()
        }
    }

    func presentationOptions(_ payload: [String: String], remote: Bool) async -> UNNotificationPresentationOptions {
        // 本模块补的本地通知已经决定过；不是本 SDK 的通知不归它管
        guard remote, PlatformPushPayload.isFlare(payload: payload) else { return Self.alert(sound: true) }
        guard let host = attached()?.host else { return Self.alert(sound: true) }
        do {
            let outcome = try await callHost("handleRemoteMessage", limitMs: remoteMessageLimitMs) {
                try await host.handleRemoteMessage(provider: "apns", payload: payload, budgetMs: 0)
            }
            await apply(outcome, payload: payload, shownBySystem: true)
            guard let presentation = outcome.presentation, presentation.surface == .system else { return [] }
            switch outcome.action {
            case .present:
                return Self.alert(sound: presentation.sound)
            case .update:
                return [.list]
            case .clear, .badgeOnly, .ignore:
                return []
            }
        } catch {
            // 宿主出错或超时：按系统默认展示，提示不丢
            onError(error)
            return Self.alert(sound: true)
        }
    }

    private static func alert(sound: Bool) -> UNNotificationPresentationOptions {
        sound ? [.banner, .list, .badge, .sound] : [.banner, .list, .badge]
    }

    // MARK: - 点击路由

    /// 点击要去的会话。没有订阅者时最近的一次留着，交给下一个订阅者；多个订阅者各收一份。
    public func routes() -> AsyncStream<PlatformTapRoute> {
        let id = UUID()
        var captured: AsyncStream<PlatformTapRoute>.Continuation?
        let stream = AsyncStream<PlatformTapRoute>(bufferingPolicy: .bufferingNewest(1)) { captured = $0 }
        let continuation = captured!
        continuation.onTermination = { [weak self] _ in
            self?.removeRouteSubscriber(id)
        }
        let subscribed: Bool
        var held: PlatformTapRoute?
        lock.lock()
        subscribed = !stopped
        if subscribed {
            routeSubscribers[id] = continuation
            held = heldRoute
            heldRoute = nil
        }
        lock.unlock()
        guard subscribed else {
            continuation.finish()
            return stream
        }
        if let held {
            continuation.yield(held)
        }
        return stream
    }

    private func removeRouteSubscriber(_ id: UUID) {
        locked { _ = routeSubscribers.removeValue(forKey: id) }
    }

    private func removePermissionSubscriber(_ id: UUID) {
        locked { _ = permissionSubscribers.removeValue(forKey: id) }
    }

    func handleTap(_ payload: [String: String]) async {
        guard PlatformPushPayload.isFlare(payload: payload) else { return }
        // 冷启动的点击常常早于会话恢复：先留着（只留最近一次），接上宿主再解析
        let current: Attached? = locked {
            if host == nil {
                pendingTap = payload
            }
            return host.map { Attached(host: $0, generation: generation) }
        }
        guard let current else { return }
        await resolveTap(payload, with: current.host, generation: current.generation)
    }

    /// 解析期间登出或换了宿主，结果作废：不能把上一个账号的会话打开。
    private func resolveTap(_ payload: [String: String], with host: any FlarePushHost, generation: UInt64) async {
        do {
            let route = try await callHost("resolveNotificationTap") {
                try await host.resolveNotificationTap(payload: payload)
            }
            guard let route, locked({ self.generation == generation }) else { return }
            emit(route)
        } catch {
            onError(error)
        }
    }

    private func emit(_ route: PlatformTapRoute) {
        let subscribers: [AsyncStream<PlatformTapRoute>.Continuation] = locked {
            let current = Array(routeSubscribers.values)
            if current.isEmpty {
                heldRoute = route
            }
            return current
        }
        subscribers.forEach { $0.yield(route) }
    }

    // MARK: - 通知扩展与后台刷新

    /// App Group 的容器目录；应用没有这个 App Group 的权限时为 nil。
    static let systemAppGroupContainer: @Sendable (_ appGroupIdentifier: String) -> URL? = { group in
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    /// 通知快照目录（`<App Group 容器>/flare-notify`），第一次用时建好。没配 App Group、取不到容器或建不了目录时
    /// 为 nil；取不到容器（多半是 entitlements 里没有这个 App Group）经 `onError` 报一次。
    func notificationDirectory() -> String? {
        if let resolved = locked({ resolvedNotificationDirectory }) {
            return resolved
        }
        let resolved = resolveNotificationDirectory()
        return locked {
            // 并发的两次解析以先落下的为准
            if let earlier = resolvedNotificationDirectory {
                return earlier
            }
            resolvedNotificationDirectory = .some(resolved)
            return resolved
        }
    }

    private func resolveNotificationDirectory() -> String? {
        guard let group = configuration.appGroup else { return nil }
        guard let container = appGroupContainer(group) else {
            onError(PlatformPushConfigurationError.appGroupUnavailable(group))
            return nil
        }
        let directory = container.appendingPathComponent(Self.notificationDirectoryName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: Self.notificationDirectoryAttributes
            )
        } catch {
            onError(error)
            return nil
        }
        return directory.path
    }

    /// 通知扩展在设备锁着时也要读快照、写回执：目录用「首次解锁之后可读写」的保护级别，里面新建的文件随它。
    private static var notificationDirectoryAttributes: [FileAttributeKey: Any]? {
        #if os(iOS)
        return [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        #else
        return nil
        #endif
    }

    /// 令牌登记带不带 `serviceExtension`：应用声明带了通知扩展，并且快照目录可用（扩展读得到快照、记得下回执）。
    private func servesNotificationExtension() -> Bool {
        configuration.hasNotificationServiceExtension && notificationDirectory() != nil
    }

    /// 把快照目录交给刚接上的宿主；没有可用的 App Group 时不调，期间换了宿主也不调。
    private func handOverNotificationDirectory(to host: any FlarePushHost, generation: UInt64) {
        guard configuration.appGroup != nil else { return }
        Task { [weak self] in
            guard let self, let directory = self.notificationDirectory(),
                  self.locked({ self.generation == generation }) else { return }
            do {
                try await self.callHost("setNotificationSnapshotDirectory") {
                    await host.setNotificationSnapshotDirectory(directory)
                }
            } catch {
                self.onError(error)
            }
        }
    }

    /// 配了后台刷新标识时登记任务的处理函数。标识没列在 Info.plist 里时经 `onError` 报出，后台刷新不开。
    private func registerBackgroundRefresh() {
        guard let identifier = configuration.backgroundRefreshTask else { return }
        do {
            try backgroundRefresh.register(identifier: identifier) { [weak self] task in
                guard let self else {
                    task.complete(success: false)
                    return
                }
                self.runBackgroundRefresh(task)
            }
        } catch {
            onError(error)
        }
    }

    /// 排一次不早于 15 分钟后的后台刷新（系统只留最后一次）。没配标识或没 `start()` 时什么也不做。
    private func scheduleBackgroundRefresh() {
        guard let identifier = configuration.backgroundRefreshTask, isStarted else { return }
        do {
            try backgroundRefresh.schedule(
                identifier: identifier,
                earliest: Date().addingTimeInterval(Self.backgroundRefreshInterval)
            )
        } catch {
            onError(error)
        }
    }

    /// 系统交来的一次后台刷新：等到宿主（进程可能正是为它冷启动的，会话还在恢复），先排好下一次，再交给宿主做
    /// 一次 25 秒的刷新，按结果结束任务。等不到宿主、出错或系统提前收回时间时按未完成结束。
    func runBackgroundRefresh(_ task: any PlatformBackgroundRefreshTask) {
        task.setExpirationHandler { [weak task] in
            task?.complete(success: false)
        }
        Task { [weak self] in
            guard let self, let host = await self.waitForHost() else {
                task.complete(success: false)
                return
            }
            self.scheduleBackgroundRefresh()
            let budgetMs = Self.backgroundRefreshBudgetMs
            let completed: Bool
            do {
                // 引擎的刷新在预算内收尾、重新托管链路；上限多给托管的那一段
                completed = try await self.callHost(
                    "backgroundRefresh",
                    limitMs: UInt32(budgetMs) + Self.parkingGraceMs
                ) {
                    await host.backgroundRefresh(budgetMs: budgetMs)
                }
            } catch {
                self.onError(error)
                completed = false
            }
            task.complete(success: completed)
        }
    }

    /// 当前的宿主；还没接上时等到接上，最多 `hostWaitLimitMs`。停止或等到上限时为 nil。
    private func waitForHost() async -> (any FlarePushHost)? {
        let id = UUID()
        let limitMs = hostWaitLimitMs
        return await withCheckedContinuation { (continuation: CheckedContinuation<(any FlarePushHost)?, Never>) in
            let immediate: (any FlarePushHost)?? = locked {
                if let host {
                    return .some(host)
                }
                if stopped {
                    return .some(nil)
                }
                hostWaiters[id] = continuation
                return nil
            }
            if let immediate {
                continuation.resume(returning: immediate)
                return
            }
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(limitMs) * 1_000_000)
                self?.stopWaiting(id)
            }
        }
    }

    /// 等到上限：还在等的那一个交回 nil（已经被接上或停止交回过的不再交）。
    private func stopWaiting(_ id: UUID) {
        let waiter = locked { hostWaiters.removeValue(forKey: id) }
        waiter?.resume(returning: nil)
    }

    // MARK: - 前后台与同步

    private func appStateChanged(_ state: PlatformAppState) {
        let previous: PlatformAppState? = locked {
            let last = lastAppState
            lastAppState = state
            return last
        }
        // 回到前台：权限可能在系统设置里改过，语言、时区、版本也可能变了。
        // 角标不在这里写：应用运行时引擎每次未读总数变化都报角标，进了后台交给推送带的角标
        if state == .foreground, previous == .background {
            requestSync()
        }
        // 进后台：登录着才排下一次后台刷新，没有会话可刷的进程不必被叫醒
        if state == .background, previous != .background, attached() != nil {
            scheduleBackgroundRefresh()
        }
    }

    private func requestSync() {
        let requests = locked { syncRequests }
        requests?.yield(())
    }

    /// 读权限并发布；接着宿主时报权限，权限允许时登记令牌（应用信息变了才重登），再对账。拒绝不排在令牌登记后面。
    private func sync() async {
        let status = await center.permissionStatus()
        publishPermission(status)
        guard let current = attached() else { return }
        let host = current.host
        let allowed = status == .granted
        if allowed {
            if let token = currentToken(), needsSending(token, generation: current.generation) {
                do {
                    try await callHost("updatePushToken") { try await host.updatePushToken(token) }
                    markSent(token, generation: current.generation)
                } catch {
                    onError(error)
                }
            }
        } else {
            // 引擎在拒绝时吊销绑定；再次允许时令牌要重新登记
            markSent(nil, generation: current.generation)
        }
        await report { try await self.callHost("setPushPermission") { try await host.setPushPermission(allowed: allowed) } }
        await report { try await self.callHost("reconcilePush") { try await host.reconcilePush() } }
    }

    /// 变了才发给订阅者。在锁里发：与新订阅者补发的当前值之间顺序不乱。
    private func publishPermission(_ status: PlatformPushPermissionStatus) {
        lock.lock()
        defer { lock.unlock() }
        guard lastPermission != status else { return }
        lastPermission = status
        for subscriber in permissionSubscribers.values {
            subscriber.yield(status)
        }
    }

    private func currentToken() -> PlatformPushToken? {
        let state: (token: String, locale: String?)? = locked {
            apnsToken.map { (token: $0, locale: localeOverride) }
        }
        guard let state else { return nil }
        var device = deviceInfo()
        if let locale = state.locale {
            device.locale = locale
        }
        var token = PlatformPushToken.apns(token: state.token, device: device)
        if servesNotificationExtension() {
            token.capabilities.append(PlatformPushToken.serviceExtensionCapability)
        }
        return token
    }

    private func needsSending(_ token: PlatformPushToken, generation: UInt64) -> Bool {
        locked { self.generation == generation && sentToken != token }
    }

    private func markSent(_ token: PlatformPushToken?, generation: UInt64) {
        locked {
            if self.generation == generation {
                sentToken = token
            }
        }
    }

    private func attached() -> Attached? {
        locked { host.map { Attached(host: $0, generation: generation) } }
    }

    /// 调宿主，不超过上限（缺省是其余调用的上限）。宿主卡住、不理会取消时按 `PlatformPushHostTimeout` 失败，
    /// 不等它返回；它晚到的答复丢掉。
    private func callHost<Value: Sendable>(
        _ call: String,
        limitMs: UInt32? = nil,
        _ body: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let limit = limitMs ?? hostCallLimitMs
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Value, Error>) in
            let race = HostCallRace(continuation)
            let work = Task {
                do {
                    let value = try await body()
                    race.finish(.success(value))
                } catch {
                    race.finish(.failure(error))
                }
            }
            race.arm(Task {
                try? await Task.sleep(nanoseconds: UInt64(limit) * 1_000_000)
                // 被取消说明宿主先答复了
                guard !Task.isCancelled else { return }
                if race.finish(.failure(PlatformPushHostTimeout(call: call, limitMs: limit))) {
                    work.cancel()
                }
            })
        }
    }

    /// 停止；返回是否装过代理。
    private func shutDown() -> Bool {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return false
        }
        stopped = true
        let wasStarted = started
        let installed = delegateInstalled
        let requests = syncRequests
        let worker = syncWorker
        let reader = takeCorrections()
        let routes = Array(routeSubscribers.values)
        let permissions = Array(permissionSubscribers.values)
        let waiters = Array(hostWaiters.values)
        syncRequests = nil
        syncWorker = nil
        routeSubscribers = [:]
        permissionSubscribers = [:]
        hostWaiters = [:]
        lock.unlock()
        if wasStarted {
            appState.stop()
        }
        requests?.finish()
        worker?.cancel()
        reader?.cancel()
        routes.forEach { $0.finish() }
        permissions.forEach { $0.finish() }
        waiters.forEach { $0.resume(returning: nil) }
        return wasStarted && installed
    }

    private func report(_ call: () async throws -> Void) async {
        do {
            try await call()
        } catch {
            onError(error)
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// 一次宿主调用的结果只交一次：宿主答复与超时谁先到算谁，先到的一方顺手停掉另一方的计时。
private final class HostCallRace<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var timer: Task<Void, Never>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    /// 交来计时任务；调用已经有结果时直接停掉它。
    func arm(_ timer: Task<Void, Never>) {
        lock.lock()
        let finished = continuation == nil
        if !finished {
            self.timer = timer
        }
        lock.unlock()
        if finished {
            timer.cancel()
        }
    }

    /// 返回这次是否交了结果（之前没人交过）。
    @discardableResult
    func finish(_ result: Result<Value, Error>) -> Bool {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return false
        }
        self.continuation = nil
        let timer = self.timer
        self.timer = nil
        lock.unlock()
        timer?.cancel()
        continuation.resume(with: result)
        return true
    }
}

#if canImport(UIKit) && !os(watchOS)
extension PlatformRemoteMessageResult {
    public var backgroundFetchResult: UIBackgroundFetchResult {
        switch self {
        case .newData: return .newData
        case .noData: return .noData
        case .failed: return .failed
        }
    }
}
#endif
