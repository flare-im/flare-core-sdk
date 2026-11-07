import XCTest
@testable import FlareCoreAppleSDK

final class ConnectionContractTests: XCTestCase {
    // MARK: - connection://status and access events

    /// The C ABI event: every field present, null without a value, plus `type` / `event`.
    func testConnectionStatusEventDecodesWithNulls() async throws {
        let (bridge, events) = try await subscribedEvents()
        let box = EventBox<ConnectionStatus>()
        _ = events.onConnectionStatusChanged { box.value = $0 }

        bridge.emit(eventType: EventCode.connectionStatus, json: """
        {"type":"connection","event":"status","phase":"reconnecting","quality":null,"accessPointId":"ap-sg-1",
         "cellId":"cell-sg-a","regionId":"sg","protocol":"quic","rttMs":null,"attempt":2,
         "nextRetryAt":1762250000000,"reason":null,"developmentMode":false}
        """)

        let status = try XCTUnwrap(box.value)
        XCTAssertEqual(status.phase, .reconnecting)
        XCTAssertNil(status.quality)
        XCTAssertEqual(status.accessPointId, "ap-sg-1")
        XCTAssertEqual(status.cellId, "cell-sg-a")
        XCTAssertEqual(status.regionId, "sg")
        XCTAssertEqual(status.protocol, "quic")
        XCTAssertNil(status.rttMs)
        XCTAssertEqual(status.attempt, 2)
        XCTAssertEqual(status.nextRetryAt, 1_762_250_000_000)
        XCTAssertNil(status.reason)
        XCTAssertFalse(status.developmentMode)
    }

    func testOnlineAndActionRequiredStatusesDecode() async throws {
        let (bridge, events) = try await subscribedEvents()
        let box = EventBox<ConnectionStatus>()
        let listener = StatusListener()
        _ = events.onConnectionStatusChanged { box.value = $0 }
        _ = events.addEventListener(listener)

        bridge.emit(eventType: EventCode.connectionStatus, json: """
        {"phase":"online","quality":"poor","accessPointId":"development","cellId":null,"regionId":null,
         "protocol":"ws","rttMs":412,"attempt":0,"nextRetryAt":null,"reason":null,"developmentMode":true}
        """)
        XCTAssertEqual(box.value?.phase, .online)
        XCTAssertEqual(box.value?.quality, .poor)
        XCTAssertEqual(box.value?.rttMs, 412)
        XCTAssertEqual(box.value?.developmentMode, true)
        XCTAssertEqual(listener.status?.phase, .online)

        bridge.emit(eventType: EventCode.connectionStatus, json: """
        {"phase":"actionRequired","quality":null,"accessPointId":null,"cellId":null,"regionId":null,
         "protocol":null,"rttMs":null,"attempt":0,"nextRetryAt":null,"reason":"upgradeRequired","developmentMode":false}
        """)
        XCTAssertEqual(box.value?.phase, .actionRequired)
        XCTAssertEqual(box.value?.reason, "upgradeRequired")
    }

    func testAccessEventsDecode() async throws {
        let (bridge, events) = try await subscribedEvents()
        let switched = EventBox<AccessSwitchedEvent>()
        let changed = EventBox<AccessChangedEvent>()
        _ = events.onAccessSwitched { switched.value = $0 }
        _ = events.onAccessChanged { changed.value = $0 }

        bridge.emit(eventType: EventCode.accessSwitched, json: """
        {"from":{"ap":"ap-sg-1","protocol":"quic"},"to":{"ap":"ap-sg-2","protocol":"ws"},"reason":"failure"}
        """)
        bridge.emit(eventType: EventCode.accessChanged, json: """
        {"serial":42,"source":"lkg","stale":false,"developmentMode":false,
         "changes":{"accessPointsAdded":["ap-sg-3"],"accessPointsRemoved":[],"policyChanged":true}}
        """)

        XCTAssertEqual(switched.value?.from.ap, "ap-sg-1")
        XCTAssertEqual(switched.value?.to.protocol, "ws")
        XCTAssertEqual(switched.value?.reason, "failure")
        XCTAssertEqual(changed.value?.serial, 42)
        XCTAssertEqual(changed.value?.source, "lkg")
        XCTAssertEqual(changed.value?.changes.accessPointsAdded, ["ap-sg-3"])
        XCTAssertEqual(changed.value?.changes.policyChanged, true)
    }

    // MARK: - typed errors

    func testTypedErrorsFromTheCAbiCode() {
        let overloaded = FlareSdkException.fromNative(nativeCode: 12, message: "busy", operation: nil, detailsJson: "")
        XCTAssertEqual(overloaded.code, "OVERLOADED")
        XCTAssertEqual(overloaded.kind, .overloaded(retryAfterMs: nil))

        let upgrade = FlareSdkException.fromNative(nativeCode: 13, message: "old", operation: nil, detailsJson: "")
        XCTAssertEqual(upgrade.kind, .upgradeRequired)

        let uncertain = FlareSdkException.fromNative(nativeCode: 14, message: "unknown", operation: nil, detailsJson: "")
        XCTAssertEqual(uncertain.kind, .networkUncertain)

        let other = FlareSdkException.fromNative(nativeCode: 5, message: "down", operation: nil, detailsJson: "")
        XCTAssertNil(other.kind)
    }

    func testTypedErrorsFromTheStructuredCode() {
        let overloaded = FlareSdkException.fromNative(
            nativeCode: 12,
            message: "busy",
            operation: "connection.reconnect_now",
            detailsJson: #"{"code":"OVERLOADED","reason":"sdk.overloaded","retryable":true,"retryAfterMs":1500}"#
        )
        XCTAssertEqual(overloaded.kind, .overloaded(retryAfterMs: 1500))
        XCTAssertTrue(overloaded.retryable)

        let upgrade = FlareSdkException.fromNative(
            nativeCode: 13, message: "old", operation: nil, detailsJson: #"{"code":"UPGRADE_REQUIRED","retryable":false}"#
        )
        XCTAssertEqual(upgrade.kind, .upgradeRequired)

        let uncertain = FlareSdkException(code: SdkErrorCodes.networkUncertain, message: "unknown")
        XCTAssertEqual(uncertain.kind, .networkUncertain)
    }

    // MARK: - connect token refresher

    func testTokenRequestRoundTrip() async throws {
        let router = FfiTokenRefreshRouter()
        let completed = CompletionBox()
        router.install(handle: 7, refresher: { "token-2" }) { completed.add($0, $1) }

        router.request(handle: 7, requestId: 42)

        let answers = try await completed.wait(for: 1)
        XCTAssertEqual(answers.first?.requestId, 42)
        XCTAssertEqual(answers.first?.token, "token-2")
    }

    func testANilOrBlankTokenAnswersNone() async throws {
        let router = FfiTokenRefreshRouter()
        let completed = CompletionBox()
        router.install(handle: 7, refresher: { nil }) { completed.add($0, $1) }
        router.install(handle: 8, refresher: { " " }) { completed.add($0, $1) }

        router.request(handle: 7, requestId: 1)
        router.request(handle: 8, requestId: 2)

        let answers = try await completed.wait(for: 2)
        XCTAssertEqual(Set(answers.map(\.requestId)), [1, 2])
        XCTAssertTrue(answers.allSatisfy { $0.token == nil })
    }

    func testASlowRefresherIsAnsweredNoneAtTheDeadline() async throws {
        let router = FfiTokenRefreshRouter(timeoutNanos: 50_000_000)
        let completed = CompletionBox()
        router.install(handle: 7, refresher: {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return "late"
        }) { completed.add($0, $1) }

        router.request(handle: 7, requestId: 3)

        let answers = try await completed.wait(for: 1)
        XCTAssertNil(answers.first?.token)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(completed.answers.count, 1, "answered once")
    }

    func testARemovedRefresherIsNotCalled() async throws {
        let router = FfiTokenRefreshRouter()
        let completed = CompletionBox()
        router.install(handle: 7, refresher: { "token" }) { completed.add($0, $1) }
        router.remove(handle: 7)

        router.request(handle: 7, requestId: 4)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(completed.answers.isEmpty)
    }

    /// The client hands the host function to the bridge hook; nil removes it.
    func testTheClientHandsTheRefresherToTheBridge() async throws {
        let bridge = RefresherBridge()
        let client = DefaultFlareImClient(bridge: bridge)

        try await client.setConnectTokenRefresher { "token-3" }
        let refresher = try XCTUnwrap(bridge.refresher)
        let token = await refresher()
        XCTAssertEqual(token, "token-3")

        try await client.setConnectTokenRefresher(nil)
        XCTAssertNil(bridge.refresher)
        XCTAssertEqual(bridge.calls, 2)
    }

    /// A bridge without a refresh channel (a test double) reports capabilityUnavailable.
    func testABridgeWithoutTheHookReportsCapabilityUnavailable() async {
        let client = DefaultFlareImClient(bridge: EventRecordingBridge())
        do {
            try await client.setConnectTokenRefresher { nil }
            XCTFail("expected capabilityUnavailable")
        } catch let error as FlareSdkException {
            XCTAssertEqual(error.code, SdkErrorCodes.capabilityUnavailable)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: - helpers

    private func subscribedEvents() async throws -> (EventRecordingBridge, DefaultEventsApi) {
        let bridge = EventRecordingBridge()
        let events = DefaultEventsApi(bridge: bridge)
        _ = try await events.subscribeEvents([:])
        return (bridge, events)
    }
}

private final class EventBox<T>: @unchecked Sendable {
    var value: T?
}

private final class StatusListener: FlareImEventListener {
    var status: ConnectionStatus?

    func onConnectionStatusChanged(_ event: ConnectionStatus) {
        status = event
    }
}

private final class CompletionBox: @unchecked Sendable {
    struct Answer {
        let requestId: UInt64
        let token: String?
    }

    private let lock = NSLock()
    private var recorded: [Answer] = []

    var answers: [Answer] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func add(_ requestId: UInt64, _ token: String?) {
        lock.lock()
        recorded.append(Answer(requestId: requestId, token: token))
        lock.unlock()
    }

    func wait(for count: Int, timeout: TimeInterval = 2) async throws -> [Answer] {
        let deadline = Date().addingTimeInterval(timeout)
        while answers.count < count {
            if Date() > deadline {
                XCTFail("expected \(count) answers, got \(answers.count)")
                break
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return answers
    }
}

/// Keeps the refresher the client hands over.
private final class RefresherBridge: NativeBridgeProtocol, @unchecked Sendable {
    private(set) var refresher: ConnectTokenRefresher?
    private(set) var calls = 0

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        AnySendable([String: Any]())
    }

    func setConnectTokenRefresher(_ refresher: ConnectTokenRefresher?) async throws {
        self.refresher = refresher
        calls += 1
    }
}

/// Hands events to the subscribed handler as the FFI bridge does: JSON decoded to plain values.
private final class EventRecordingBridge: NativeBridgeProtocol, @unchecked Sendable {
    private var handler: ((Int, Any?) -> Void)?

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        if descriptor.operation == SdkOperations.eventSubscribe || descriptor.operation == SdkOperations.eventSubscribeBatch {
            handler = (request?.value as? [String: Any])?["handler"] as? (Int, Any?) -> Void
        }
        return AnySendable([String: Any]())
    }

    func emit(eventType: Int, json: String) {
        handler?(eventType, FfiJson.decode(json))
    }
}
