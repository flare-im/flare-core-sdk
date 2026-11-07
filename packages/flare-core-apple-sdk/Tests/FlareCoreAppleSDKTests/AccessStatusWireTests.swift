import Foundation
import XCTest
@testable import FlareCoreAppleSDK

/// `access.get_status` as the FFI bridge hands it over: JSON text decoded to plain values (null is NSNull).
final class AccessStatusWireTests: XCTestCase {
    func testReadsTheConnectAckDiagnostics() throws {
        let status = try decode(connectAck: """
        {"gatewayId":"gw-7","accessPointId":"ap-sg-2","accessSerial":43,"heartbeatIntervalHintSec":25,
         "accessPointMismatch":true}
        """)

        let ack = try XCTUnwrap(status.connectAck)
        XCTAssertEqual(ack.gatewayId, "gw-7")
        XCTAssertEqual(ack.accessPointId, "ap-sg-2")
        XCTAssertEqual(ack.accessSerial, 43)
        XCTAssertEqual(ack.heartbeatIntervalHintSec, 25)
        XCTAssertTrue(ack.accessPointMismatch)
        XCTAssertEqual(status.accessPointId, "ap-sg-1")
    }

    func testKeepsAbsentConnectAckFieldsNil() throws {
        let ack = try XCTUnwrap(decode(connectAck: """
        {"gatewayId":null,"accessPointId":null,"accessSerial":null,"heartbeatIntervalHintSec":null,
         "accessPointMismatch":false}
        """).connectAck)

        XCTAssertNil(ack.gatewayId)
        XCTAssertNil(ack.accessPointId)
        XCTAssertNil(ack.accessSerial)
        XCTAssertNil(ack.heartbeatIntervalHintSec)
        XCTAssertFalse(ack.accessPointMismatch)
    }

    func testHasNoConnectAckWithoutAConnection() throws {
        XCTAssertNil(try decode(connectAck: "null").connectAck)
    }

    func testReadsTheManifestTimesRefreshProgressAndRecovery() throws {
        let status = try decode(
            issuedAtMs: "1793779200000",
            expiresAtMs: "1796371200000",
            fetchedAtMs: "1793779260000",
            refresh: """
            {"lastAttemptAtMs":1793779260000,"lastSuccessAtMs":1793779200000,"lastOutcome":"adopted",
             "nextAtMs":1793800860000}
            """,
            recovering: """
            {"sinceMs":1793779000000,"rounds":2,"nextRoundAtMs":1793779090000}
            """
        )

        XCTAssertEqual(status.issuedAtMs, 1_793_779_200_000)
        XCTAssertEqual(status.expiresAtMs, 1_796_371_200_000)
        XCTAssertEqual(status.fetchedAtMs, 1_793_779_260_000)
        let refresh = try XCTUnwrap(status.refresh)
        XCTAssertEqual(refresh.lastAttemptAtMs, 1_793_779_260_000)
        XCTAssertEqual(refresh.lastSuccessAtMs, 1_793_779_200_000)
        XCTAssertEqual(refresh.lastOutcome, "adopted")
        XCTAssertEqual(refresh.nextAtMs, 1_793_800_860_000)
        let recovering = try XCTUnwrap(status.recovering)
        XCTAssertEqual(recovering.sinceMs, 1_793_779_000_000)
        XCTAssertEqual(recovering.rounds, 2)
        XCTAssertEqual(recovering.nextRoundAtMs, 1_793_779_090_000)
    }

    func testKeepsAbsentRefreshAndRecoveryFieldsNil() throws {
        let status = try decode(
            refresh: """
            {"lastAttemptAtMs":null,"lastSuccessAtMs":null,"lastOutcome":null,"nextAtMs":null}
            """,
            recovering: """
            {"sinceMs":5,"rounds":0,"nextRoundAtMs":null}
            """
        )

        XCTAssertNil(status.issuedAtMs)
        XCTAssertNil(status.fetchedAtMs)
        XCTAssertNil(try XCTUnwrap(status.refresh).lastOutcome)
        XCTAssertNil(try XCTUnwrap(status.refresh).nextAtMs)
        XCTAssertNil(try XCTUnwrap(status.recovering).nextRoundAtMs)
        XCTAssertNil(try decode().refresh)
        XCTAssertNil(try decode().recovering)
    }

    func testRefreshReportsEverySourceItTried() async throws {
        let bridge = AccessAnswerBridge(answers: ["access.refresh": """
        {"outcome":"adopted","mode":"background","serial":42,"source":"https:https://cfg-b/","keystateSerial":3,
         "attempts":[
           {"source":"https:https://cfg-a/","tier":"mirror","document":"access","result":"failed","code":"timeout",
            "serial":null},
           {"source":"https:https://cfg-b/","tier":"mirror","document":"access","result":"adopted","code":null,
            "serial":42}]}
        """])

        let report = try await DefaultAccessApi(bridge: bridge).refresh()

        XCTAssertEqual(bridge.operations, ["access.refresh"])
        XCTAssertEqual(report.outcome, "adopted")
        XCTAssertEqual(report.mode, "background")
        XCTAssertEqual(report.serial, 42)
        XCTAssertEqual(report.source, "https:https://cfg-b/")
        XCTAssertEqual(report.keystateSerial, 3)
        XCTAssertEqual(report.attempts.map(\.result), ["failed", "adopted"])
        XCTAssertEqual(report.attempts.first?.code, "timeout")
        XCTAssertNil(report.attempts.first?.serial)
        XCTAssertNil(report.attempts.last?.code)
        XCTAssertEqual(report.attempts.last?.serial, 42)
    }

    func testARefreshWithoutAttemptsIsRefused() async {
        let bridge = AccessAnswerBridge(answers: ["access.refresh": """
        {"outcome":"failed","mode":"background","serial":0}
        """])

        do {
            _ = try await DefaultAccessApi(bridge: bridge).refresh()
            XCTFail("a report without attempts decoded")
        } catch {
            XCTAssertEqual((error as? FlareSdkException)?.code, SdkErrorCodes.invalidParameter)
        }
    }

    func testARecoveryLinkGoesVerbatimAndABadOneIsAnAnswer() async throws {
        let link = "flare-recover://v1?p=abc&k=root-a&s=def"
        let bridge = AccessAnswerBridge(answers: ["access.import_recovery": """
        {"outcome":"rejected","code":"rollback","serial":42}
        """])

        let imported = try await DefaultAccessApi(bridge: bridge)
            .importRecovery(AccessImportRecoveryRequest(link: link))

        XCTAssertEqual(bridge.operations, ["access.import_recovery"])
        XCTAssertEqual(bridge.requests.first?["link"] as? String, link)
        XCTAssertEqual(imported.outcome, "rejected")
        XCTAssertEqual(imported.code, "rollback")
        XCTAssertEqual(imported.serial, 42)
    }

    func testAnAdoptedRecoveryLinkHasNoCode() async throws {
        let bridge = AccessAnswerBridge(answers: ["access.import_recovery": """
        {"outcome":"adopted","code":null,"serial":2000}
        """])

        let imported = try await DefaultAccessApi(bridge: bridge)
            .importRecovery(AccessImportRecoveryRequest(link: "flare-recover://v1?p=a&k=b&s=c"))

        XCTAssertEqual(imported.outcome, "adopted")
        XCTAssertNil(imported.code)
        XCTAssertEqual(imported.serial, 2000)
    }

    private func decode(
        connectAck: String = "null",
        issuedAtMs: String = "null",
        expiresAtMs: String = "null",
        fetchedAtMs: String = "null",
        refresh: String = "null",
        recovering: String = "null"
    ) throws -> AccessStatus {
        let json = """
        {"loaded":true,"serial":42,"source":"seed","stale":false,"developmentMode":false,
         "issuedAtMs":\(issuedAtMs),"expiresAtMs":\(expiresAtMs),"fetchedAtMs":\(fetchedAtMs),
         "regionId":"sg","cellId":"cell-sg-a","keystateSerial":null,"accessPointId":"ap-sg-1","protocol":"quic",
         "pinned":null,"connectAck":\(connectAck),"refresh":\(refresh),"recovering":\(recovering)}
        """
        return try accessStatusFromJson(jsonObjectMap(FfiJson.decode(json)))
    }
}

/// Answers each operation with its JSON text, decoded the way the FFI bridge hands it over.
private final class AccessAnswerBridge: NativeBridgeProtocol, @unchecked Sendable {
    private let answers: [String: String]
    private(set) var operations: [String] = []
    private(set) var requests: [[String: Any]] = []

    init(answers: [String: String]) {
        self.answers = answers
    }

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        operations.append(descriptor.operation)
        requests.append(request?.value as? [String: Any] ?? [:])
        return AnySendable(FfiJson.decode(answers[descriptor.operation] ?? "{}") ?? [String: Any]())
    }
}
