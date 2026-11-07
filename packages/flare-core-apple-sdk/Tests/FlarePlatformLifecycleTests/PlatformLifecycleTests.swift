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

    /// The fingerprint hint is a gateway prefix: IPv4 /24 first, else a global IPv6 /64.
    func testGatewayPrefix() {
        func gateway(_ host: String) -> NWEndpoint {
            .hostPort(host: NWEndpoint.Host(host), port: 0)
        }
        XCTAssertEqual(SystemNetworkSource.gatewayPrefix([gateway("192.168.31.1")]), "192.168.31.0/24")
        XCTAssertEqual(
            SystemNetworkSource.gatewayPrefix([gateway("fe80::1"), gateway("2001:db8:a:b::1"), gateway("10.0.0.1")]),
            "10.0.0.0/24"
        )
        XCTAssertEqual(SystemNetworkSource.gatewayPrefix([gateway("2001:db8:a:b::1")]), "2001:db8:a:b::/64")
        XCTAssertNil(SystemNetworkSource.gatewayPrefix([gateway("fe80::1")]), "link-local says nothing about the network")
        XCTAssertNil(SystemNetworkSource.gatewayPrefix([]))
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
