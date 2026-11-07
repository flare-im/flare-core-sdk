import FlareIMUI
import FlarePlatformUpdate
import XCTest
@testable import FlareUpdateUI

final class FlareUpdateUITests: XCTestCase {
    private let release = FlareUpdateRelease(releaseId: "rel_01JC8W", version: "2.4.0", build: 20400, kind: .package)

    private func status(
        state: FlareUpdateState = .available,
        prompt: FlarePlatformUpdate.FlareUpdatePromptForm = .none,
        release: FlareUpdateRelease? = nil,
        distribution: String = "direct"
    ) -> FlareUpdateStatus {
        FlareUpdateStatus(
            state: state,
            current: FlareUpdateCurrent(version: "2.3.2", build: 20302, distribution: distribution),
            release: release,
            prompt: prompt
        )
    }

    func testTheThreeFormsReachTheKit() {
        XCTAssertEqual(status(prompt: .sheet).kitPromptForm, FlareIMUI.FlareUpdatePromptForm.sheet)
        XCTAssertEqual(status(prompt: .modal).kitPromptForm, FlareIMUI.FlareUpdatePromptForm.modal)
        XCTAssertEqual(status(prompt: .fullscreen).kitPromptForm, FlareIMUI.FlareUpdatePromptForm.fullscreen)
    }

    func testABadgeAndNoneAreNoPrompt() {
        XCTAssertNil(status(prompt: .badge).kitPromptForm)
        XCTAssertNil(status(prompt: .none).kitPromptForm)
    }

    /// The server can refuse this build before the manifest arrives: forced, and no target version to name.
    func testARefusalBeforeTheManifestIsForcedAndNamesTheRunningVersion() {
        let refused = status(state: .required)
        XCTAssertTrue(refused.kitMandatory)
        XCTAssertEqual(refused.kitVersion, "2.3.2")
    }

    func testAnOptionalReleaseIsNotForced() {
        XCTAssertFalse(status(release: release).kitMandatory)
        XCTAssertEqual(status(release: release).kitVersion, "2.4.0")
    }

    func testTheFallbackGoesToTheWebsiteOnlyOnADirectInstall() {
        XCTAssertEqual(status().kitFallbackTarget, FlareIMUI.FlareUpdateFallbackTarget.website)
        XCTAssertEqual(status(distribution: "appstore").kitFallbackTarget, FlareIMUI.FlareUpdateFallbackTarget.store)
    }

    func testProgressKeepsAnUnknownTotal() {
        var downloading = status()
        downloading.progress = FlarePlatformUpdate.FlareUpdateProgress(received: 10, total: nil)
        XCTAssertEqual(downloading.kitProgress, FlareIMUI.FlareUpdateProgress(received: 10, total: nil))
        XCTAssertNil(status().kitProgress)
    }
}

private let stringsPack: [String: Any] = [
    "id": "strings",
    "kind": "strings",
    "packVersion": 3,
    "contentJson": #"{"schema":"flare.resource.v1","kind":"strings","locales":{"en":{"send":"Send it"}}}"#,
]

/// Answers the status and the packs; counts how often the packs are read.
private final class PackEngine: FlareUpdateEngine, @unchecked Sendable {
    private let lock = NSLock()
    private let packs: [[String: Any]]
    private var count = 0

    init(packs: [[String: Any]]) {
        self.packs = packs
    }

    var reads: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    private func countRead() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    func dispatch(_ operation: String, params: [String: Any]) async throws -> [String: Any] {
        guard operation == FlareUpdateOperation.getResources else { return ["state": "idle"] }
        countRead()
        return ["packs": packs]
    }

    func subscribeState(_ onState: @escaping @Sendable ([String: Any]) -> Void) -> @Sendable () -> Void {
        {}
    }
}

@MainActor
final class FlareUpdateResourcesTests: XCTestCase {
    func testAPackReachesTheKitAsIs() {
        let pack = FlareUpdateResourcePack(id: "strings", kind: "strings", packVersion: 3, contentJson: "{}")
        XCTAssertEqual(pack.kitPack.id, "strings")
        XCTAssertEqual(pack.kitPack.kind, "strings")
        XCTAssertEqual(pack.kitPack.packVersion, 3)
        XCTAssertEqual(pack.kitPack.contentJson, "{}")
    }

    /// `update.*` needs `init`, and the first status is what says the engine is up.
    func testTheOverlayWaitsForTheEngine() async {
        let engine = PackEngine(packs: [stringsPack])
        let controller = FlareUpdateController(engine: engine)
        let resources = FlareUpdateResources()

        let loading = Task { await resources.load(from: controller) }
        await Task.yield()
        XCTAssertEqual(engine.reads, 0)

        controller.install()
        await loading.value

        XCTAssertEqual(engine.reads, 1)
        XCTAssertFalse(resources.overlay.isEmpty)
        XCTAssertEqual(resources.strings(over: FlareStrings(), locale: "en").send, "Send it")
        controller.dispose()
    }

    /// The app's own strings and what a session formats read no Kit environment: the host hears of it once.
    func testTheHostHearsOfTheOverlay() async {
        let engine = PackEngine(packs: [stringsPack])
        let controller = FlareUpdateController(engine: engine).install()
        let resources = FlareUpdateResources()
        var heard: [Bool] = []

        await resources.load(from: controller) { heard.append($0.isEmpty) }
        await resources.load(from: controller) { heard.append($0.isEmpty) }

        XCTAssertEqual(heard, [false])
        controller.dispose()
    }

    func testNoPacksSayNothingToTheHost() async {
        let engine = PackEngine(packs: [])
        let controller = FlareUpdateController(engine: engine).install()
        let resources = FlareUpdateResources()
        var heard = 0

        await resources.load(from: controller) { _ in heard += 1 }

        XCTAssertEqual(heard, 0)
        controller.dispose()
    }

    func testTheResourcesAreReadOnce() async {
        let engine = PackEngine(packs: [stringsPack])
        let controller = FlareUpdateController(engine: engine).install()
        let resources = FlareUpdateResources()

        await resources.load(from: controller)
        await resources.load(from: controller)

        XCTAssertEqual(engine.reads, 1)
        controller.dispose()
    }

    func testNoPacksLeaveTheBuiltInResources() async {
        let controller = FlareUpdateController(engine: PackEngine(packs: [])).install()
        let resources = FlareUpdateResources()

        await resources.load(from: controller)

        XCTAssertTrue(resources.overlay.isEmpty)
        XCTAssertEqual(resources.strings(over: FlareStrings(), locale: "en").send, FlareStrings().send)
        XCTAssertEqual(resources.brand(over: .violet), .violet)
        controller.dispose()
    }

    /// A new language asks the overlay again; the same one does not.
    func testStringsFollowTheLanguage() async {
        let controller = FlareUpdateController(engine: PackEngine(packs: [stringsPack])).install()
        let resources = FlareUpdateResources()
        await resources.load(from: controller)

        XCTAssertEqual(resources.strings(over: FlareStrings(), locale: "en").send, "Send it")
        XCTAssertEqual(resources.strings(over: FlareStrings(), locale: "zh-CN").send, FlareStrings().send)
        controller.dispose()
    }
}
