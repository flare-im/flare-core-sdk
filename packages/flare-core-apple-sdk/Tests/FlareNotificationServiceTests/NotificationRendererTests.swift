import XCTest
@testable import FlareNotificationService

/// 扩展的重渲染：标题取本地会话标题，预览设置按快照，发送者名字换成本地名字；快照不可用时原样。
final class NotificationRendererTests: XCTestCase {
    private let fields: [String: String] = [
        "uid": "u-1", "tenant_id": "t-1", "conversation_id": "c-1", "message_id": "m-9", "seq": "42",
        "collapse_id": "c:0123456789abcdef0123456789abcdef", "disposition": "loud", "alert_class": "normal",
        "count": "1", "sender_id": "u-2", "sender_name": "Alice", "kind": "group",
    ]

    private func snapshot(preview: String = "full", uid: String = "u-1", extra: [String: Any] = [:]) -> NotificationSnapshot? {
        var root: [String: Any] = [
            "v": 1,
            "uid": uid,
            "tenant": "t-1",
            "locale": "zh-CN",
            "preview": preview,
            "strings": [
                "genericTitle": "新消息", "genericBody": "你收到一条新消息", "sentMessage": "发来一条消息",
                "mentionMarker": "[有人@你]", "recalled": "撤回了一条消息",
            ],
            "conversations": [
                "c-1": ["t": "Project", "m": false, "o": false, "g": true] as [String: Any],
                "c-2": ["t": "Bob (remark)", "m": false, "o": false, "g": false] as [String: Any],
            ],
            "names": ["u-2": "Alice (remark)"],
            "at": 1_731_400_000_000,
        ]
        root.merge(extra) { _, new in new }
        let data = try! JSONSerialization.data(withJSONObject: root)
        return NotificationSnapshot.parse(data)
    }

    private func payload(_ changes: [String: String] = [:]) -> NotificationPayload {
        NotificationPayload(fields: fields.merging(changes) { _, new in new })
    }

    func testFullPreviewTakesTheLocalTitleAndTheLocalSenderName() {
        let text = NotificationRenderer.render(
            title: "新消息", body: "Alice: ship it", payload: payload(), snapshot: snapshot()
        )
        XCTAssertEqual(text, NotificationText(title: "Project", body: "Alice (remark): ship it"))
    }

    func testOnlyTheFirstOccurrenceOfTheSenderNameIsReplaced() {
        let text = NotificationRenderer.render(
            title: "新消息", body: "Alice: ask Alice", payload: payload(), snapshot: snapshot()
        )
        XCTAssertEqual(text?.body, "Alice (remark): ask Alice")
    }

    func testTheCountPrefixOfTheServerTitleStays() {
        let text = NotificationRenderer.render(
            title: "[3条] 新消息", body: "Alice: hi", payload: payload(["count": "3"]), snapshot: snapshot()
        )
        XCTAssertEqual(text?.title, "[3条] Project")
        XCTAssertEqual(NotificationRenderer.countPrefix(of: "[99+ messages] New message", count: 120), "[99+ messages] ")
        XCTAssertEqual(NotificationRenderer.countPrefix(of: "[Ops] Alerts", count: 3), "", "not a count")
        XCTAssertEqual(NotificationRenderer.countPrefix(of: "[3条] 新消息", count: 1), "", "one message has no prefix")
    }

    func testAnUnknownConversationKeepsTheServerTitleWithTheLocalName() {
        let text = NotificationRenderer.render(
            title: "Alice", body: "hi", payload: payload(["conversation_id": "c-9", "kind": "direct"]), snapshot: snapshot()
        )
        XCTAssertEqual(text, NotificationText(title: "Alice (remark)", body: "hi"))
    }

    func testHiddenPreviewShowsTheGenericCopy() {
        let text = NotificationRenderer.render(
            title: "[2条] Alice", body: "Alice: secret", payload: payload(["count": "2"]),
            snapshot: snapshot(preview: "hidden")
        )
        XCTAssertEqual(text, NotificationText(title: "[2条] 新消息", body: "你收到一条新消息"))
    }

    func testAnUnknownPreviewIsTreatedAsHidden() {
        let text = NotificationRenderer.render(
            title: "Alice", body: "secret", payload: payload(), snapshot: snapshot(preview: "blurred")
        )
        XCTAssertEqual(text?.body, "你收到一条新消息")
    }

    func testSenderOnlyInAGroupNamesTheSender() {
        let text = NotificationRenderer.render(
            title: "新消息", body: "Alice: secret", payload: payload(), snapshot: snapshot(preview: "sender_only")
        )
        XCTAssertEqual(text, NotificationText(title: "Project", body: "Alice (remark) 发来一条消息"))
    }

    func testSenderOnlyInADirectChatLeavesTheSenderToTheTitle() {
        let text = NotificationRenderer.render(
            title: "Bob", body: "secret",
            payload: payload(["conversation_id": "c-2", "kind": "direct", "sender_id": "u-3", "sender_name": ""]),
            snapshot: snapshot(preview: "sender_only")
        )
        XCTAssertEqual(text, NotificationText(title: "Bob (remark)", body: "发来一条消息"))
    }

    func testSenderOnlyKeepsTheMentionMarker() {
        let text = NotificationRenderer.render(
            title: "新消息", body: "[有人@你] Alice: look", payload: payload(["alert_class": "mention"]),
            snapshot: snapshot(preview: "sender_only")
        )
        XCTAssertEqual(text?.body, "[有人@你] Alice (remark) 发来一条消息")
    }

    func testSenderOnlyForANoticeSaysNothingAboutASender() {
        let text = NotificationRenderer.render(
            title: "Friend request", body: "Carol wants to add you",
            payload: payload(["conversation_id": "", "kind": "notice", "sender_id": "", "sender_name": ""]),
            snapshot: snapshot(preview: "sender_only")
        )
        XCTAssertEqual(text, NotificationText(title: "Friend request", body: "你收到一条新消息"))
    }

    func testARecallReplacementSaysRecalled() {
        let text = NotificationRenderer.render(
            title: "新消息", body: "Message recalled", payload: payload(["disposition": "recall_replace"]),
            snapshot: snapshot()
        )
        XCTAssertEqual(text, NotificationText(title: "Project", body: "撤回了一条消息"))
    }

    func testADigestIsLeftAsItCame() {
        XCTAssertNil(NotificationRenderer.render(
            title: "新消息", body: "2 个会话有 5 条新消息",
            payload: payload(["disposition": "digest", "sender_id": "", "sender_name": "", "count": "5"]),
            snapshot: snapshot()
        ))
    }

    func testWithoutAUsableSnapshotThePayloadIsShownAsIs() {
        XCTAssertNil(NotificationRenderer.render(title: "a", body: "b", payload: payload(), snapshot: nil))
        XCTAssertNil(NotificationRenderer.render(
            title: "a", body: "b", payload: payload(), snapshot: snapshot(uid: "u-other")
        ), "a snapshot of another user")
        XCTAssertNil(NotificationRenderer.render(
            title: "a", body: "b", payload: payload(["tenant_id": "t-2"]), snapshot: snapshot()
        ), "a snapshot of another tenant")
        XCTAssertNil(NotificationRenderer.render(
            title: "a", body: "b", payload: payload(["uid": ""]), snapshot: snapshot()
        ), "a payload without a user cannot be matched")
    }

    func testOnlyVersionOneSnapshotsAreRead() throws {
        XCTAssertNil(snapshot(extra: ["v": 2]))
        XCTAssertNil(NotificationSnapshot.parse(Data("[]".utf8)))
        XCTAssertNil(NotificationSnapshot.parse(Data("{\"v\":1,\"tenant\":\"t-1\"}".utf8)), "no user")
        let parsed = try XCTUnwrap(snapshot())
        XCTAssertEqual(parsed.conversation("c-1"), NotificationSnapshot.Conversation(
            title: "Project", muted: false, mentionOnly: false, group: true
        ))
        XCTAssertNil(parsed.conversation("c-9"))
        XCTAssertEqual(parsed.name("u-2"), "Alice (remark)")
        XCTAssertNil(parsed.name(""))
    }

    func testThePayloadReadsNumbersAsText() {
        let read = NotificationPayload(userInfo: [
            "aps": ["alert": ["title": "t", "body": "b"], "mutable-content": 1] as [String: Any],
            "uid": "u-1", "tenant_id": "t-1", "conversation_id": "c-1", "seq": NSNumber(value: 42), "count": 3,
            "collapse_id": "c:1",
        ])
        XCTAssertEqual(read.seq, 42)
        XCTAssertEqual(read.count, 3)
        XCTAssertTrue(read.isFlare)
        XCTAssertFalse(NotificationPayload(userInfo: ["kind": "reminder"]).isFlare)
    }
}
