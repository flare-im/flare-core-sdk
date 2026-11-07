import Foundation
import XCTest
@testable import FlareCoreAppleSDK

/// The engine's link status vectors (`flare-core-sdk-engine/tests/vectors/link_status.json`): each case's
/// `expected` is a `connection://status` payload exactly as the core puts it on the wire. Every platform
/// package decodes the same file.
final class LinkStatusVectorTests: XCTestCase {
    private static let fields: Set<String> = [
        "phase", "quality", "accessPointId", "cellId", "regionId", "protocol",
        "rttMs", "attempt", "nextRetryAt", "reason", "developmentMode",
    ]

    func testVectorsCoverEveryPublicPhase() throws {
        let cases = try vectors()
        XCTAssertGreaterThanOrEqual(cases.count, 22, "the shared vectors lost cases")
        let phases = Set(cases.compactMap { $0.expected["phase"] as? String })
        XCTAssertEqual(phases, Set(Self.publicPhases.map(\.rawValue)))
        for vector in cases {
            XCTAssertEqual(Set(vector.expected.keys), Self.fields, vector.name)
        }
        XCTAssertTrue(Self.publicPhases.allSatisfy(Self.listed))
    }

    func testEveryVectorDecodes() throws {
        for vector in try vectors() {
            let decoded = try connectionStatusFromJson(jsonObjectMap(vector.expected))
            assertMatches(decoded, vector)
        }
    }

    func testEveryVectorReachesTheStatusListener() async throws {
        for vector in try vectors() {
            let bridge = VectorEventBridge()
            let events = DefaultEventsApi(bridge: bridge)
            _ = try await events.subscribeEvents([:])
            let box = StatusBox()
            _ = events.onConnectionStatusChanged { box.statuses.append($0) }

            var payload = vector.expected
            payload["type"] = "connection"
            payload["event"] = "status"
            bridge.emit(eventType: EventCode.connectionStatus, payload: payload)

            XCTAssertEqual(box.statuses.count, 1, vector.name)
            if let status = box.statuses.first { assertMatches(status, vector) }
        }
    }

    func testUnknownPhaseIsRejectedNotGuessed() async throws {
        var unknown = try XCTUnwrap(vectors().first).expected
        unknown["phase"] = "halfOpen"

        XCTAssertThrowsError(try connectionStatusFromJson(jsonObjectMap(unknown))) { error in
            XCTAssertEqual((error as? FlareSdkException)?.code, SdkErrorCodes.invalidParameter)
        }

        // On the event path the status listener hears nothing; the decode failure is reported instead.
        let bridge = VectorEventBridge()
        let events = DefaultEventsApi(bridge: bridge)
        _ = try await events.subscribeEvents([:])
        let box = StatusBox()
        _ = events.onConnectionStatusChanged { box.statuses.append($0) }
        _ = events.onInitFailed { box.failures.append($0) }

        bridge.emit(eventType: EventCode.connectionStatus, payload: unknown)

        XCTAssertTrue(box.statuses.isEmpty)
        XCTAssertEqual(box.failures.map(\.operation), ["event.decode"])
    }

    // MARK: - helpers

    private static let publicPhases: [ConnectionPhase] = [
        .idle, .connecting, .syncing, .online, .switching, .reconnecting, .waitingForNetwork,
        .serviceUnavailable, .actionRequired,
    ]

    /// Exhaustive on purpose: a phase added to the contract stops this compiling until `publicPhases` lists it.
    private static func listed(_ phase: ConnectionPhase) -> Bool {
        switch phase {
        case .idle, .connecting, .syncing, .online, .switching, .reconnecting, .waitingForNetwork,
             .serviceUnavailable, .actionRequired:
            return publicPhases.contains(phase)
        }
    }

    private struct Vector {
        let name: String
        let expected: [String: Any]
    }

    private func vectors() throws -> [Vector] {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("flare-core-sdk-engine/tests/vectors/link_status.json")
        let table = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any], "unreadable \(url.path)")
        let cases = try XCTUnwrap(table["cases"] as? [[String: Any]])
        return try cases.map {
            Vector(name: try XCTUnwrap($0["name"] as? String), expected: try XCTUnwrap($0["expected"] as? [String: Any]))
        }
    }

    private func assertMatches(_ status: ConnectionStatus, _ vector: Vector, line: UInt = #line) {
        let expected = vector.expected
        func string(_ key: String) -> String? { expected[key] as? String }
        func number(_ key: String) -> Int64? { (expected[key] as? NSNumber)?.int64Value }
        let name = vector.name
        XCTAssertEqual(status.phase.rawValue, string("phase"), name, line: line)
        XCTAssertEqual(status.quality?.rawValue, string("quality"), name, line: line)
        XCTAssertEqual(status.accessPointId, string("accessPointId"), name, line: line)
        XCTAssertEqual(status.cellId, string("cellId"), name, line: line)
        XCTAssertEqual(status.regionId, string("regionId"), name, line: line)
        XCTAssertEqual(status.protocol, string("protocol"), name, line: line)
        XCTAssertEqual(status.rttMs.map(Int64.init), number("rttMs"), name, line: line)
        XCTAssertEqual(Int64(status.attempt), number("attempt"), name, line: line)
        XCTAssertEqual(status.nextRetryAt, number("nextRetryAt"), name, line: line)
        XCTAssertEqual(status.reason, string("reason"), name, line: line)
        XCTAssertEqual(status.developmentMode, expected["developmentMode"] as? Bool, name, line: line)
    }
}

private final class StatusBox: @unchecked Sendable {
    var statuses: [ConnectionStatus] = []
    var failures: [LifecycleEvent] = []
}

/// Hands events to the subscribed handler as the FFI bridge does: the JSON text decoded to plain values.
private final class VectorEventBridge: NativeBridgeProtocol, @unchecked Sendable {
    private var handler: ((Int, Any?) -> Void)?

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        if descriptor.operation == SdkOperations.eventSubscribe || descriptor.operation == SdkOperations.eventSubscribeBatch {
            handler = (request?.value as? [String: Any])?["handler"] as? (Int, Any?) -> Void
        }
        return AnySendable([String: Any]())
    }

    func emit(eventType: Int, payload: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: payload)
        handler?(eventType, FfiJson.decode(String(decoding: data, as: UTF8.self)))
    }
}
