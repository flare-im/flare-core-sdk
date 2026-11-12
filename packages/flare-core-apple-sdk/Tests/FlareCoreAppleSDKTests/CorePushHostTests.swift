import XCTest
import FlarePlatformPush
@testable import FlareCoreAppleSDK

/// 核心客户端上的推送宿主：每个方法落到哪个契约操作、带什么字段，结果怎么还原。
final class CorePushHostTests: XCTestCase {
    private let status: [String: Any] = [
        "configuredProviders": 1, "pendingRevocations": 0, "registeredProviders": 1, "state": "registered",
    ]

    func testTokenPermissionAndReconcileReachTheCore() async throws {
        let bridge = PushRecordingBridge(responses: [
            "sdk.update_push_token": status, "sdk.set_push_permission": status, "sdk.reconcile_push": status,
        ])
        let host = CorePushHost(client: DefaultFlareImClient(bridge: bridge))

        try await host.updatePushToken(PlatformPushToken(
            provider: "apns", platform: "ios", token: "deadbeef", appBundle: "im.flare.app", environment: "sandbox",
            locale: "zh-Hans-CN", timeZone: "Asia/Shanghai", appVersion: "1.2.0"
        ))
        try await host.setPushPermission(allowed: false)
        try await host.reconcilePush()

        XCTAssertEqual(bridge.calls.map(\.operation), [
            "sdk.update_push_token", "sdk.set_push_permission", "sdk.reconcile_push",
        ])
        let token = bridge.calls[0].request
        XCTAssertEqual(token["provider"] as? String, "apns")
        XCTAssertEqual(token["platform"] as? String, "ios")
        XCTAssertEqual(token["token"] as? String, "deadbeef")
        XCTAssertEqual(token["appBundle"] as? String, "im.flare.app")
        XCTAssertEqual(token["environment"] as? String, "sandbox")
        XCTAssertEqual(token["locale"] as? String, "zh-Hans-CN")
        XCTAssertEqual(token["timeZone"] as? String, "Asia/Shanghai")
        XCTAssertEqual(token["appVersion"] as? String, "1.2.0")
        XCTAssertEqual(token["capabilities"] as? [String], [])
        XCTAssertEqual(bridge.calls[1].request["allowed"] as? Bool, false)
    }

    func testARemoteMessageComesBackAsTheOutcome() async throws {
        let bridge = PushRecordingBridge(responses: [
            "sdk.handle_remote_message": [
                "action": "present",
                "presentation": [
                    "collapseId": "c:1", "threadId": "c:1", "conversationId": "conv-1", "messageId": "m-9", "seq": 42,
                    "title": "Ann", "body": "hi", "count": 2, "sound": true, "channel": "mentions", "surface": "system",
                ] as [String: Any],
                "clearCollapseIds": ["c:0"],
                "badge": 5,
            ],
        ])
        let host = CorePushHost(client: DefaultFlareImClient(bridge: bridge))

        let outcome = try await host.handleRemoteMessage(
            provider: "apns", payload: ["collapse_id": "c:1", "seq": "42"], budgetMs: 20_000
        )

        XCTAssertEqual(outcome, PlatformPushOutcome(
            action: .present,
            presentation: PlatformNotificationPresentation(
                collapseId: "c:1", threadId: "c:1", conversationId: "conv-1", messageId: "m-9", seq: 42,
                title: "Ann", body: "hi", count: 2, sound: true, channel: .mentions, surface: .system
            ),
            clearCollapseIds: ["c:0"],
            badge: 5
        ))
        let request = try XCTUnwrap(bridge.calls.first { $0.operation == "sdk.handle_remote_message" }).request
        XCTAssertEqual(request["provider"] as? String, "apns")
        XCTAssertEqual(request["payload"] as? [String: String], ["collapse_id": "c:1", "seq": "42"])
        XCTAssertEqual((request["budgetMs"] as? NSNumber)?.intValue, 20_000)
    }

    func testATapRoutesOnlyForTheCurrentAccount() async throws {
        let bridge = PushRecordingBridge(responses: [
            "sdk.resolve_notification_tap": ["conversationId": "conv-1", "messageId": "m-9", "seq": 42],
        ])
        let host = CorePushHost(client: DefaultFlareImClient(bridge: bridge))
        let route = try await host.resolveNotificationTap(payload: ["conversation_id": "conv-1"])
        XCTAssertEqual(route, PlatformTapRoute(conversationId: "conv-1", messageId: "m-9", seq: 42))
        XCTAssertEqual(
            bridge.calls.first?.request["payload"] as? [String: String], ["conversation_id": "conv-1"]
        )

        let other = CorePushHost(client: DefaultFlareImClient(bridge: PushRecordingBridge(responses: [
            "sdk.resolve_notification_tap": [:],
        ])))
        let none = try await other.resolveNotificationTap(payload: ["conversation_id": "conv-1"])
        XCTAssertNil(none)
    }

    func testClearAndBadgeEventsBecomeCorrections() async throws {
        let client = DefaultFlareImClient(bridge: PushRecordingBridge(responses: [:]))
        let events = try XCTUnwrap(client.events as? DefaultEventsApi)
        let host = CorePushHost(client: client)
        var corrections = host.notificationCorrections().makeAsyncIterator()

        events.emit(NotificationClearEvent(all: false, collapseIds: ["c:1", "c:2"]))
        events.emit(NotificationBadgeEvent(count: 3))
        events.emit(NotificationClearEvent(all: true, collapseIds: []))

        let cleared = await corrections.next()
        let badge = await corrections.next()
        let all = await corrections.next()
        XCTAssertEqual(cleared, .clear(collapseIds: ["c:1", "c:2"]))
        XCTAssertEqual(badge, .badge(3))
        XCTAssertEqual(all, .clearAll)
    }

    func testTheSnapshotDirectoryAndTheBackgroundRefreshReachTheCore() async throws {
        let bridge = PushRecordingBridge(responses: [
            "notification.set_snapshot_directory": [:],
            "notification.background_refresh": ["completed": true],
        ])
        let host = CorePushHost(client: DefaultFlareImClient(bridge: bridge))

        await host.setNotificationSnapshotDirectory("/group/flare-notify")
        let completed = await host.backgroundRefresh(budgetMs: 25_000)

        XCTAssertTrue(completed)
        XCTAssertEqual(bridge.calls.map(\.operation), [
            "notification.set_snapshot_directory", "notification.background_refresh",
        ])
        XCTAssertEqual(bridge.calls[0].request["directory"] as? String, "/group/flare-notify")
        XCTAssertEqual((bridge.calls[1].request["budgetMs"] as? NSNumber)?.intValue, 25_000)

        let unfinished = CorePushHost(client: DefaultFlareImClient(bridge: PushRecordingBridge(responses: [
            "notification.background_refresh": ["completed": false],
        ])))
        let result = await unfinished.backgroundRefresh(budgetMs: 25_000)
        XCTAssertFalse(result)
    }
}

/// 记下每次桥调用，按操作回固定的应答。
private final class PushRecordingBridge: NativeBridgeProtocol, @unchecked Sendable {
    struct Call {
        let operation: String
        let request: [String: Any]
    }

    private let lock = NSLock()
    private let responses: [String: [String: Any]]
    private var recorded: [Call] = []

    init(responses: [String: [String: Any]]) {
        self.responses = responses
    }

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        lock.lock()
        recorded.append(Call(operation: descriptor.operation, request: FfiJson.asMap(request)))
        lock.unlock()
        return AnySendable(responses[descriptor.operation] ?? [String: Any]())
    }
}
