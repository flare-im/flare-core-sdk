import UserNotifications
import XCTest
@testable import FlareNotificationService

/// 回执日志：一行一个对象（带推送发给的账号）、只追加、到 64 KiB 停；扩展处理推送时回执照记，快照不可用时内容原样。
final class NotificationReceiptLogTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("flare-notify-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var log: URL { directory.appendingPathComponent(NotificationReceiptLog.fileName) }

    private func receipt(conversationId: String = "c-1", seq: UInt64 = 123) -> NotificationReceipt {
        NotificationReceipt(
            payload: NotificationPayload(fields: [
                "uid": "u-1", "tenant_id": "t-1",
                "conversation_id": conversationId, "message_id": "m-9", "seq": String(seq),
                "collapse_id": "c:0123456789abcdef0123456789abcdef", "disposition": "loud",
            ]),
            receivedAtMs: 1_731_400_000_000
        )
    }

    func testTheLineIsTheContractShape() {
        XCTAssertEqual(
            receipt().line,
            "{\"u\":\"u-1\",\"n\":\"t-1\",\"c\":\"c-1\",\"m\":\"m-9\",\"s\":123,"
                + "\"k\":\"c:0123456789abcdef0123456789abcdef\",\"d\":\"loud\",\"p\":\"apns\",\"t\":1731400000000}\n"
        )
    }

    func testStringsAreEscaped() throws {
        let line = receipt(conversationId: "a\"b\\c\nd\u{1}e").line
        XCTAssertTrue(line.contains(",\"c\":\"a\\\"b\\\\c\\nd\\u0001e\","))
        let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        XCTAssertEqual(object?["c"] as? String, "a\"b\\c\nd\u{1}e")
        XCTAssertEqual((object?["s"] as? NSNumber)?.uint64Value, 123)
    }

    func testTheLineCarriesTheAccountThePushWasFor() throws {
        let line = receipt().line
        let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        XCTAssertEqual(object?["u"] as? String, "u-1")
        XCTAssertEqual(object?["n"] as? String, "t-1")
        let anonymous = NotificationReceipt(
            payload: NotificationPayload(fields: ["conversation_id": "c-1", "collapse_id": "c:1"]),
            receivedAtMs: 5
        ).line
        XCTAssertTrue(anonymous.hasPrefix("{\"u\":\"\",\"n\":\"\","), "a payload without an account writes empty ones")
    }

    func testLinesAreAppended() throws {
        XCTAssertTrue(NotificationReceiptLog.append(receipt(seq: 1), directory: directory))
        XCTAssertTrue(NotificationReceiptLog.append(receipt(seq: 2), directory: directory))
        let lines = try String(contentsOf: log, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("\"s\":2"))
    }

    func testAppendingStopsAtTheCap() throws {
        let filler = Data(repeating: 0x20, count: NotificationReceiptLog.maxBytes - 10)
        try filler.write(to: log)
        XCTAssertFalse(NotificationReceiptLog.append(receipt(), directory: directory))
        XCTAssertEqual(try Data(contentsOf: log).count, filler.count, "nothing written past the cap")
    }

    func testAMissingDirectoryWritesNothing() {
        let missing = directory.appendingPathComponent("absent", isDirectory: true)
        XCTAssertFalse(NotificationReceiptLog.append(receipt(), directory: missing))
    }

    func testProcessingRendersFromTheSnapshotAndRecordsTheReceipt() throws {
        let snapshot: [String: Any] = [
            "v": 1, "uid": "u-1", "tenant": "t-1", "locale": "en", "preview": "full",
            "strings": ["genericTitle": "New message", "genericBody": "You have a new message"],
            "conversations": ["c-1": ["t": "Project", "g": true] as [String: Any]],
            "names": ["u-2": "Alice (remark)"],
        ]
        try JSONSerialization.data(withJSONObject: snapshot)
            .write(to: directory.appendingPathComponent(NotificationSnapshot.fileName))
        let content = UNMutableNotificationContent()
        content.title = "New message"
        content.body = "Alice: hi"
        content.threadIdentifier = "c:1"
        content.userInfo = [
            "uid": "u-1", "tenant_id": "t-1", "conversation_id": "c-1", "message_id": "m-9", "seq": 7,
            "collapse_id": "c:1", "disposition": "loud", "sender_id": "u-2", "sender_name": "Alice", "kind": "group",
        ]

        let shown = FlareNotificationServiceBase.process(content, directory: directory, receivedAtMs: 5)

        XCTAssertEqual(shown.title, "Project")
        XCTAssertEqual(shown.body, "Alice (remark): hi")
        XCTAssertEqual(shown.threadIdentifier, "c:1", "everything else comes from the payload")
        XCTAssertEqual(shown.userInfo["message_id"] as? String, "m-9")
        let line = try String(contentsOf: log, encoding: .utf8)
        XCTAssertEqual(
            line,
            "{\"u\":\"u-1\",\"n\":\"t-1\",\"c\":\"c-1\",\"m\":\"m-9\",\"s\":7,\"k\":\"c:1\",\"d\":\"loud\","
                + "\"p\":\"apns\",\"t\":5}\n"
        )
    }

    func testWithoutASnapshotTheContentIsUnchangedButTheReceiptIsWritten() throws {
        let content = UNMutableNotificationContent()
        content.title = "New message"
        content.body = "hi"
        content.userInfo = ["uid": "u-1", "tenant_id": "t-1", "conversation_id": "c-1", "collapse_id": "c:1"]

        let shown = FlareNotificationServiceBase.process(content, directory: directory, receivedAtMs: 5)

        XCTAssertTrue(shown === content)
        XCTAssertTrue(FileManager.default.fileExists(atPath: log.path))
    }

    func testOtherPushesAreLeftAlone() {
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.userInfo = ["kind": "reminder"]

        let shown = FlareNotificationServiceBase.process(content, directory: directory, receivedAtMs: 5)

        XCTAssertTrue(shown === content)
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.path), "no receipt for a push that is not ours")
    }
}
