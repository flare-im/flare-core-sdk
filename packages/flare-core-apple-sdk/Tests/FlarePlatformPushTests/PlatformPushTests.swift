import UserNotifications
import XCTest
import FlarePlatformLifecycle
@testable import FlarePlatformPush

final class PlatformPushTests: XCTestCase {
    private let flarePayload: [String: String] = [
        "uid": "u-1", "tenant_id": "t-1", "conversation_id": "conv-1", "message_id": "m-9", "seq": "42",
        "collapse_id": "c:1", "thread_id": "c:1", "disposition": "loud", "alert_class": "normal", "count": "1",
        "title": "Ann", "body": "hi", "sound": "1",
    ]

    private func presentation(surface: PlatformNotificationPresentation.Surface = .system, sound: Bool = true)
        -> PlatformNotificationPresentation {
        PlatformNotificationPresentation(
            collapseId: "c:1", threadId: "t:1", conversationId: "conv-1", messageId: "m-9", seq: 42,
            title: "Ann", body: "hi", count: 1, sound: sound, channel: .messages, surface: surface
        )
    }

    /// 启动：装代理、向 APNs 要令牌、把拒绝也报给宿主，再对账。
    func testStartReportsTheDenialAndRegistersForApns() async throws {
        let rig = Rig()
        rig.push.attach(rig.host)
        rig.push.start()

        try await eventually { rig.host.calls == [.permission(false), .reconcile] }
        try await eventually { rig.application.registrations == 1 }
        XCTAssertTrue(rig.center.delegate === rig.push)
        XCTAssertEqual(rig.center.allowedReads, 1)

        rig.push.stop()
        XCTAssertNil(rig.center.delegate)
        XCTAssertTrue(rig.appState.stopped)
    }

    /// 允许时令牌带着应用信息登记，信息不变不重登；回到前台重新报权限、对账，语言变了重登。
    func testTheTokenGoesOutOnceUntilTheDeviceInfoChanges() async throws {
        let rig = Rig()
        rig.center.allowed = true
        rig.push.attach(rig.host)
        rig.push.start()
        try await eventually { rig.host.calls == [.permission(true), .reconcile] }

        rig.push.didRegisterForRemoteNotifications(deviceToken: Data([0xde, 0xad, 0xbe, 0xef]))
        let first = PlatformPushToken.apns(token: "deadbeef", device: rig.device.value)
        try await eventually { rig.host.calls.count == 5 }
        XCTAssertEqual(Array(rig.host.calls[2...]), [.token(first), .permission(true), .reconcile])

        rig.appState.emit(.foreground)
        rig.appState.emit(.background)
        rig.appState.emit(.foreground)
        try await eventually { rig.host.calls.count == 7 }
        XCTAssertEqual(rig.host.tokens, [first], "unchanged info is not registered again")

        rig.device.value.locale = "en-US"
        rig.appState.emit(.background)
        rig.appState.emit(.foreground)
        let second = PlatformPushToken.apns(token: "deadbeef", device: rig.device.value)
        try await eventually { rig.host.tokens == [first, second] }
        rig.push.stop()
    }

    /// 拒绝不排在令牌后面；再次允许时令牌重新登记。
    func testADenialForgetsTheRegisteredToken() async throws {
        let rig = Rig()
        rig.center.allowed = true
        rig.push.didRegisterForRemoteNotifications(deviceToken: Data([0x01]))
        rig.push.attach(rig.host)
        rig.push.start()
        try await eventually { rig.host.tokens.count == 1 }

        rig.center.allowed = false
        rig.appState.emit(.background)
        rig.appState.emit(.foreground)
        try await eventually { rig.host.calls.contains(.permission(false)) }

        rig.center.allowed = true
        rig.appState.emit(.background)
        rig.appState.emit(.foreground)
        try await eventually { rig.host.tokens.count == 2 }
        rig.push.stop()
    }

    /// 应用选时机申请权限：返回结果，向 APNs 要令牌，并把新权限报给宿主。
    func testRequestAuthorizationRegistersAndReports() async throws {
        let rig = Rig()
        rig.push.attach(rig.host)
        rig.push.start()
        try await eventually { rig.host.calls.contains(.permission(false)) }

        rig.center.grant = true
        let granted = await rig.push.requestAuthorization()

        XCTAssertTrue(granted)
        XCTAssertEqual(rig.center.authorizationRequests, [[.alert, .badge, .sound]])
        try await eventually { rig.application.registrations == 2 }
        try await eventually { rig.host.calls.contains(.permission(true)) }
        rig.push.stop()
    }

    /// 静默推送：载荷交给引擎，按结果清旧通知、写角标、补一条以合并键为标识的本地通知，
    /// 然后保持到引擎的唤醒结束。
    func testASilentPushAppliesTheOutcomeAndHoldsForTheWake() async throws {
        let rig = Rig()
        rig.host.outcome = PlatformPushOutcome(
            action: .present, presentation: presentation(), clearCollapseIds: ["c:0"], badge: 5
        )
        rig.center.delivered = [
            PlatformDeliveredNotification(identifier: "apns-0", collapseId: "c:0"),
            PlatformDeliveredNotification(identifier: "apns-7", collapseId: "c:7"),
        ]
        rig.push.attach(rig.host)

        let result = await rig.push.handleRemoteMessage(flarePayload, shownBySystem: false)

        XCTAssertEqual(result, .newData)
        XCTAssertTrue(rig.host.calls.contains(.remote("apns", flarePayload, PlatformPush.silentPushBudgetMs)))
        XCTAssertEqual(rig.center.removed, [["apns-0", "c:0"]])
        XCTAssertEqual(rig.center.badges, [5])
        XCTAssertEqual(rig.center.added, [PlatformLocalNotification(
            identifier: "c:1", threadId: "t:1", title: "Ann", body: "hi", sound: true, passive: false,
            userInfo: flarePayload
        )])
        XCTAssertEqual(rig.waits.value, [PlatformPush.silentPushBudgetMs + PlatformPush.parkingGraceMs])
    }

    /// 静默更新进通知中心不响；应用在前台（应用内提示）时不补系统通知；系统已展示的不再补。
    func testUpdatesArePassiveAndInAppOrAlertedPushesAddNothing() async throws {
        let rig = Rig()
        rig.push.attach(rig.host)

        rig.host.outcome = PlatformPushOutcome(action: .update, presentation: presentation())
        _ = await rig.push.handleRemoteMessage(flarePayload, shownBySystem: false)
        XCTAssertEqual(rig.center.added.last?.passive, true)
        XCTAssertEqual(rig.center.added.last?.sound, false)

        rig.host.outcome = PlatformPushOutcome(action: .present, presentation: presentation(surface: .inApp))
        _ = await rig.push.handleRemoteMessage(flarePayload, shownBySystem: false)
        rig.host.outcome = PlatformPushOutcome(action: .present, presentation: presentation())
        _ = await rig.push.handleRemoteMessage(flarePayload, shownBySystem: true)
        XCTAssertEqual(rig.center.added.count, 1)
    }

    /// 不属于当前账号的推送什么都不做，也不等唤醒。
    func testAPushForAnotherAccountIsIgnoredAtOnce() async {
        let rig = Rig()
        rig.host.outcome = PlatformPushOutcome(action: .ignore, reason: "otherAccount")
        rig.push.attach(rig.host)

        let result = await rig.push.handleRemoteMessage(flarePayload, shownBySystem: false)

        XCTAssertEqual(result, .noData)
        XCTAssertTrue(rig.center.added.isEmpty)
        XCTAssertTrue(rig.waits.value.isEmpty)
    }

    /// 会话还没恢复（没有宿主）或宿主出错：按载荷原样提示，系统已展示的不重复。
    func testWithoutAHostTheSilentPushIsPresentedFromThePayload() async {
        let rig = Rig()
        var payload = flarePayload
        payload["badge"] = "3"

        let result = await rig.push.handleRemoteMessage(payload, shownBySystem: false)

        XCTAssertEqual(result, .newData)
        XCTAssertEqual(rig.center.added.map(\.identifier), ["c:1"])
        XCTAssertEqual(rig.center.added.first?.sound, true)
        XCTAssertEqual(rig.center.badges, [3])

        _ = await rig.push.handleRemoteMessage(payload, shownBySystem: true)
        XCTAssertEqual(rig.center.added.count, 1)

        rig.host.failure = URLError(.timedOut)
        rig.push.attach(rig.host)
        let failed = await rig.push.handleRemoteMessage(payload, shownBySystem: false)
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(rig.center.added.count, 2)
        XCTAssertEqual(rig.errors.value.count, 1)

        let foreign = await rig.push.handleRemoteMessage(["kind": "reminder"], shownBySystem: false)
        XCTAssertEqual(foreign, .noData)
    }

    /// 前台收到推送：应用内提示时不出横幅；系统展示时按声音给选项；静默更新只进列表；
    /// 没有宿主、不是远程推送、不是本 SDK 的通知按默认展示。
    func testForegroundPresentationAsksTheHost() async {
        let rig = Rig()
        let alert: UNNotificationPresentationOptions = [.banner, .list, .badge, .sound]

        let withoutHost = await rig.push.presentationOptions(flarePayload, remote: true)
        XCTAssertEqual(withoutHost, alert)

        rig.push.attach(rig.host)
        rig.host.outcome = PlatformPushOutcome(action: .present, presentation: presentation(surface: .inApp), badge: 2)
        let inApp = await rig.push.presentationOptions(flarePayload, remote: true)
        XCTAssertEqual(inApp, [])
        XCTAssertEqual(rig.center.badges, [2])
        XCTAssertTrue(rig.host.calls.contains(.remote("apns", flarePayload, 0)), "no wake while in the foreground")

        rig.host.outcome = PlatformPushOutcome(action: .present, presentation: presentation(sound: false))
        let quietAlert = await rig.push.presentationOptions(flarePayload, remote: true)
        XCTAssertEqual(quietAlert, [.banner, .list, .badge])

        rig.host.outcome = PlatformPushOutcome(action: .update, presentation: presentation())
        let update = await rig.push.presentationOptions(flarePayload, remote: true)
        XCTAssertEqual(update, [.list])

        rig.host.outcome = PlatformPushOutcome(action: .ignore, reason: "alreadyAlerted")
        let ignored = await rig.push.presentationOptions(flarePayload, remote: true)
        XCTAssertEqual(ignored, [])

        let local = await rig.push.presentationOptions(flarePayload, remote: false)
        XCTAssertEqual(local, alert)
        let foreign = await rig.push.presentationOptions(["kind": "reminder"], remote: true)
        XCTAssertEqual(foreign, alert)
        XCTAssertTrue(rig.center.added.isEmpty, "the system shows the pushed notification itself")
    }

    /// 宿主接上之前的点击只留最近一次，接上后解析并发出；没有订阅者时交给下一个订阅者。
    func testATapBeforeTheHostIsRoutedOnceAttached() async throws {
        let rig = Rig()
        var older = flarePayload
        older["conversation_id"] = "conv-old"
        await rig.push.handleTap(older)
        await rig.push.handleTap(flarePayload)

        rig.host.route = PlatformTapRoute(conversationId: "conv-1", messageId: "m-9", seq: 42)
        rig.push.attach(rig.host)
        try await eventually { rig.host.calls.contains(.tap(flarePayload)) }
        XCTAssertFalse(rig.host.calls.contains(.tap(older)))

        var routes = rig.push.routes().makeAsyncIterator()
        let route = await routes.next()
        XCTAssertEqual(route, PlatformTapRoute(conversationId: "conv-1", messageId: "m-9", seq: 42))

        rig.host.route = PlatformTapRoute(conversationId: "conv-2")
        await rig.push.handleTap(flarePayload)
        let next = await routes.next()
        XCTAssertEqual(next, PlatformTapRoute(conversationId: "conv-2"))

        rig.host.route = nil
        await rig.push.handleTap(flarePayload)
        await rig.push.handleTap(["kind": "reminder"])
        rig.push.stop()
        let ended = await routes.next()
        XCTAssertNil(ended, "a tap for another account routes nowhere, and stop ends the stream")
    }

    /// 接着宿主期间，引擎的更正直接落到通知中心：按合并键撤（也按载荷里的合并键找）、写角标、全部撤；
    /// 离开应用时模块不再自己写角标。
    func testCorrectionsFromTheHostReachTheNotificationCenter() async throws {
        let rig = Rig()
        rig.push.attach(rig.host)
        rig.push.start()
        try await eventually { rig.host.correctionStreams == 1 }
        rig.center.delivered = [
            PlatformDeliveredNotification(identifier: "apns-1", collapseId: "c:1"),
            PlatformDeliveredNotification(identifier: "c:2", collapseId: "c:2"),
            PlatformDeliveredNotification(identifier: "reminder", collapseId: nil),
        ]
        rig.center.pending = [PlatformDeliveredNotification(identifier: "c:1", collapseId: "c:1")]

        rig.host.correct(.clear(collapseIds: ["c:1"]))
        try await eventually { rig.center.removed.count == 1 }
        XCTAssertEqual(rig.center.removed, [["apns-1", "c:1"]])
        try await eventually { rig.center.removedPending == [["c:1"]] }

        rig.host.correct(.badge(4))
        try await eventually { rig.center.badges == [4] }

        rig.host.correct(.clearAll)
        try await eventually { rig.center.removed.count == 2 }
        XCTAssertEqual(rig.center.removed[1], ["apns-1", "c:2"], "only the SDK's own notifications")

        rig.appState.emit(.foreground)
        rig.appState.emit(.background)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(rig.center.badges, [4], "leaving the app writes no badge of its own")
        rig.push.stop()
        try await eventually { rig.host.endedCorrectionStreams == 1 }
    }

    /// 换宿主、摘下与登出都结束上一条更正流；结束之后它再报的更正不照办。
    func testCorrectionsEndWithTheHost() async throws {
        let rig = Rig()
        rig.push.start()
        rig.push.attach(rig.host)
        try await eventually { rig.host.correctionStreams == 1 }

        let next = FakeHost()
        rig.push.attach(next)
        try await eventually { rig.host.endedCorrectionStreams == 1 }
        rig.host.correct(.badge(9))
        next.correct(.badge(2))
        try await eventually { rig.center.badges == [2] }

        rig.push.detach()
        try await eventually { next.endedCorrectionStreams == 1 }

        rig.push.attach(next)
        try await eventually { next.correctionStreams == 2 }
        await rig.push.signOut()
        try await eventually { next.endedCorrectionStreams == 2 }
        XCTAssertEqual(rig.center.badges, [2, 0])
        rig.push.stop()
    }

    /// 没 `start()`（不是应用进程）时清通知与写角标都不碰系统通知中心。
    func testCorrectionsNeedAStartedModule() async {
        let rig = Rig()
        await rig.push.clearNotifications(collapseIds: ["c:1"])
        await rig.push.clearAllNotifications()
        await rig.push.setBadge(3)
        XCTAssertTrue(rig.center.removed.isEmpty)
        XCTAssertTrue(rig.center.badges.isEmpty)
    }

    /// 三态权限：没启动时不碰通知中心；启动、申请之后、回到前台都重读，变了才发；新订阅者先拿到当前值。
    func testPermissionIsReadOnStartAfterARequestAndOnForeground() async throws {
        let rig = Rig()
        let beforeStart = await rig.push.permissionStatus()
        XCTAssertNil(beforeStart)
        XCTAssertFalse(rig.push.isStarted)
        let refused = await rig.push.requestAuthorization()
        XCTAssertFalse(refused)
        XCTAssertEqual(rig.center.allowedReads, 0, "nothing touches the notification center before start")
        XCTAssertTrue(rig.center.authorizationRequests.isEmpty)

        var changes = rig.push.permissionChanges().makeAsyncIterator()
        rig.push.start()
        XCTAssertTrue(rig.push.isStarted)
        let first = await changes.next()
        XCTAssertEqual(first, .notDetermined)

        rig.center.grant = false
        _ = await rig.push.requestAuthorization()
        let second = await changes.next()
        XCTAssertEqual(second, .denied)

        rig.center.status = .granted
        rig.appState.emit(.background)
        rig.appState.emit(.foreground)
        let third = await changes.next()
        XCTAssertEqual(third, .granted)
        let current = await rig.push.permissionStatus()
        XCTAssertEqual(current, .granted)

        var late = rig.push.permissionChanges().makeAsyncIterator()
        let replayed = await late.next()
        XCTAssertEqual(replayed, .granted, "a new subscriber starts from the current value")

        rig.push.stop()
        XCTAssertFalse(rig.push.isStarted)
        let ended = await changes.next()
        XCTAssertNil(ended)
    }

    /// 系统的五种授权归成三态：临时授权与短期授权都能收到通知。
    func testTheSystemAuthorizationMapsToThreeStates() {
        XCTAssertEqual(SystemNotificationCenter.permissionStatus(for: .notDetermined), .notDetermined)
        XCTAssertEqual(SystemNotificationCenter.permissionStatus(for: .denied), .denied)
        XCTAssertEqual(SystemNotificationCenter.permissionStatus(for: .authorized), .granted)
        XCTAssertEqual(SystemNotificationCenter.permissionStatus(for: .provisional), .granted)
        #if os(iOS)
        XCTAssertEqual(SystemNotificationCenter.permissionStatus(for: .ephemeral), .granted)
        #endif
    }

    /// 登出：摘下宿主，清掉本 SDK 已展示与等待展示的通知（应用自己的不动），角标归零，留着的点击作废；
    /// 下一个账号接上时令牌重新登记。没启动时不碰通知中心。
    func testSignOutClearsTheAccountsNotificationsAndForgetsIt() async throws {
        let idle = Rig()
        await idle.push.signOut()
        XCTAssertTrue(idle.center.badges.isEmpty)

        let rig = Rig()
        rig.center.allowed = true
        rig.push.didRegisterForRemoteNotifications(deviceToken: Data([0x01]))
        rig.push.attach(rig.host)
        rig.push.start()
        try await eventually { rig.host.tokens.count == 1 }
        rig.push.detach()
        await rig.push.handleTap(flarePayload)
        rig.center.delivered = [
            PlatformDeliveredNotification(identifier: "c:1", collapseId: "c:1"),
            PlatformDeliveredNotification(identifier: "reminder", collapseId: nil),
        ]
        rig.center.pending = [
            PlatformDeliveredNotification(identifier: "c:2", collapseId: "c:2"),
            PlatformDeliveredNotification(identifier: "alarm", collapseId: nil, isFlare: false),
        ]

        await rig.push.signOut()

        XCTAssertEqual(rig.center.removed, [["c:1"]])
        XCTAssertEqual(rig.center.removedPending, [["c:2"]])
        XCTAssertEqual(rig.center.badges, [0])

        let next = FakeHost()
        next.route = PlatformTapRoute(conversationId: "conv-1")
        rig.push.attach(next)
        try await eventually { next.tokens.count == 1 }
        XCTAssertFalse(next.calls.contains(.tap(flarePayload)), "the queued tap belonged to the account that left")
        rig.push.stop()
    }

    /// 应用内的语言替换系统语言，变了立刻重登，不等回到前台；空白回到系统语言。
    func testTheInAppLocaleRegistersTheTokenAgainAtOnce() async throws {
        let rig = Rig()
        rig.center.allowed = true
        rig.push.didRegisterForRemoteNotifications(deviceToken: Data([0xab]))
        rig.push.attach(rig.host)
        rig.push.start()
        try await eventually { rig.host.tokens.count == 1 }
        XCTAssertEqual(rig.host.tokens[0].locale, "zh-Hans-CN")

        rig.push.setLocale("en-US")
        try await eventually { rig.host.tokens.count == 2 }
        XCTAssertEqual(rig.host.tokens[1].locale, "en-US")

        rig.push.setLocale("en-US")
        rig.push.setLocale("  ")
        try await eventually { rig.host.tokens.count == 3 }
        XCTAssertEqual(rig.host.tokens[2].locale, "zh-Hans-CN", "a blank tag goes back to the system language")
        rig.push.stop()
    }

    /// 卡住的宿主拖不住系统回调：远程推送到上限按载荷提示，前台按默认展示，点击按失败处理。
    func testAStuckHostTimesOut() async {
        let rig = Rig(remoteMessageLimitMs: 20, hostCallLimitMs: 20)
        rig.host.hangs = true
        rig.push.attach(rig.host)

        let result = await rig.push.handleRemoteMessage(flarePayload, shownBySystem: false)

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(rig.center.added.map(\.identifier), ["c:1"], "presented from the payload")
        XCTAssertTrue(rig.waits.value.isEmpty)
        let remoteTimeout = String(describing: PlatformPushHostTimeout(call: "handleRemoteMessage", limitMs: 20))
        XCTAssertTrue(rig.errors.value.contains(remoteTimeout))

        let options = await rig.push.presentationOptions(flarePayload, remote: true)
        XCTAssertEqual(options, [.banner, .list, .badge, .sound])

        await rig.push.handleTap(flarePayload)
        let tapTimeout = String(describing: PlatformPushHostTimeout(call: "resolveNotificationTap", limitMs: 20))
        XCTAssertTrue(rig.errors.value.contains(tapTimeout))
    }

    func testTheNotificationSettingsOpenThroughTheApplication() async {
        let rig = Rig()
        let opened = await rig.push.openNotificationSettings()
        XCTAssertTrue(opened)
        XCTAssertEqual(rig.application.settingsOpenings, 1)
    }
}

// MARK: - Fakes

private func eventually(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("condition not met in time")
            return
        }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
}

private final class Rig {
    let host = FakeHost()
    let center = FakeCenter()
    let application = FakeApplication()
    let appState = FakeAppState()
    let device = Locked(PlatformPushDeviceInfo(
        appBundle: "im.flare.app", environment: "sandbox", locale: "zh-Hans-CN", timeZone: "Asia/Shanghai",
        appVersion: "1.2.0"
    ))
    let waits = Locked<[UInt32]>([])
    let errors = Locked<[String]>([])
    let push: PlatformPush

    init(
        remoteMessageLimitMs: UInt32 = PlatformPush.remoteMessageTimeoutMs,
        hostCallLimitMs: UInt32 = PlatformPush.hostCallTimeoutMs
    ) {
        let device = self.device
        let waits = self.waits
        let errors = self.errors
        push = PlatformPush(
            center: center,
            application: application,
            appState: appState,
            deviceInfo: { device.value },
            wait: { milliseconds in waits.value.append(milliseconds) },
            remoteMessageLimitMs: remoteMessageLimitMs,
            hostCallLimitMs: hostCallLimitMs,
            onError: { error in errors.value.append(String(describing: error)) }
        )
    }
}

private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }
}

private final class FakeHost: FlarePushHost, @unchecked Sendable {
    enum Call: Equatable {
        case token(PlatformPushToken)
        case permission(Bool)
        case reconcile
        case remote(String, [String: String], UInt32)
        case tap([String: String])
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    private var storedOutcome = PlatformPushOutcome(action: .ignore)
    private var storedRoute: PlatformTapRoute?
    private var streams: [AsyncStream<PlatformNotificationCorrection>.Continuation] = []
    private var ended = 0
    private var storedFailure: Error?
    private var storedHangs = false

    var calls: [Call] { read { recorded } }
    /// 远程推送与点击一直不答复，直到被取消。
    var hangs: Bool {
        get { read { storedHangs } }
        set { write { storedHangs = newValue } }
    }
    var tokens: [PlatformPushToken] {
        calls.compactMap { call -> PlatformPushToken? in
            if case let .token(token) = call { return token }
            return nil
        }
    }
    var outcome: PlatformPushOutcome {
        get { read { storedOutcome } }
        set { write { storedOutcome = newValue } }
    }
    var route: PlatformTapRoute? {
        get { read { storedRoute } }
        set { write { storedRoute = newValue } }
    }
    /// 模块要过几次更正流。
    var correctionStreams: Int { read { streams.count } }
    /// 其中结束了几条（模块取消了读取）。
    var endedCorrectionStreams: Int { read { ended } }
    var failure: Error? {
        get { read { storedFailure } }
        set { write { storedFailure = newValue } }
    }

    func updatePushToken(_ token: PlatformPushToken) async throws {
        record(.token(token))
    }

    func setPushPermission(allowed: Bool) async throws {
        record(.permission(allowed))
    }

    func reconcilePush() async throws {
        record(.reconcile)
    }

    func handleRemoteMessage(provider: String, payload: [String: String], budgetMs: UInt32) async throws
        -> PlatformPushOutcome {
        record(.remote(provider, payload, budgetMs))
        if hangs { try await Task.sleep(nanoseconds: 10_000_000_000) }
        if let failure { throw failure }
        return outcome
    }

    func resolveNotificationTap(payload: [String: String]) async throws -> PlatformTapRoute? {
        record(.tap(payload))
        if hangs { try await Task.sleep(nanoseconds: 10_000_000_000) }
        return route
    }

    func notificationCorrections() -> AsyncStream<PlatformNotificationCorrection> {
        var captured: AsyncStream<PlatformNotificationCorrection>.Continuation?
        let stream = AsyncStream<PlatformNotificationCorrection> { captured = $0 }
        let continuation = captured!
        continuation.onTermination = { [weak self] _ in self?.markEnded() }
        write { streams.append(continuation) }
        return stream
    }

    /// 像引擎那样报一条更正（只送到还没结束的流）。
    func correct(_ correction: PlatformNotificationCorrection) {
        read { streams }.forEach { $0.yield(correction) }
    }

    private func markEnded() {
        write { ended += 1 }
    }

    private func record(_ call: Call) {
        write { recorded.append(call) }
    }

    private func read<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func write(_ body: () -> Void) {
        lock.lock()
        body()
        lock.unlock()
    }
}

private final class FakeCenter: PlatformNotificationCenter, @unchecked Sendable {
    private let lock = NSLock()
    private weak var storedDelegate: (any UNUserNotificationCenterDelegate)?
    private var state = (
        status: PlatformPushPermissionStatus.notDetermined, grant: false, allowedReads: 0,
        requests: [UNAuthorizationOptions](), added: [PlatformLocalNotification](), removed: [[String]](),
        removedPending: [[String]](), badges: [Int](), delivered: [PlatformDeliveredNotification](),
        pending: [PlatformDeliveredNotification]()
    )

    var delegate: (any UNUserNotificationCenterDelegate)? { read { storedDelegate } }
    var status: PlatformPushPermissionStatus {
        get { read { state.status } }
        set { write { state.status = newValue } }
    }
    /// 允许或拒绝过；还没问过用 `status`。
    var allowed: Bool {
        get { status == .granted }
        set { status = newValue ? .granted : .denied }
    }
    var grant: Bool {
        get { read { state.grant } }
        set { write { state.grant = newValue } }
    }
    var delivered: [PlatformDeliveredNotification] {
        get { read { state.delivered } }
        set { write { state.delivered = newValue } }
    }
    var pending: [PlatformDeliveredNotification] {
        get { read { state.pending } }
        set { write { state.pending = newValue } }
    }
    var allowedReads: Int { read { state.allowedReads } }
    var authorizationRequests: [UNAuthorizationOptions] { read { state.requests } }
    var added: [PlatformLocalNotification] { read { state.added } }
    var removed: [[String]] { read { state.removed } }
    var removedPending: [[String]] { read { state.removedPending } }
    var badges: [Int] { read { state.badges } }

    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) {
        write { storedDelegate = delegate }
    }

    func removeDelegate(_ delegate: any UNUserNotificationCenterDelegate) {
        write {
            if storedDelegate === delegate { storedDelegate = nil }
        }
    }

    func permissionStatus() async -> PlatformPushPermissionStatus {
        read {
            state.allowedReads += 1
            return state.status
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        read {
            state.requests.append(options)
            state.status = state.grant ? .granted : .denied
            return state.grant
        }
    }

    func add(_ notification: PlatformLocalNotification) async throws {
        write { state.added.append(notification) }
    }

    func deliveredNotifications() async -> [PlatformDeliveredNotification] {
        delivered
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        write { state.removed.append(identifiers) }
    }

    func pendingNotifications() async -> [PlatformDeliveredNotification] {
        pending
    }

    func removePendingNotifications(withIdentifiers identifiers: [String]) {
        write { state.removedPending.append(identifiers) }
    }

    func setBadge(_ count: Int) async throws {
        write { state.badges.append(count) }
    }

    private func read<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func write(_ body: () -> Void) {
        lock.lock()
        body()
        lock.unlock()
    }
}

private final class FakeApplication: PlatformPushApplication, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var openings = 0

    var registrations: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    var settingsOpenings: Int {
        lock.lock()
        defer { lock.unlock() }
        return openings
    }

    func registerForRemoteNotifications() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    func openNotificationSettings() async -> Bool {
        recordOpening()
        return true
    }

    private func recordOpening() {
        lock.lock()
        openings += 1
        lock.unlock()
    }
}

private final class FakeAppState: PlatformAppStateSource, @unchecked Sendable {
    private let lock = NSLock()
    private var onChange: (@Sendable (PlatformAppState) -> Void)?
    private var didStop = false

    var stopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didStop
    }

    func start(_ onChange: @escaping @Sendable (PlatformAppState) -> Void) {
        lock.lock()
        self.onChange = onChange
        lock.unlock()
    }

    func stop() {
        lock.lock()
        didStop = true
        onChange = nil
        lock.unlock()
    }

    func emit(_ state: PlatformAppState) {
        lock.lock()
        let onChange = self.onChange
        lock.unlock()
        onChange?(state)
    }
}
