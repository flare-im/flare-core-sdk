import Network
import XCTest
@testable import FlarePlatformLifecycle

final class PlatformLifecycleTests: XCTestCase {
    /// Install reports the current network and app state once; repeats are dropped, changes go
    /// out in order.
    func testReportsTheCurrentStateFirstAndDropsRepeats() async throws {
        let reports = Reports()
        let wifi = PlatformNetworkState(
            available: true, interface: .wifi, expensive: false, metered: false, fingerprintHint: "192.168.1.0/24"
        )
        let network = FakeNetworkSource(initial: wifi)
        let appState = FakeAppStateSource(initial: .foreground)
        let lifecycle = PlatformLifecycle(
            notifyNetworkChange: { reports.add(.network($0, $1)) },
            setAppState: { reports.add(.appState($0)) },
            network: network,
            appState: appState
        ).install()

        try await reports.wait(for: 2)
        network.emit(wifi)
        appState.emit(.foreground)
        network.emit(PlatformNetworkState(available: true, interface: .cellular, expensive: true, metered: false))
        appState.emit(.background)
        network.emit(PlatformNetworkState(available: false))
        try await reports.wait(for: 5)
        lifecycle.dispose()

        let networkReports = reports.all.compactMap { report -> (PlatformNetworkState, String)? in
            if case let .network(state, reason) = report { return (state, reason) }
            return nil
        }
        let appReports = reports.all.compactMap { report -> PlatformAppState? in
            if case let .appState(state) = report { return state }
            return nil
        }
        XCTAssertEqual(networkReports.map(\.0), [
            wifi,
            PlatformNetworkState(available: true, interface: .cellular, expensive: true, metered: false),
            PlatformNetworkState(available: false),
        ])
        XCTAssertEqual(networkReports.map(\.1), ["initial", "path_change", "path_change"])
        XCTAssertEqual(appReports, [.foreground, .background])
    }

    /// After dispose the sources are stopped and nothing more is reported.
    func testDisposeStopsReporting() async throws {
        let reports = Reports()
        let network = FakeNetworkSource(initial: PlatformNetworkState(available: true, interface: .ethernet))
        let appState = FakeAppStateSource(initial: nil)
        let lifecycle = PlatformLifecycle(
            notifyNetworkChange: { reports.add(.network($0, $1)) },
            setAppState: { reports.add(.appState($0)) },
            network: network,
            appState: appState
        ).install()
        try await reports.wait(for: 1)

        lifecycle.dispose()
        XCTAssertTrue(network.stopped)
        XCTAssertTrue(appState.stopped)
        network.emit(PlatformNetworkState(available: false))
        appState.emit(.background)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(reports.all.count, 1)
    }

    /// A failed report goes to `onError`; the next still goes out.
    func testAFailedReportDoesNotStopTheNext() async throws {
        let reports = Reports()
        let errors = Reports()
        let lifecycle = PlatformLifecycle(
            notifyNetworkChange: { _, _ in throw URLError(.notConnectedToInternet) },
            setAppState: { reports.add(.appState($0)) },
            network: FakeNetworkSource(initial: PlatformNetworkState(available: true, interface: .wifi)),
            appState: FakeAppStateSource(initial: .foreground),
            onError: { _ in errors.add(.failed) }
        ).install()
        try await reports.wait(for: 1)
        try await errors.wait(for: 1)
        lifecycle.dispose()
        XCTAssertEqual(errors.all.count, 1)
    }

    /// Installing twice starts the sources once.
    func testInstallIsIdempotent() async throws {
        let reports = Reports()
        let network = FakeNetworkSource(initial: PlatformNetworkState(available: true, interface: .wifi))
        let lifecycle = PlatformLifecycle(
            notifyNetworkChange: { reports.add(.network($0, $1)) },
            setAppState: { reports.add(.appState($0)) },
            network: network,
            appState: FakeAppStateSource(initial: nil)
        )
        lifecycle.install()
        lifecycle.install()
        try await reports.wait(for: 1)
        lifecycle.dispose()
        XCTAssertEqual(network.starts, 1)
    }

    /// 进后台：后台执行在通知回调里同步申请，上报返回后才结束；重复的后台不再上报，申请的也随即结束。
    func testBackgroundHoldsATaskUntilTheReportReturns() async throws {
        let reports = Reports()
        let gate = Gate()
        let background = FakeBackgroundExecution()
        let appState = FakeAppStateSource(initial: .foreground)
        let lifecycle = PlatformLifecycle(
            notifyNetworkChange: { _, _ in },
            setAppState: { state in
                if state == .background { await gate.wait() }
                reports.add(.appState(state))
            },
            network: FakeNetworkSource(initial: nil),
            appState: appState,
            backgroundExecution: background
        ).install()
        try await reports.wait(for: 1)
        XCTAssertTrue(background.tasks.isEmpty, "the foreground holds nothing")

        appState.emit(.background)
        XCTAssertEqual(background.tasks.count, 1, "begun inside the notification handler")
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(background.tasks[0].ended, "held while the report runs")

        gate.open()
        try await reports.wait(for: 2)
        try await waitUntil { background.tasks[0].ended }

        appState.emit(.background)
        try await waitUntil { background.tasks.count == 2 && background.tasks[1].ended }
        XCTAssertEqual(reports.all.count, 2)
        XCTAssertEqual(background.names, ["im.flare.sdk.app-state", "im.flare.sdk.app-state"])
        lifecycle.dispose()
    }

    /// 释放时，还在跑或还在排队的上报带着的后台执行一并结束。
    func testDisposeEndsTheHeldTasks() async throws {
        let gate = Gate()
        let background = FakeBackgroundExecution()
        let appState = FakeAppStateSource(initial: nil)
        let lifecycle = PlatformLifecycle(
            notifyNetworkChange: { _, _ in },
            setAppState: { _ in await gate.wait() },
            network: FakeNetworkSource(initial: nil),
            appState: appState,
            backgroundExecution: background
        ).install()

        appState.emit(.background)
        appState.emit(.foreground)
        appState.emit(.background)
        XCTAssertEqual(background.tasks.count, 2)
        lifecycle.dispose()

        XCTAssertTrue(background.tasks.allSatisfy(\.ended))
        appState.emit(.background)
        XCTAssertEqual(background.tasks.count, 3)
        XCTAssertTrue(background.tasks[2].ended, "a signal after dispose ends its task at once")
        gate.open()
    }

    /// The gateway the fingerprint is taken from: IPv4 first, else a global IPv6 /64, else the
    /// router's link-local address.
    func testGatewayIdentity() {
        func gateway(_ host: String) -> NWEndpoint {
            .hostPort(host: NWEndpoint.Host(host), port: 0)
        }
        XCTAssertEqual(SystemNetworkSource.gatewayIdentity([gateway("192.168.31.1")]), "4:192.168.31.1")
        XCTAssertEqual(
            SystemNetworkSource.gatewayIdentity([gateway("fe80::1"), gateway("2001:db8:a:b::1"), gateway("10.0.0.1")]),
            "4:10.0.0.1"
        )
        XCTAssertEqual(
            SystemNetworkSource.gatewayIdentity([gateway("fe80::1"), gateway("2001:db8:a:b::1")]),
            "6g:20010db8000a000b"
        )
        XCTAssertEqual(
            SystemNetworkSource.gatewayIdentity([gateway("fe80::1:2")]),
            "6l:fe800000000000000000000000010002"
        )
        XCTAssertNil(SystemNetworkSource.gatewayIdentity([gateway("::1")]))
        XCTAssertNil(SystemNetworkSource.gatewayIdentity([]))
    }

    /// The hint is a hash: it tells networks apart, never carries an address, and is the same each
    /// time the device joins the same network.
    func testTheFingerprintHintIsAHashOfInterfaceAndGateway() throws {
        func gateway(_ host: String) -> NWEndpoint {
            .hostPort(host: NWEndpoint.Host(host), port: 0)
        }
        let home = try XCTUnwrap(SystemNetworkSource.gatewayFingerprint(kind: .wifi, gateways: [gateway("192.168.31.1")]))
        XCTAssertEqual(home.count, 16)
        XCTAssertTrue(home.allSatisfy(\.isHexDigit), "no dots, colons or prefix lengths of an address")
        XCTAssertEqual(SystemNetworkSource.gatewayFingerprint(kind: .wifi, gateways: [gateway("192.168.31.1")]), home)
        XCTAssertNotEqual(SystemNetworkSource.gatewayFingerprint(kind: .wifi, gateways: [gateway("192.168.1.1")]), home)
        XCTAssertNotEqual(
            SystemNetworkSource.gatewayFingerprint(kind: .ethernet, gateways: [gateway("192.168.31.1")]), home
        )
        XCTAssertNil(SystemNetworkSource.gatewayFingerprint(kind: .wifi, gateways: []))
    }

    /// Fixed vectors of the hint. The Flutter lifecycle plugin's iOS and macOS side
    /// (`FlareNetworkReading.gatewayFingerprint`) computes them the same way: both report the same hint
    /// for the same network.
    func testTheFingerprintHintMatchesTheSharedVectors() {
        func gateway(_ host: String) -> NWEndpoint {
            .hostPort(host: NWEndpoint.Host(host), port: 0)
        }
        XCTAssertEqual(
            SystemNetworkSource.gatewayFingerprint(kind: .wifi, gateways: [gateway("192.168.31.1")]),
            "e29489e6840fedc1"
        )
        XCTAssertEqual(
            SystemNetworkSource.gatewayFingerprint(kind: .ethernet, gateways: [gateway("192.168.31.1")]),
            "234ad802cd784800"
        )
        XCTAssertEqual(
            SystemNetworkSource.gatewayFingerprint(kind: .wifi, gateways: [gateway("fe80::1:2")]),
            "d2745eb21b4dee93"
        )
    }
}

private enum Report: Sendable {
    case network(PlatformNetworkState, String)
    case appState(PlatformAppState)
    case failed
}

private final class Reports: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Report] = []

    var all: [Report] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func add(_ report: Report) {
        lock.lock()
        recorded.append(report)
        lock.unlock()
    }

    func wait(for count: Int, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while all.count < count {
            if Date() > deadline {
                XCTFail("expected \(count) reports, got \(all.count)")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("condition not met in time")
            return
        }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
}

/// 打开之前一直等着的上报。
private final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false

    func open() {
        lock.lock()
        opened = true
        lock.unlock()
    }

    func wait() async {
        while true {
            lock.lock()
            let opened = self.opened
            lock.unlock()
            if opened || Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

final class FakeBackgroundExecution: PlatformBackgroundExecution, @unchecked Sendable {
    private let lock = NSLock()
    private var begun: [(String, PlatformBackgroundTask)] = []

    var tasks: [PlatformBackgroundTask] {
        lock.lock()
        defer { lock.unlock() }
        return begun.map(\.1)
    }

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }
        return begun.map(\.0)
    }

    func begin(name: String) -> PlatformBackgroundTask? {
        let task = PlatformBackgroundTask(release: {})
        lock.lock()
        begun.append((name, task))
        lock.unlock()
        return task
    }
}

final class FakeNetworkSource: PlatformNetworkSource, @unchecked Sendable {
    private let initial: PlatformNetworkState?
    private var onChange: (@Sendable (PlatformNetworkState) -> Void)?
    private(set) var starts = 0
    private(set) var stopped = false

    init(initial: PlatformNetworkState?) {
        self.initial = initial
    }

    func start(_ onChange: @escaping @Sendable (PlatformNetworkState) -> Void) {
        starts += 1
        self.onChange = onChange
        if let initial { onChange(initial) }
    }

    func stop() {
        stopped = true
    }

    func emit(_ state: PlatformNetworkState) {
        onChange?(state)
    }
}

final class FakeAppStateSource: PlatformAppStateSource, @unchecked Sendable {
    private let initial: PlatformAppState?
    private var onChange: (@Sendable (PlatformAppState) -> Void)?
    private(set) var stopped = false

    init(initial: PlatformAppState?) {
        self.initial = initial
    }

    func start(_ onChange: @escaping @Sendable (PlatformAppState) -> Void) {
        self.onChange = onChange
        if let initial { onChange(initial) }
    }

    func stop() {
        stopped = true
    }

    func emit(_ state: PlatformAppState) {
        onChange?(state)
    }
}
