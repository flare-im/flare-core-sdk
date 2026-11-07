import XCTest
@testable import FlarePlatformUpdate

final class FlareUpdateWireTests: XCTestCase {
    private func json(_ text: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    /// The full payload of the interface document.
    func testReadsAFullStatus() throws {
        let status = try FlareUpdateStatus(wire: json("""
        {
          "state": "downloading",
          "current": {"version": "2.3.2", "build": 20302, "channel": "stable", "distribution": "direct"},
          "release": {"releaseId": "rel_01JC8W", "version": "2.4.0", "build": 20400, "notes": ["a", "b"],
                      "sizeBytes": 52428800, "mandatory": false, "recommended": true, "kind": "package"},
          "progress": {"received": 1048576, "total": 52428800},
          "prompt": "sheet",
          "blockUi": false,
          "readOnly": true,
          "lastCheckedAt": 1793871062839,
          "error": {"code": "update.hashMismatch", "retryable": true, "fallbackUrl": "https://example.com"}
        }
        """))

        XCTAssertEqual(status.state, .downloading)
        XCTAssertEqual(status.current.build, 20302)
        XCTAssertEqual(status.release?.notes, ["a", "b"])
        XCTAssertEqual(status.release?.kind, .package)
        XCTAssertEqual(status.release?.recommended, true)
        XCTAssertEqual(status.progress, FlareUpdateProgress(received: 1048576, total: 52428800))
        XCTAssertEqual(status.prompt, .sheet)
        XCTAssertTrue(status.readOnly)
        XCTAssertEqual(status.lastCheckedAt, 1793871062839)
        XCTAssertEqual(
            status.error,
            FlareUpdateError(code: "update.hashMismatch", retryable: true, fallbackUrl: "https://example.com")
        )
    }

    /// JSON null arrives as `NSNull`; it must read as absent.
    func testReadsNullsAsAbsent() throws {
        let status = try FlareUpdateStatus(wire: json("""
        {"state": "idle", "release": null, "progress": null, "lastCheckedAt": null, "error": null}
        """))
        XCTAssertNil(status.release)
        XCTAssertNil(status.progress)
        XCTAssertNil(status.lastCheckedAt)
        XCTAssertNil(status.error)
    }

    func testRefusesAnUnknownState() {
        XCTAssertThrowsError(try FlareUpdateStatus(wire: ["state": "unheardOf"]))
    }

    func testReadsTheStorePlan() throws {
        let plan = try FlareUpdateInstallPlan(wire: json("""
        {"kind": "openStore", "store": "appstore", "url": "itms-apps://apps.apple.com/app/id1", "packageName": null, "appId": "1", "immediate": false}
        """))
        XCTAssertEqual(plan, .openStore(FlareUpdateStoreTarget(
            store: "appstore",
            url: "itms-apps://apps.apple.com/app/id1",
            appId: "1"
        )))
    }

    /// Another platform's plan is a value, not a crash: the installer fails it and reports.
    func testKeepsAPlanForAnotherPlatform() throws {
        XCTAssertEqual(
            try FlareUpdateInstallPlan(wire: ["kind": "installPackage", "path": "/tmp/a.apk"]),
            .unsupported(kind: "installPackage")
        )
    }

    func testTheReportCarriesTheCodeOnlyWhenThereIsOne() {
        let failed = FlareUpdateInstallResult.failed("update.installFailed").reportParams
        XCTAssertEqual(failed["outcome"] as? String, "failed")
        XCTAssertEqual(failed["code"] as? String, "update.installFailed")
        XCTAssertNil(FlareUpdateInstallResult(outcome: .started).reportParams["code"])
    }

    /// The direct channel falls back to the website, every other one to its store.
    func testTheFallbackTargetFollowsTheDistribution() {
        XCTAssertEqual(
            FlareUpdateStatus(state: .failed, current: FlareUpdateCurrent(distribution: "direct")).fallbackTarget,
            .website
        )
        XCTAssertEqual(
            FlareUpdateStatus(state: .failed, current: FlareUpdateCurrent(distribution: "appstore")).fallbackTarget,
            .store
        )
    }
}
