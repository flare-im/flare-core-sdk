import UserNotifications
import XCTest
import FlarePlatformLifecycle
@testable import FlarePlatformPush

/// 配置打开的两样：App Group 里的通知快照目录与 `serviceExtension` 能力，`BGAppRefreshTask` 的登记、排期与运行。
final class PlatformPushExtensionTests: XCTestCase {
    private var container: URL!

    override func setUpWithError() throws {
        container = FileManager.default.temporaryDirectory
            .appendingPathComponent("flare-group-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: container)
    }

    private func makeRig(
        configuration: PlatformPushConfiguration,
        containerAvailable: Bool = true,
        hostWaitLimitMs: UInt32 = 2_000
    ) -> ExtensionRig {
        ExtensionRig(
            configuration: configuration,
            container: containerAvailable ? container : nil,
            hostWaitLimitMs: hostWaitLimitMs
        )
    }

    func testAnAppGroupHandsTheSnapshotDirectoryToTheHost() async throws {
        let rig = makeRig(configuration: PlatformPushConfiguration(appGroupIdentifier: "group.im.flare.app"))
        rig.push.attach(rig.host)

        let expected = container.appendingPathComponent("flare-notify", isDirectory: true).path
        try await eventually { rig.host.directories == [expected] }
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(rig.groups.value, ["group.im.flare.app"])
    }

    func testWithoutAnAppGroupTheHostHearsNothing() async throws {
        let rig = makeRig(configuration: PlatformPushConfiguration(hasNotificationServiceExtension: true))
        rig.push.attach(rig.host)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(rig.host.directories.isEmpty)
        XCTAssertTrue(rig.groups.value.isEmpty)
    }

    func testTheServiceExtensionCapabilityNeedsTheFlagAndAUsableAppGroup() async throws {
        let declared = makeRig(configuration: PlatformPushConfiguration(
            appGroupIdentifier: "group.im.flare.app", hasNotificationServiceExtension: true
        ))
        try await registerToken(declared)
        XCTAssertEqual(declared.host.tokens.first?.capabilities, [PlatformPushToken.serviceExtensionCapability])

        let undeclared = makeRig(configuration: PlatformPushConfiguration(appGroupIdentifier: "group.im.flare.app"))
        try await registerToken(undeclared)
        XCTAssertEqual(undeclared.host.tokens.first?.capabilities, [], "an app group alone is not an extension")

        let unentitled = makeRig(
            configuration: PlatformPushConfiguration(
                appGroupIdentifier: "group.im.flare.app", hasNotificationServiceExtension: true
            ),
            containerAvailable: false
        )
        try await registerToken(unentitled)
        XCTAssertEqual(unentitled.host.tokens.first?.capabilities, [], "no container, no snapshot to read")
        XCTAssertTrue(unentitled.errors.value.contains(
            String(describing: PlatformPushConfigurationError.appGroupUnavailable("group.im.flare.app"))
        ))
    }

    private func registerToken(_ rig: ExtensionRig) async throws {
        rig.center.status = .granted
        rig.push.attach(rig.host)
        rig.push.start()
        rig.push.didRegisterForRemoteNotifications(deviceToken: Data([0xab, 0xcd]))
        try await eventually { rig.host.tokens.count == 1 }
        rig.push.stop()
    }

    func testTheRefreshTaskIsRegisteredAtStartAndScheduledWhenALoggedInAppGoesToTheBackground() async throws {
        let rig = makeRig(configuration: PlatformPushConfiguration(backgroundRefreshTaskIdentifier: "im.flare.app.refresh"))
        rig.push.start()
        XCTAssertEqual(rig.scheduler.registered, ["im.flare.app.refresh"], "registered before start returns")

        rig.appState.emit(.foreground)
        rig.appState.emit(.background)
        XCTAssertTrue(rig.scheduler.schedules.isEmpty, "nothing to refresh without a session")

        rig.push.attach(rig.host)
        rig.appState.emit(.foreground)
        let before = Date()
        rig.appState.emit(.background)
        let schedule = try XCTUnwrap(rig.scheduler.schedules.last)
        XCTAssertEqual(schedule.identifier, "im.flare.app.refresh")
        XCTAssertGreaterThanOrEqual(
            schedule.earliest.timeIntervalSince(before), PlatformPush.backgroundRefreshInterval - 1
        )

        await rig.push.signOut()
        XCTAssertEqual(rig.scheduler.cancelled, ["im.flare.app.refresh"])
        rig.push.stop()
    }

    func testAnIdentifierThatIsNotPermittedIsReported() {
        let rig = makeRig(configuration: PlatformPushConfiguration(backgroundRefreshTaskIdentifier: "im.flare.app.refresh"))
        rig.scheduler.permitted = false
        rig.push.start()
        XCTAssertEqual(rig.errors.value, [
            String(describing: PlatformPushConfigurationError.backgroundRefreshNotPermitted("im.flare.app.refresh")),
        ])
        rig.push.stop()
    }

    func testARefreshRunsOnTheHostCompletesWithItsResultAndReschedules() async throws {
        let rig = makeRig(configuration: PlatformPushConfiguration(backgroundRefreshTaskIdentifier: "im.flare.app.refresh"))
        rig.host.refreshResult = true
        rig.push.start()
        rig.push.attach(rig.host)

        let task = FakeRefreshTask()
        rig.scheduler.launch(task)

        try await eventually { task.completions == [true] }
        XCTAssertEqual(rig.host.refreshBudgets, [PlatformPush.backgroundRefreshBudgetMs])
        XCTAssertEqual(rig.scheduler.schedules.count, 1, "the next refresh is queued")

        let unfinished = FakeRefreshTask()
        rig.host.refreshResult = false
        rig.scheduler.launch(unfinished)
        try await eventually { unfinished.completions == [false] }
        rig.push.stop()
    }

    func testAColdStartWaitsForTheSessionThenGivesUp() async throws {
        let rig = makeRig(
            configuration: PlatformPushConfiguration(backgroundRefreshTaskIdentifier: "im.flare.app.refresh"),
            hostWaitLimitMs: 2_000
        )
        rig.host.refreshResult = true
        rig.push.start()

        let restored = FakeRefreshTask()
        rig.scheduler.launch(restored)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(rig.host.refreshBudgets.isEmpty, "still waiting for the session")
        rig.push.attach(rig.host)
        try await eventually { restored.completions == [true] }

        let quick = makeRig(
            configuration: PlatformPushConfiguration(backgroundRefreshTaskIdentifier: "im.flare.app.refresh"),
            hostWaitLimitMs: 20
        )
        quick.push.start()
        let abandoned = FakeRefreshTask()
        quick.scheduler.launch(abandoned)
        try await eventually { abandoned.completions == [false] }
        XCTAssertTrue(quick.scheduler.schedules.isEmpty, "no session, no next refresh")
        rig.push.stop()
        quick.push.stop()
    }

    func testExpiryCompletesTheTaskAsUnfinished() async throws {
        let rig = makeRig(configuration: PlatformPushConfiguration(backgroundRefreshTaskIdentifier: "im.flare.app.refresh"))
        rig.host.refreshHangs = true
        rig.push.start()
        rig.push.attach(rig.host)

        let task = FakeRefreshTask()
        rig.scheduler.launch(task)
        try await eventually { rig.host.refreshBudgets.count == 1 }
        task.expire()

        XCTAssertEqual(task.completions, [false])
        rig.push.stop()
    }
}

private func eventually(timeout: TimeInterval = 3, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("condition not met in time")
            return
        }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
}

private final class ExtensionRig {
    let host = ExtensionHost()
    let center = MinimalCenter()
    let application = MinimalApplication()
    let appState = MinimalAppState()
    let scheduler = FakeScheduler()
    let groups = Guarded<[String]>([])
    let errors = Guarded<[String]>([])
    let push: PlatformPush

    init(configuration: PlatformPushConfiguration, container: URL?, hostWaitLimitMs: UInt32) {
        let groups = self.groups
        let errors = self.errors
        push = PlatformPush(
            center: center,
            application: application,
            appState: appState,
            deviceInfo: { PlatformPushDeviceInfo(appBundle: "im.flare.app", environment: "sandbox", locale: "en") },
            wait: { _ in },
            configuration: configuration,
            backgroundRefresh: scheduler,
            appGroupContainer: { group in
                groups.value.append(group)
                return container
            },
            hostWaitLimitMs: hostWaitLimitMs,
            onError: { error in errors.value.append(String(describing: error)) }
        )
    }
}

private final class Guarded<Value>: @unchecked Sendable {
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

private final class ExtensionHost: FlarePushHost, @unchecked Sendable {
    private let state = Guarded((
        tokens: [PlatformPushToken](), directories: [String?](), budgets: [Int](), result: false, hangs: false
    ))

    var tokens: [PlatformPushToken] { state.value.tokens }
    var directories: [String?] { state.value.directories }
    var refreshBudgets: [Int] { state.value.budgets }
    var refreshResult: Bool {
        get { state.value.result }
        set { state.value.result = newValue }
    }
    /// 后台刷新一直不答复，直到系统收回时间。
    var refreshHangs: Bool {
        get { state.value.hangs }
        set { state.value.hangs = newValue }
    }

    func updatePushToken(_ token: PlatformPushToken) async throws {
        state.value.tokens.append(token)
    }

    func setPushPermission(allowed: Bool) async throws {}

    func reconcilePush() async throws {}

    func handleRemoteMessage(provider: String, payload: [String: String], budgetMs: UInt32) async throws
        -> PlatformPushOutcome {
        PlatformPushOutcome(action: .ignore)
    }

    func resolveNotificationTap(payload: [String: String]) async throws -> PlatformTapRoute? {
        nil
    }

    func notificationCorrections() -> AsyncStream<PlatformNotificationCorrection> {
        AsyncStream { $0.finish() }
    }

    func setNotificationSnapshotDirectory(_ path: String?) async {
        state.value.directories.append(path)
    }

    func backgroundRefresh(budgetMs: Int) async -> Bool {
        state.value.budgets.append(budgetMs)
        if refreshHangs {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        return refreshResult
    }
}

private final class FakeScheduler: PlatformBackgroundRefreshScheduler, @unchecked Sendable {
    struct Schedule {
        let identifier: String
        let earliest: Date
    }

    typealias LaunchHandler = @Sendable (any PlatformBackgroundRefreshTask) -> Void

    private let state = Guarded((
        permitted: true, registered: [String](), schedules: [Schedule](), cancelled: [String]()
    ))
    private let handler = Guarded<LaunchHandler?>(nil)

    var permitted: Bool {
        get { state.value.permitted }
        set { state.value.permitted = newValue }
    }
    var registered: [String] { state.value.registered }
    var schedules: [Schedule] { state.value.schedules }
    var cancelled: [String] { state.value.cancelled }

    func register(
        identifier: String,
        launchHandler: @escaping @Sendable (any PlatformBackgroundRefreshTask) -> Void
    ) throws {
        guard permitted else { throw PlatformPushConfigurationError.backgroundRefreshNotPermitted(identifier) }
        state.value.registered.append(identifier)
        handler.value = launchHandler
    }

    func schedule(identifier: String, earliest: Date) throws {
        state.value.schedules.append(Schedule(identifier: identifier, earliest: earliest))
    }

    func cancel(identifier: String) {
        state.value.cancelled.append(identifier)
    }

    /// 像系统那样交来一次后台刷新。
    func launch(_ task: any PlatformBackgroundRefreshTask) {
        handler.value?(task)
    }
}

private final class FakeRefreshTask: PlatformBackgroundRefreshTask, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Bool] = []
    private var expiration: (@Sendable () -> Void)?

    var completions: [Bool] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func setExpirationHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        expiration = handler
        lock.unlock()
    }

    /// 和系统的任务一样，只有第一次完成算数。
    func complete(success: Bool) {
        lock.lock()
        if recorded.isEmpty {
            recorded.append(success)
        }
        lock.unlock()
    }

    func expire() {
        lock.lock()
        let handler = expiration
        lock.unlock()
        handler?()
    }
}

private final class MinimalCenter: PlatformNotificationCenter, @unchecked Sendable {
    private let stored = Guarded(PlatformPushPermissionStatus.denied)

    var status: PlatformPushPermissionStatus {
        get { stored.value }
        set { stored.value = newValue }
    }

    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) {}
    func removeDelegate(_ delegate: any UNUserNotificationCenterDelegate) {}
    func permissionStatus() async -> PlatformPushPermissionStatus { status }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
    func add(_ notification: PlatformLocalNotification) async throws {}
    func deliveredNotifications() async -> [PlatformDeliveredNotification] { [] }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
    func pendingNotifications() async -> [PlatformDeliveredNotification] { [] }
    func removePendingNotifications(withIdentifiers identifiers: [String]) {}
    func setBadge(_ count: Int) async throws {}
}

private final class MinimalApplication: PlatformPushApplication, @unchecked Sendable {
    func registerForRemoteNotifications() {}
    func openNotificationSettings() async -> Bool { false }
}

private final class MinimalAppState: PlatformAppStateSource, @unchecked Sendable {
    private let stored = Guarded<(@Sendable (PlatformAppState) -> Void)?>(nil)

    func start(_ onChange: @escaping @Sendable (PlatformAppState) -> Void) {
        stored.value = onChange
    }

    func stop() {
        stored.value = nil
    }

    func emit(_ state: PlatformAppState) {
        stored.value?(state)
    }
}
