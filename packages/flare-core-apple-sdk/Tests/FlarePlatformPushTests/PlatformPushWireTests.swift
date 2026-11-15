import XCTest
@testable import FlarePlatformPush

/// 契约 JSON 的读写：社交 SDK 的 IM 分发与 Flutter 方法通道共用这一份。
final class PlatformPushWireTests: XCTestCase {
    func testTheTokenRequestOmitsAbsentFields() {
        let request = PlatformPushWire.tokenRequest(PlatformPushToken(
            provider: "apns", platform: "ios", token: "deadbeef", appBundle: "im.flare.app", environment: "sandbox",
            locale: "zh-CN"
        ))
        XCTAssertEqual(request["provider"] as? String, "apns")
        XCTAssertEqual(request["platform"] as? String, "ios")
        XCTAssertEqual(request["token"] as? String, "deadbeef")
        XCTAssertEqual(request["appBundle"] as? String, "im.flare.app")
        XCTAssertEqual(request["environment"] as? String, "sandbox")
        XCTAssertEqual(request["locale"] as? String, "zh-CN")
        XCTAssertNil(request["timeZone"])
        XCTAssertNil(request["appVersion"])
        XCTAssertNil(request["capabilities"], "an empty capability list is left out")

        let withCapabilities = PlatformPushWire.tokenRequest(PlatformPushToken(
            provider: "apns", platform: "ios", token: "t", capabilities: ["serviceExtension"]
        ))
        XCTAssertEqual(withCapabilities["capabilities"] as? [String], ["serviceExtension"])
    }

    /// 数字可能是数字也可能是字符串；空的合并键丢掉；次数至少为 1；没有合并键的展示意图按缺失处理。
    func testTheOutcomeReadsEitherNumberForm() throws {
        let outcome = try PlatformPushWire.outcome([
            "action": "update",
            "presentation": [
                "collapseId": "c:1", "threadId": "", "conversationId": "conv-1", "messageId": "m-9",
                "seq": "18446744073709551615", "title": "Ann", "body": "3 new", "count": 0, "sound": 1,
                "channel": "quiet", "surface": "inApp",
            ] as [String: Any],
            "clearCollapseIds": ["c:0", "", NSNull()] as [Any],
            "badge": NSNumber(value: 9),
            "reason": NSNull(),
        ] as [String: Any])

        XCTAssertEqual(outcome, PlatformPushOutcome(
            action: .update,
            presentation: PlatformNotificationPresentation(
                collapseId: "c:1", threadId: "c:1", conversationId: "conv-1", messageId: "m-9",
                seq: 18_446_744_073_709_551_615, title: "Ann", body: "3 new", count: 1, sound: true, channel: .quiet,
                surface: .inApp
            ),
            clearCollapseIds: ["c:0"],
            badge: 9
        ))
        XCTAssertNil(PlatformPushWire.presentation(["collapseId": "", "title": "T"] as [String: Any]))
        XCTAssertNil(try PlatformPushWire.outcome(["badge": -1] as [String: Any]).badge)
    }

    /// 认不出的动作当作什么都不做；不是对象时抛错，宿主据此按失败处理。
    func testAnUnknownActionIsIgnoredAndANonObjectThrows() throws {
        XCTAssertEqual(
            try PlatformPushWire.outcome(["action": "explode", "reason": "otherAccount"] as [String: Any]),
            PlatformPushOutcome(action: .ignore, reason: "otherAccount")
        )
        XCTAssertEqual(
            try PlatformPushWire.outcome(["action": "badgeOnly", "badge": 0] as [String: Any]),
            PlatformPushOutcome(action: .badgeOnly, badge: 0)
        )
        XCTAssertThrowsError(try PlatformPushWire.outcome(nil)) { error in
            XCTAssertEqual(error as? PlatformPushWireError, PlatformPushWireError(expected: "RemoteMessageOutcome"))
        }
        XCTAssertThrowsError(try PlatformPushWire.outcome("present"))
    }

    func testATapRouteRoundTripsAndAnotherAccountHasNone() {
        let route = PlatformTapRoute(conversationId: "conv-1", messageId: "m-9", seq: 42)
        let wire = PlatformPushWire.tapResult(route)
        XCTAssertEqual(wire["conversationId"] as? String, "conv-1")
        XCTAssertEqual(wire["messageId"] as? String, "m-9")
        XCTAssertEqual(wire["seq"] as? Int64, 42, "written signed: the Flutter codec has no unsigned 64-bit")
        XCTAssertEqual(PlatformPushWire.tapRoute(wire), route)

        XCTAssertNil(PlatformPushWire.tapRoute([:] as [String: Any]))
        XCTAssertNil(PlatformPushWire.tapRoute(nil))
        XCTAssertEqual(
            PlatformPushWire.tapRoute(["conversationId": "conv-1", "messageId": ""] as [String: Any]),
            PlatformTapRoute(conversationId: "conv-1")
        )
    }

    func testClearAndBadgeEventsReadAsCorrections() {
        XCTAssertEqual(
            PlatformPushWire.clearCorrection(["collapseIds": ["c:1", " ", "c:2"], "all": false] as [String: Any]),
            .clear(collapseIds: ["c:1", "c:2"])
        )
        XCTAssertEqual(
            PlatformPushWire.clearCorrection(["collapseIds": [String](), "all": true] as [String: Any]),
            .clearAll
        )
        XCTAssertNil(PlatformPushWire.clearCorrection(["collapseIds": [String](), "all": false] as [String: Any]))
        XCTAssertNil(PlatformPushWire.clearCorrection(nil))

        XCTAssertEqual(PlatformPushWire.badgeCorrection(["count": 12] as [String: Any]), .badge(12))
        XCTAssertEqual(PlatformPushWire.badgeCorrection(["count": 0] as [String: Any]), .badge(0))
        XCTAssertNil(PlatformPushWire.badgeCorrection(["count": -1] as [String: Any]))
        XCTAssertNil(PlatformPushWire.badgeCorrection([:] as [String: Any]))
    }
}
