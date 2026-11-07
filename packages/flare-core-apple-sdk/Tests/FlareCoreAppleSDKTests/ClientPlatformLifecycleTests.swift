import XCTest
@testable import FlareCoreAppleSDK

/// The core client's use of the FlarePlatformLifecycle product.
final class ClientPlatformLifecycleTests: XCTestCase {
    /// Reports reach the core as `connection.notify_network_change` and `lifecycle.set_app_state`
    /// with the wire values.
    func testReportsReachTheCoreOnTheWire() async throws {
        let bridge = LifecycleRecordingBridge()
        let network = CoreFakeNetworkSource(initial: PlatformNetworkState(
            available: true, interface: .wifi, expensive: false, metered: true, fingerprintHint: "192.168.1.0/24"
        ))
        let appState = CoreFakeAppStateSource(initial: .background)
        let lifecycle = PlatformLifecycle(
            connection: DefaultConnectionApi(bridge: bridge),
            lifecycle: DefaultLifecycleApi(bridge: bridge),
            network: network,
            appState: appState
        ).install()

        try await bridge.waitForCalls(2)
        lifecycle.dispose()

        let networkCall = try XCTUnwrap(bridge.calls.first { $0.operation == "connection.notify_network_change" })
        XCTAssertEqual(networkCall.request["available"] as? Bool, true)
        XCTAssertEqual(networkCall.request["interface"] as? String, "wifi")
        XCTAssertEqual(networkCall.request["metered"] as? Bool, true)
        XCTAssertEqual(networkCall.request["fingerprintHint"] as? String, "192.168.1.0/24")
        XCTAssertEqual(networkCall.request["reason"] as? String, "initial")
        let appCall = try XCTUnwrap(bridge.calls.first { $0.operation == "lifecycle.set_app_state" })
        XCTAssertEqual(appCall.request["appState"] as? String, "background")
    }

    /// The client installs the lifecycle after init succeeds and removes it on dispose; the
    /// switch is read by the client and never sent to the core.
    func testClientInstallsAfterInitAndDisposeRemovesIt() async throws {
        let bridge = LifecycleRecordingBridge()
        let built = BuiltLifecycles()
        let client = DefaultFlareImClient(bridge: bridge) { connection, lifecycle in
            built.make(connection: connection, lifecycle: lifecycle)
        }

        try await client.`init`(["tenantId": AnySendable("0")])
        XCTAssertEqual(built.count, 1)
        XCTAssertEqual(built.last?.starts, 1)
        XCTAssertFalse(built.last?.stopped ?? true)

        try await client.dispose()
        XCTAssertTrue(built.last?.stopped ?? false)
    }

    /// A second init replaces the installed lifecycle.
    func testASecondInitReplacesTheLifecycle() async throws {
        let bridge = LifecycleRecordingBridge()
        let built = BuiltLifecycles()
        let client = DefaultFlareImClient(bridge: bridge) { connection, lifecycle in
            built.make(connection: connection, lifecycle: lifecycle)
        }

        try await client.`init`(["tenantId": AnySendable("0")])
        let first = built.last
        try await client.`init`(["tenantId": AnySendable("0")])

        XCTAssertEqual(built.count, 2)
        XCTAssertTrue(first?.stopped ?? false)
        XCTAssertFalse(built.last?.stopped ?? true)
        try await client.dispose()
    }

    func testInstallPlatformLifecycleFalseLeavesItOut() async throws {
        let bridge = LifecycleRecordingBridge()
        let built = BuiltLifecycles()
        let client = DefaultFlareImClient(bridge: bridge) { connection, lifecycle in
            built.make(connection: connection, lifecycle: lifecycle)
        }

        try await client.`init`(["tenantId": AnySendable("0"), "installPlatformLifecycle": AnySendable(false)])

        XCTAssertEqual(built.count, 0)
        let initCall = try XCTUnwrap(bridge.calls.first { $0.operation == "sdk.init" })
        XCTAssertNil(initCall.request["installPlatformLifecycle"])
        XCTAssertEqual(initCall.request["tenantId"] as? String, "0")
    }

    /// A failed init installs nothing.
    func testAFailedInitInstallsNothing() async throws {
        let bridge = LifecycleRecordingBridge(failFirst: true)
        let built = BuiltLifecycles()
        let client = DefaultFlareImClient(bridge: bridge) { connection, lifecycle in
            built.make(connection: connection, lifecycle: lifecycle)
        }

        do {
            try await client.`init`(["tenantId": AnySendable("0")])
            XCTFail("init should fail")
        } catch {}
        XCTAssertEqual(built.count, 0)
    }
}

private final class CoreFakeNetworkSource: PlatformNetworkSource, @unchecked Sendable {
    private let initial: PlatformNetworkState?
    private(set) var starts = 0
    private(set) var stopped = false

    init(initial: PlatformNetworkState?) {
        self.initial = initial
    }

    func start(_ onChange: @escaping @Sendable (PlatformNetworkState) -> Void) {
        starts += 1
        if let initial { onChange(initial) }
    }

    func stop() {
        stopped = true
    }
}

private final class CoreFakeAppStateSource: PlatformAppStateSource, @unchecked Sendable {
    private let initial: PlatformAppState?

    init(initial: PlatformAppState?) {
        self.initial = initial
    }

    func start(_ onChange: @escaping @Sendable (PlatformAppState) -> Void) {
        if let initial { onChange(initial) }
    }

    func stop() {}
}

private final class BuiltLifecycles: @unchecked Sendable {
    private let lock = NSLock()
    private var networks: [CoreFakeNetworkSource] = []

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return networks.count
    }

    var last: CoreFakeNetworkSource? {
        lock.lock()
        defer { lock.unlock() }
        return networks.last
    }

    func make(connection: any ConnectionApiProtocol, lifecycle: any LifecycleApiProtocol) -> PlatformLifecycle {
        let network = CoreFakeNetworkSource(initial: nil)
        lock.lock()
        networks.append(network)
        lock.unlock()
        return PlatformLifecycle(
            connection: connection,
            lifecycle: lifecycle,
            network: network,
            appState: CoreFakeAppStateSource(initial: nil)
        )
    }
}

/// Records every bridge call with its request as plain values.
final class LifecycleRecordingBridge: NativeBridgeProtocol, @unchecked Sendable {
    struct Call {
        let operation: String
        let request: [String: Any]
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    private var failNext: Bool

    init(failFirst: Bool = false) {
        failNext = failFirst
    }

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        if record(Call(operation: descriptor.operation, request: FfiJson.asMap(request))) {
            throw FlareSdkException(code: "NOT_CONNECTED", message: "rejected", operation: descriptor.operation)
        }
        return AnySendable([String: AnySendable]())
    }

    /// Records the call; true when it is the one to fail.
    private func record(_ call: Call) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(call)
        let fail = failNext
        failNext = false
        return fail
    }

    func waitForCalls(_ count: Int, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while calls.count < count {
            if Date() > deadline {
                XCTFail("expected \(count) bridge calls, got \(calls.count)")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
