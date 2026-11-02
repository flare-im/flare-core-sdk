import Foundation
import XCTest
@testable import FlareCoreAppleSDK

/// Projected names (`title`, `lastSender`, `sender`, participant `name`) and the typed reason of a failed send, read
/// against the shared vectors in sdk-spec/golden.
final class DisplayNameWireTests: XCTestCase {
    func testEveryProjectedNameDecodesAsTheCoreWroteIt() throws {
        for (name, expected) in try projectedNames() {
            let decoded = try XCTUnwrap(displayNameFromJson(expected), name)
            XCTAssertTrue(wireEquals(displayNameToMap(decoded), expected), name)
        }
    }

    func testConversationsMessagesAndParticipantsCarryTheirNames() throws {
        for (name, expected) in try projectedNames() {
            var conversationJson = try golden("responses/conversation_get_one.json")
            conversationJson["title"] = expected
            conversationJson["lastSender"] = expected
            conversationJson["memberPreview"] = [participant("u2", name: expected)]
            conversationJson["participants"] = [participant("u3", name: expected)]
            let conversation = try conversationFromJson(conversationJson)
            XCTAssertTrue(wireEquals(displayNameToMap(conversation.title), expected), name)
            XCTAssertTrue(wireEquals(conversation.lastSender.map(displayNameToMap), expected), name)
            XCTAssertTrue(wireEquals(conversation.memberPreview.first.map { displayNameToMap($0.name) }, expected), name)
            XCTAssertTrue(wireEquals(conversation.participants.first.map { displayNameToMap($0.name) }, expected), name)

            var messageJson = try golden("responses/build_thread_reply_message.json")
            messageJson["sender"] = expected
            let message = try messageFromJson(messageJson)
            XCTAssertTrue(wireEquals(displayNameToMap(message.sender), expected), name)
        }
    }

    func testTheNamesEveryValueCarriesAreRequiredAndLastSenderStaysOutWithoutALatestMessage() throws {
        var untitled = try golden("responses/conversation_get_one.json")
        untitled.removeValue(forKey: "title")
        assertRequired("Conversation.title") { _ = try conversationFromJson(untitled) }
        let conversation = try conversationFromJson(try golden("responses/conversation_get_one.json"))
        XCTAssertEqual(conversation.title.kind, .named)
        XCTAssertEqual(conversation.title.text, "User Two")
        XCTAssertNil(conversation.lastSender)

        var unsent = try golden("responses/build_thread_reply_message.json")
        unsent.removeValue(forKey: "sender")
        assertRequired("Message.sender") { _ = try messageFromJson(unsent) }

        assertRequired("ConversationParticipant.name") { _ = try conversationParticipantFromJson(participant("u2")) }
        XCTAssertNil(displayNameFromJson(nil))
        XCTAssertNil(displayNameFromJson(NSNull()))
    }

    func testAnUnknownKindReadsAsAnUnnamedPersonWithoutIdTail() throws {
        assertUnknownPerson(displayNameFromJson(["kind": "nickname", "text": "Alice"]))
        assertUnknownPerson(displayNameFromJson(["text": "Alice"]))
        var conversationJson = try golden("responses/conversation_get_one.json")
        conversationJson["title"] = ["kind": "emoji", "value": ":)"]
        assertUnknownPerson(try conversationFromJson(conversationJson).title)
    }

    func testAnUnknownEntityReadsAsAPersonAndKeepsTheIdTail() throws {
        let robot = try XCTUnwrap(displayNameFromJson(["kind": "unnamed", "entity": "robot", "idTail": "9876"]))
        XCTAssertEqual(robot.kind, .unnamed)
        XCTAssertEqual(robot.entity, .person)
        XCTAssertEqual(robot.idTail, "9876")
        assertUnknownPerson(displayNameFromJson(["kind": "unnamed"]))

        var messageJson = try golden("responses/build_thread_reply_message.json")
        messageJson["sender"] = ["kind": "unnamed", "entity": "bot", "idTail": "0401"]
        let sender = try messageFromJson(messageJson).sender
        XCTAssertEqual(sender.entity, .person)
        XCTAssertEqual(sender.idTail, "0401")
    }

    func testMalformedNamesDoNotFailTheValueThatCarriesThem() throws {
        assertUnknownPerson(displayNameFromJson("Alice"))
        assertUnknownPerson(displayNameFromJson(["Alice"]))
        assertUnknownPerson(displayNameFromJson(["kind": "named"]))

        let unknownSource = try XCTUnwrap(displayNameFromJson(["kind": "named", "text": "Alice", "source": "nickname"]))
        XCTAssertEqual(unknownSource.text, "Alice")
        XCTAssertNil(unknownSource.source)

        let members = try XCTUnwrap(displayNameFromJson(["kind": "members", "names": ["Ann", 3, "Ben"], "total": 4.7]))
        XCTAssertEqual(members.names, ["Ann", "Ben"])
        XCTAssertEqual(members.total, 4)
        let negative = try XCTUnwrap(displayNameFromJson(["kind": "members", "total": -1]))
        XCTAssertEqual(negative.names, [])
        XCTAssertEqual(negative.total, 0)
        let flag = try XCTUnwrap(displayNameFromJson(["kind": "members", "names": ["Ann"], "total": true]))
        XCTAssertEqual(flag.total, 0)

        let group = try XCTUnwrap(displayNameFromJson(["kind": "unnamed", "entity": "group", "idTail": 12]))
        XCTAssertEqual(group.entity, .group)
        XCTAssertEqual(group.idTail, "")
    }

    func testTheServerRejectionGoldenArrivesWithItsTypedReason() async throws {
        let golden = try golden("events/send_failed_with_error.json")
        let expected = try XCTUnwrap(golden["error"] as? [String: Any])
        let failed = try await deliverSendFailed(golden)

        XCTAssertEqual(failed.events.count, 1)
        let event = try XCTUnwrap(failed.events.first)
        XCTAssertEqual(event.clientMsgId, golden["clientMsgId"] as? String)
        XCTAssertEqual(event.reason, golden["reason"] as? String)
        let error = try XCTUnwrap(event.error)
        XCTAssertEqual(error.code, expected["code"] as? String)
        XCTAssertEqual(error.machineReason, "SOCIAL_CARD_SCOPE_FRIENDS")
        XCTAssertEqual(error.machineReason, expected["machineReason"] as? String)
        XCTAssertEqual(error.message, expected["message"] as? String)
        XCTAssertEqual(error.operation, expected["operation"] as? String)
        XCTAssertEqual(error.retryable, expected["retryable"] as? Bool)
        XCTAssertEqual(error.details, expected["details"] as? [String: String])
        XCTAssertTrue(failed.decodeFailures.isEmpty)
    }

    func testTheEmptyTypedReasonOfALocalFailureReadsAsNoReason() async throws {
        let local = try await deliverSendFailed([
            "clientMsgId": "cm1",
            "reason": "send timed out",
            "error": [
                "code": "OPERATION_TIMEOUT",
                "machineReason": "",
                "message": "send timed out",
                "operation": "message.send",
                "retryable": false,
                "details": [String: String](),
            ] as [String: Any],
        ])
        XCTAssertEqual(local.events.first?.error?.code, "OPERATION_TIMEOUT")
        XCTAssertNil(try XCTUnwrap(local.events.first?.error).machineReason)

        let malformed = try await deliverSendFailed([
            "clientMsgId": "cm1",
            "reason": "send timed out",
            "error": ["code": "OPERATION_TIMEOUT", "machineReason": 21, "message": "send timed out"] as [String: Any],
        ])
        XCTAssertTrue(malformed.events.isEmpty)
        XCTAssertEqual(malformed.decodeFailures.first?.error?.message.contains("error.machineReason"), true)
    }

    private func deliverSendFailed(_ payload: [String: Any]) async throws -> SendFailedBox {
        let bridge = EventBridge()
        let events = DefaultEventsApi(bridge: bridge)
        let box = SendFailedBox()
        _ = events.onMessageSendFailed { event in box.events.append(event) }
        _ = events.onInitFailed { event in box.decodeFailures.append(event) }
        _ = try await events.subscribeEvents([:])
        bridge.emit(eventType: EventCode.messageSendFailed, payload: payload)
        return box
    }
}

private func assertRequired(
    _ field: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ decode: () throws -> Void
) {
    XCTAssertThrowsError(try decode(), file: file, line: line) { error in
        XCTAssertEqual((error as? FlareSdkException)?.message, "\(field) is required", file: file, line: line)
    }
}

private func assertUnknownPerson(_ name: DisplayName?, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(name?.kind, .unnamed, file: file, line: line)
    XCTAssertEqual(name?.entity, .person, file: file, line: line)
    XCTAssertEqual(name?.idTail, "", file: file, line: line)
}

/// Whether an encoded name carries exactly the wire fields of the vector.
private func wireEquals(_ encoded: [String: AnySendable]?, _ expected: [String: Any]) -> Bool {
    guard let encoded else { return false }
    return (encoded.mapValues { $0.value } as NSDictionary).isEqual(to: expected)
}

private func goldenRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("sdk-spec/golden")
}

private func golden(_ relative: String) throws -> [String: Any] {
    let data = try Data(contentsOf: goldenRoot().appendingPathComponent(relative))
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func projectedNames() throws -> [(String, [String: Any])] {
    let vectors = try golden("display-name-projection.json")
    let cases = ((vectors["people"] as? [[String: Any]]) ?? []) + ((vectors["conversations"] as? [[String: Any]]) ?? [])
    XCTAssertFalse(cases.isEmpty)
    return try cases.map { vector in
        (vector["name"] as? String ?? "", try XCTUnwrap(vector["expected"] as? [String: Any]))
    }
}

private func participant(_ userId: String, name: [String: Any]? = nil) -> [String: Any] {
    var json: [String: Any] = [
        "userId": userId,
        "roles": [String](),
        "muted": false,
        "pinned": false,
        "attributes": [String: String](),
        "joinedAt": 0,
        "nickname": "",
    ]
    if let name { json["name"] = name }
    return json
}

private final class SendFailedBox: @unchecked Sendable {
    var events: [MessageSendFailedEvent] = []
    var decodeFailures: [LifecycleEvent] = []
}

private final class EventBridge: NativeBridgeProtocol {
    private var handler: ((Int, Any?) -> Void)?

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        if descriptor.operation == SdkOperations.eventSubscribe || descriptor.operation == SdkOperations.eventSubscribeBatch {
            handler = (request?.value as? [String: Any])?["handler"] as? (Int, Any?) -> Void
        }
        return AnySendable([String: Any]())
    }

    func emit(eventType: Int, payload: [String: Any]) {
        handler?(eventType, payload)
    }
}
