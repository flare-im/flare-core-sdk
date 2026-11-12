import XCTest
@testable import FlarePlatformPush

final class PushPayloadTests: XCTestCase {
    /// 顶层自定义键转成字符串，数字写成十进制；`aps` 不进字典，只抄标题正文；嵌套值丢弃。
    func testFlattenStringifiesTopLevelKeysAndLiftsTheAlert() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Ann", "subtitle": "ignored", "body": "hello"], "badge": 3, "sound": "default"],
            "uid": "u-1",
            "conversation_id": "conv-1",
            "collapse_id": "c:0123456789abcdef0123456789abcdef",
            "seq": 18_446_744_073_709_551_615 as UInt64,
            "count": 2,
            "badge": 5.0,
            "sound": true,
            "ratio": 1.5,
            "nested": ["a": 1],
            "list": [1, 2],
        ]
        let payload = PlatformPushPayload.flatten(userInfo)

        XCTAssertEqual(payload["title"], "Ann")
        XCTAssertEqual(payload["body"], "hello")
        XCTAssertNil(payload["aps"])
        XCTAssertNil(payload["subtitle"])
        XCTAssertEqual(payload["uid"], "u-1")
        XCTAssertEqual(payload["seq"], "18446744073709551615")
        XCTAssertEqual(payload["count"], "2")
        XCTAssertEqual(payload["badge"], "5")
        XCTAssertEqual(payload["sound"], "1")
        XCTAssertEqual(payload["ratio"], "1.5")
        XCTAssertNil(payload["nested"])
        XCTAssertNil(payload["list"])
        XCTAssertTrue(PlatformPushPayload.isFlare(userInfo: userInfo))
    }

    /// `aps.alert` 是字符串时就是正文；静默推送没有 alert。
    func testAStringAlertIsTheBodyAndASilentPushCarriesNone() {
        let alerted: [AnyHashable: Any] = ["aps": ["alert": "hi"], "collapse_id": "c:1"]
        XCTAssertEqual(PlatformPushPayload.flatten(alerted)["body"], "hi")
        XCTAssertTrue(PlatformPushPayload.carriesAlert(alerted))

        let silent: [AnyHashable: Any] = ["aps": ["content-available": 1], "collapse_id": "c:1", "title": "T"]
        XCTAssertFalse(PlatformPushPayload.carriesAlert(silent))
        XCTAssertEqual(PlatformPushPayload.flatten(silent)["title"], "T")
        XCTAssertFalse(PlatformPushPayload.isFlare(userInfo: ["aps": ["alert": "other app feature"]]))
    }

    /// 没有宿主时按处置原样得出结果：响铃提示、静默更新、清除、仅角标；没有文案的不提示。
    func testOutcomeFromThePayload() {
        let loud = PlatformPushPayload.outcome(fromPayload: [
            "collapse_id": "c:1", "thread_id": "c:1", "conversation_id": "conv-1", "message_id": "m-9", "seq": "42",
            "disposition": "loud", "alert_class": "mention", "count": "3", "badge": "7", "title": "Ann", "body": "hi",
            "sound": "1",
        ])
        XCTAssertEqual(loud, PlatformPushOutcome(
            action: .present,
            presentation: PlatformNotificationPresentation(
                collapseId: "c:1", threadId: "c:1", conversationId: "conv-1", messageId: "m-9", seq: 42,
                title: "Ann", body: "hi", count: 3, sound: true, channel: .mentions, surface: .system
            ),
            badge: 7
        ))

        let quiet = PlatformPushPayload.outcome(fromPayload: [
            "collapse_id": "c:1", "conversation_id": "conv-1", "disposition": "quiet", "title": "Ann", "body": "2 new",
            "sound": "1",
        ])
        XCTAssertEqual(quiet.action, .update)
        XCTAssertEqual(quiet.presentation?.channel, .quiet)
        XCTAssertEqual(quiet.presentation?.threadId, "c:1", "the collapse id groups when no thread id is given")
        XCTAssertEqual(quiet.presentation?.sound, false)

        XCTAssertEqual(
            PlatformPushPayload.outcome(fromPayload: ["collapse_id": "c:1", "disposition": "clear", "badge": "0"]),
            PlatformPushOutcome(action: .clear, clearCollapseIds: ["c:1"], badge: 0)
        )
        XCTAssertEqual(
            PlatformPushPayload.outcome(fromPayload: ["collapse_id": "c:1", "disposition": "badge_only", "badge": "4"]),
            PlatformPushOutcome(action: .badgeOnly, badge: 4)
        )
        XCTAssertEqual(
            PlatformPushPayload.outcome(fromPayload: ["collapse_id": "c:1", "disposition": "loud"]).action,
            .ignore
        )
        XCTAssertEqual(
            PlatformPushPayload.outcome(fromPayload: ["conversation_id": "conv-1", "title": "T"]).action,
            .present,
            "an unknown disposition still alerts"
        )
    }

    /// 描述文件的 `aps-environment`：development 是沙盒，其余与没有描述文件都是生产。
    func testApnsEnvironmentFromTheProvisioningProfile() {
        func profile(_ environment: String) -> Data {
            var data = Data([0x30, 0x82, 0x01, 0x00, 0xff])
            data.append(Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict><key>Name</key><string>dev</string><key>Entitlements</key><dict>
            <key>aps-environment</key><string>\(environment)</string></dict></dict></plist>
            """.utf8))
            data.append(Data([0x00, 0xa0, 0x82]))
            return data
        }
        XCTAssertEqual(PlatformPushDeviceInfo.apnsEnvironment(provisioningProfile: profile("development")), "sandbox")
        XCTAssertEqual(PlatformPushDeviceInfo.apnsEnvironment(provisioningProfile: profile("production")), "production")
        XCTAssertEqual(PlatformPushDeviceInfo.apnsEnvironment(provisioningProfile: nil), "production")
        XCTAssertEqual(PlatformPushDeviceInfo.apnsEnvironment(provisioningProfile: Data("garbage".utf8)), "production")
    }

    func testTheApnsTokenIsLowercaseHexWithTheDeviceInfo() {
        let device = PlatformPushDeviceInfo(
            appBundle: "im.flare.app", environment: "sandbox", locale: "zh-Hans-CN", timeZone: "Asia/Shanghai",
            appVersion: "1.2.0"
        )
        let token = PlatformPushToken.apns(token: PlatformPushToken.hex(Data([0x0a, 0xbc, 0xff])), device: device)
        XCTAssertEqual(token, PlatformPushToken(
            provider: "apns", platform: "ios", token: "0abcff", appBundle: "im.flare.app", environment: "sandbox",
            locale: "zh-Hans-CN", timeZone: "Asia/Shanghai", appVersion: "1.2.0", capabilities: []
        ))
        XCTAssertFalse(token.description.contains("0abcff"), "the token never reaches a log line")
    }
}
