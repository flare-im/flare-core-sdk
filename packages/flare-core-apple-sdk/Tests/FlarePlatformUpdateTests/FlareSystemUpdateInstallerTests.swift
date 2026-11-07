import XCTest
@testable import FlarePlatformUpdate

final class FlareSystemUpdateInstallerTests: XCTestCase {
    private final class Opener: @unchecked Sendable {
        private let lock = NSLock()
        private var seen: [URL] = []
        private let accepts: @Sendable (URL) -> Bool

        init(accepts: @escaping @Sendable (URL) -> Bool) {
            self.accepts = accepts
        }

        func open(_ url: URL) -> Bool {
            lock.lock()
            seen.append(url)
            lock.unlock()
            return accepts(url)
        }

        var urls: [String] {
            lock.lock()
            defer { lock.unlock() }
            return seen.map(\.absoluteString)
        }
    }

    private func installer(_ opener: Opener) -> FlareSystemUpdateInstaller {
        FlareSystemUpdateInstaller(open: { opener.open($0) })
    }

    /// The manifest's link is the one to open; the rest of the release is the store's.
    func testOpensTheManifestLink() async {
        let opener = Opener(accepts: { _ in true })
        let plan = FlareUpdateInstallPlan.openStore(
            FlareUpdateStoreTarget(store: "appstore", url: "itms-apps://apps.apple.com/app/id123", appId: "123")
        )
        let result = await installer(opener).execute(plan)
        XCTAssertEqual(result, FlareUpdateInstallResult(outcome: .completed))
        XCTAssertEqual(opener.urls, ["itms-apps://apps.apple.com/app/id123"])
    }

    func testAnAppIdGivesTheStoreAppThenItsWebPage() {
        let urls = FlareSystemUpdateInstaller.urls(for: FlareUpdateStoreTarget(store: "appstore", appId: "123"))
            .map(\.absoluteString)
        #if os(macOS)
        XCTAssertEqual(urls, ["macappstore://apps.apple.com/app/id123", "https://apps.apple.com/app/id123"])
        #else
        XCTAssertEqual(urls, ["itms-apps://apps.apple.com/app/id123", "https://apps.apple.com/app/id123"])
        #endif
    }

    func testTestFlightGoesToItsApp() {
        let urls = FlareSystemUpdateInstaller.urls(for: FlareUpdateStoreTarget(store: "testflight", appId: "123"))
            .map(\.absoluteString)
        XCTAssertEqual(urls, [
            "itms-beta://beta.itunes.apple.com/v1/app/123",
            "https://beta.itunes.apple.com/v1/app/123",
        ])
    }

    /// Without the TestFlight app the web page is the way in.
    func testFallsThroughToTheNextLink() async {
        let opener = Opener(accepts: { $0.scheme == "https" })
        let plan = FlareUpdateInstallPlan.openStore(FlareUpdateStoreTarget(store: "testflight", appId: "123"))
        let result = await installer(opener).execute(plan)
        XCTAssertEqual(result.outcome, .completed)
        XCTAssertEqual(opener.urls.count, 2)
    }

    func testFailsWhenNothingOpens() async {
        let opener = Opener(accepts: { _ in false })
        let plan = FlareUpdateInstallPlan.openStore(FlareUpdateStoreTarget(store: "appstore", appId: "123"))
        let result = await installer(opener).execute(plan)
        XCTAssertEqual(result, .failed(FlareUpdateErrorCode.installFailed))
    }

    func testFailsWithoutALinkOrAppId() async {
        let opener = Opener(accepts: { _ in true })
        let result = await installer(opener).execute(.openStore(FlareUpdateStoreTarget(store: "appstore")))
        XCTAssertEqual(result, .failed(FlareUpdateErrorCode.installFailed))
        XCTAssertTrue(opener.urls.isEmpty)
    }

    /// Apple platforms have no way to install a package: the plan fails, nothing is opened.
    func testAPlanForAnotherPlatformFails() async {
        let opener = Opener(accepts: { _ in true })
        let result = await installer(opener).execute(.unsupported(kind: "installPackage"))
        XCTAssertEqual(result, .failed(FlareUpdateErrorCode.installFailed))
        XCTAssertTrue(opener.urls.isEmpty)
    }

    /// A website fallback is that link alone.
    func testAWebsiteIsItsLink() {
        let target = FlareUpdateStoreTarget(store: FlareUpdateStoreTarget.website, url: "https://example.com/download")
        XCTAssertEqual(FlareSystemUpdateInstaller.urls(for: target).map(\.absoluteString), ["https://example.com/download"])
    }
}
