import FlarePlatformUpdate
import XCTest
@testable import FlareCoreAppleSDK

private final class Received: @unchecked Sendable {
    var payloads: [[String: Any]] = []
}

final class ClientUpdateEngineTests: XCTestCase {
    private let status = UpdateStatus(
        state: "downloading",
        current: UpdateCurrentApp(version: "2.3.2", build: 20302, channel: "stable", distribution: "direct"),
        release: UpdateReleaseSummary(
            releaseId: "rel_01JC8W",
            version: "2.4.0",
            build: 20400,
            notes: ["Scheduled messages"],
            sizeBytes: 52428800,
            mandatory: true,
            kind: "package"
        ),
        progress: UpdateProgress(received: 1048576, total: 52428800),
        prompt: "modal",
        blockUi: true,
        readOnly: true,
        lastCheckedAt: 1793871062839,
        error: UpdateErrorInfo(code: "update.hashMismatch", retryable: true, fallbackUrl: "https://example.com"),
        blockReason: "No longer supported"
    )

    /// What the controller reads is what the client said: the models' property names are the wire's.
    func testAStatusSurvivesTheWayToTheController() throws {
        let read = try FlareUpdateStatus(wire: clientUpdateWire(status))

        XCTAssertEqual(read.state, .downloading)
        XCTAssertEqual(read.current, FlareUpdateCurrent(version: "2.3.2", build: 20302, channel: "stable", distribution: "direct"))
        XCTAssertEqual(read.release?.version, "2.4.0")
        XCTAssertEqual(read.release?.build, 20400)
        XCTAssertEqual(read.release?.notes, ["Scheduled messages"])
        XCTAssertEqual(read.release?.sizeBytes, 52428800)
        XCTAssertEqual(read.release?.mandatory, true)
        XCTAssertEqual(read.release?.kind, .package)
        XCTAssertEqual(read.progress, FlareUpdateProgress(received: 1048576, total: 52428800))
        XCTAssertEqual(read.prompt, .modal)
        XCTAssertTrue(read.blockUi)
        XCTAssertTrue(read.readOnly)
        XCTAssertEqual(read.blockReason, "No longer supported")
        XCTAssertEqual(read.lastCheckedAt, 1793871062839)
        XCTAssertEqual(read.error, FlareUpdateError(code: "update.hashMismatch", retryable: true, fallbackUrl: "https://example.com"))
    }

    func testResourcePacksSurviveTheWayToTheController() throws {
        let resources = UpdateResources(
            packs: [UpdateResourcePack(id: "strings", kind: "strings", packVersion: 3, contentJson: "{}")]
        )
        XCTAssertEqual(
            try FlareUpdateResourcePack.list(wire: clientUpdateWire(resources)),
            [FlareUpdateResourcePack(id: "strings", kind: "strings", packVersion: 3, contentJson: "{}")]
        )
    }

    func testAStorePlanSurvivesTheWayToTheInstaller() throws {
        let plan = UpdateInstallPlan(kind: "openStore", store: "appstore", url: "itms-apps://a", immediate: false)
        XCTAssertEqual(
            try FlareUpdateInstallPlan(wire: clientUpdateWire(plan)),
            .openStore(FlareUpdateStoreTarget(store: "appstore", url: "itms-apps://a"))
        )
    }

    /// A forced prompt can stand before the manifest arrives, with no release to name.
    func testBuildIsAbsentWithoutARelease() {
        XCTAssertEqual(clientUpdateBuild(["build": Int64(20400)]), 20400)
        XCTAssertNil(clientUpdateBuild(["form": "modal"]))
    }

    func testAnEventReachesTheControllerUntilItUnsubscribes() {
        let engine = ClientUpdateEngine(client: { throw FlareUpdateWireError(field: "client") })
        let received = Received()

        let unsubscribe = engine.subscribeState { payload in received.payloads.append(payload) }
        engine.receive(status)
        unsubscribe()
        engine.receive(status)

        XCTAssertEqual(received.payloads.count, 1)
        XCTAssertEqual(received.payloads.first?["state"] as? String, "downloading")
    }
}
