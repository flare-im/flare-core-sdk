import FlarePlatformLifecycle
import XCTest
@testable import FlarePlatformUpdate

private func releaseWire(mandatory: Bool = false, kind: String = "package") -> [String: Any] {
    [
        "releaseId": "rel_01JC8W",
        "version": "2.4.0",
        "build": 20400,
        "notes": ["Scheduled messages"],
        "mandatory": mandatory,
        "recommended": false,
        "kind": kind,
    ]
}

private func status(
    _ state: String,
    release releaseValue: [String: Any]? = releaseWire(),
    prompt: String = "none",
    blockUi: Bool = false,
    readOnly: Bool = false,
    blockReason: String? = nil,
    error: [String: Any]? = nil,
    distribution: String = "appstore"
) -> [String: Any] {
    var wire: [String: Any] = [
        "state": state,
        "current": ["version": "2.3.2", "build": 20302, "channel": "stable", "distribution": distribution],
        "prompt": prompt,
        "blockUi": blockUi,
        "readOnly": readOnly,
    ]
    wire["release"] = releaseValue
    wire["blockReason"] = blockReason
    wire["error"] = error
    return wire
}

private let storePlan: [String: Any] = ["kind": "openStore", "store": "appstore", "url": "itms-apps://a", "immediate": false]

/// Answers each route with what the test set, and records every call.
private final class FakeEngine: FlareUpdateEngine, @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [String: [String: Any]] = [:]
    private var refusals: [String: FlareUpdateException] = [:]
    private var listener: (@Sendable ([String: Any]) -> Void)?
    private(set) var calls: [(operation: String, params: [String: Any])] = []
    private(set) var closed = false

    func answer(_ operation: String, _ payload: [String: Any]) {
        lock.lock()
        answers[operation] = payload
        lock.unlock()
    }

    func refuse(_ operation: String, _ refusal: FlareUpdateException) {
        lock.lock()
        refusals[operation] = refusal
        lock.unlock()
    }

    func dispatch(_ operation: String, params: [String: Any]) async throws -> [String: Any] {
        try record(operation, params)
    }

    private func record(_ operation: String, _ params: [String: Any]) throws -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        calls.append((operation, params))
        if let refusal = refusals.removeValue(forKey: operation) {
            throw refusal
        }
        return answers[operation] ?? answers[FlareUpdateOperation.getState] ?? [:]
    }

    func subscribeState(_ onState: @escaping @Sendable ([String: Any]) -> Void) -> @Sendable () -> Void {
        lock.lock()
        listener = onState
        lock.unlock()
        return { [self] in
            lock.lock()
            closed = true
            lock.unlock()
        }
    }

    func emit(_ payload: [String: Any]) {
        lock.lock()
        let listener = listener
        lock.unlock()
        listener?(payload)
    }

    func count(_ operation: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return calls.filter { $0.operation == operation }.count
    }

    func routes() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return calls.map { $0.operation }
    }

    func params(of operation: String) -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return calls.filter { $0.operation == operation }.map { $0.params }
    }
}

private final class FakeInstaller: FlareUpdateInstaller, @unchecked Sendable {
    private let lock = NSLock()
    private var plans: [FlareUpdateInstallPlan] = []
    var result = FlareUpdateInstallResult(outcome: .completed)

    func execute(_ plan: FlareUpdateInstallPlan) async -> FlareUpdateInstallResult {
        record(plan)
    }

    private func record(_ plan: FlareUpdateInstallPlan) -> FlareUpdateInstallResult {
        lock.lock()
        defer { lock.unlock() }
        plans.append(plan)
        return result
    }

    var executed: [FlareUpdateInstallPlan] {
        lock.lock()
        defer { lock.unlock() }
        return plans
    }
}

private final class FakeAppState: PlatformAppStateSource, @unchecked Sendable {
    private var onChange: (@Sendable (PlatformAppState) -> Void)?

    func start(_ onChange: @escaping @Sendable (PlatformAppState) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func emit(_ state: PlatformAppState) {
        onChange?(state)
    }
}

@MainActor
final class FlareUpdateControllerTests: XCTestCase {
    /// Long enough to outlast a test's work, short enough to keep the suite quick.
    private let interval: UInt64 = 40_000_000

    private var engine: FakeEngine!
    private var installer: FakeInstaller!
    private var appState: FakeAppState!

    override func setUp() async throws {
        engine = FakeEngine()
        installer = FakeInstaller()
        appState = FakeAppState()
    }

    private func makeController(_ initial: [String: Any] = status("available")) async throws -> FlareUpdateController {
        engine.answer(FlareUpdateOperation.getState, initial)
        let controller = FlareUpdateController(
            engine: engine,
            installer: installer,
            appState: appState,
            pollInterval: interval
        ).install()
        try await until { controller.status != nil }
        return controller
    }

    private func until(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("timed out")
                return
            }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    private func wait(intervals: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(Double(interval) * intervals))
    }

    /// Events do not arrive before login, so the start, the foreground and login each read the status.
    func testReadsTheStatusOnStartForegroundAndLogin() async throws {
        let controller = try await makeController()
        XCTAssertEqual(engine.count(FlareUpdateOperation.getState), 1)

        appState.emit(.background)
        appState.emit(.foreground)
        try await until { self.engine.count(FlareUpdateOperation.getState) == 2 }

        controller.onLoginSucceeded()
        try await until { self.engine.count(FlareUpdateOperation.getState) == 3 }

        controller.onLoginFailed()
        try await until { self.engine.count(FlareUpdateOperation.getState) == 4 }
    }

    /// A return says so itself, since `lifecycle.set_app_state` may reach the engine after this read.
    func testAReturnToTheForegroundSaysSo() async throws {
        let controller = try await makeController()
        XCTAssertNil(engine.params(of: FlareUpdateOperation.getState).last?["foreground"])

        appState.emit(.background)
        appState.emit(.foreground)
        try await until { self.engine.count(FlareUpdateOperation.getState) == 2 }
        XCTAssertEqual(engine.params(of: FlareUpdateOperation.getState).last?["foreground"] as? Bool, true)

        controller.onLoginSucceeded()
        try await until { self.engine.count(FlareUpdateOperation.getState) == 3 }
        XCTAssertNil(engine.params(of: FlareUpdateOperation.getState).last?["foreground"])
    }

    /// `didBecomeActive` fires without the app having left: only a real return reads.
    func testAForegroundWithoutABackgroundReadsNothing() async throws {
        _ = try await makeController()
        appState.emit(.foreground)
        appState.emit(.foreground)
        try await wait(intervals: 1)
        XCTAssertEqual(engine.count(FlareUpdateOperation.getState), 1)
    }

    /// Silence while something runs is filled by reading the status; the reads stop with the state.
    func testPollsARunningStateThatStaysSilent() async throws {
        let controller = try await makeController(status("downloading"))
        try await until { self.engine.count(FlareUpdateOperation.getState) >= 2 }

        engine.answer(FlareUpdateOperation.getState, status("readyToInstall"))
        try await until { controller.status?.state == .readyToInstall }
        let reads = engine.count(FlareUpdateOperation.getState)

        try await wait(intervals: 3)
        XCTAssertEqual(engine.count(FlareUpdateOperation.getState), reads, "a settled state is not polled")
    }

    /// `update.check` answers at once: what it returns is no result, the poll of `checking` brings that.
    func testACheckAnswersAtOnceAndThePollBringsItsResult() async throws {
        let controller = try await makeController(status("idle", release: nil))
        engine.answer(FlareUpdateOperation.check, status("checking", release: nil))
        engine.answer(FlareUpdateOperation.getState, status("checking", release: nil))

        let answer = await controller.check()
        XCTAssertEqual(answer?.state, .checking)
        try await until { self.engine.count(FlareUpdateOperation.getState) >= 2 }

        engine.answer(FlareUpdateOperation.getState, status("available"))
        try await until { controller.status?.state == .available }
        let reads = engine.count(FlareUpdateOperation.getState)

        try await wait(intervals: 3)
        XCTAssertEqual(engine.count(FlareUpdateOperation.getState), reads, "a settled state is not polled")
    }

    func testPollsCheckingAndVerifyingToo() async throws {
        for running in ["checking", "verifying"] {
            engine = FakeEngine()
            let controller = try await makeController(status(running))
            try await until { self.engine.count(FlareUpdateOperation.getState) >= 2 }
            controller.dispose()
        }
    }

    func testDoesNotPollOtherStates() async throws {
        _ = try await makeController(status("installing"))
        try await wait(intervals: 3)
        XCTAssertEqual(engine.count(FlareUpdateOperation.getState), 1)
    }

    /// An event ends the wait: a settled state from the bus means no read at all.
    func testAnEventHoldsThePollBack() async throws {
        let controller = try await makeController(status("downloading"))
        engine.emit(status("readyToInstall"))
        try await until { controller.status?.state == .readyToInstall }
        try await wait(intervals: 3)
        XCTAssertEqual(engine.count(FlareUpdateOperation.getState), 1)
    }

    /// Every route's return value is the latest status, with no event needed.
    func testTakesEveryReturnValueAsTheLatestStatus() async throws {
        let controller = try await makeController()
        engine.answer(FlareUpdateOperation.check, status("upToDate", release: nil))
        await controller.check()
        XCTAssertEqual(controller.status?.state, .upToDate)
        XCTAssertEqual(engine.params(of: FlareUpdateOperation.check).first?["manual"] as? Bool, true)
    }

    /// A store release has nothing to download: the plan runs and the outcome goes back.
    func testRunsInstallAndReport() async throws {
        let controller = try await makeController(status("available", release: releaseWire(kind: "store")))
        engine.answer(FlareUpdateOperation.install, storePlan)
        engine.answer(FlareUpdateOperation.reportInstall, status("installing", release: releaseWire(kind: "store")))

        await controller.update()

        XCTAssertEqual(engine.routes().suffix(3), [
            FlareUpdateOperation.install,
            FlareUpdateOperation.getState,
            FlareUpdateOperation.reportInstall,
        ])
        XCTAssertEqual(engine.count(FlareUpdateOperation.download), 0)
        XCTAssertEqual(installer.executed, [
            .openStore(FlareUpdateStoreTarget(store: "appstore", url: "itms-apps://a")),
        ])
        XCTAssertEqual(engine.params(of: FlareUpdateOperation.reportInstall).first?["outcome"] as? String, "completed")
    }

    /// A release that needs a download waits for the state, polled if need be.
    func testWaitsForADownloadThatReturnsEarly() async throws {
        let controller = try await makeController()
        engine.answer(FlareUpdateOperation.getState, status("downloading"))
        engine.answer(FlareUpdateOperation.download, status("downloading"))
        engine.answer(FlareUpdateOperation.install, storePlan)
        engine.answer(FlareUpdateOperation.reportInstall, status("installing"))
        let run = Task { await controller.update() }
        try await until { self.engine.count(FlareUpdateOperation.download) == 1 }
        XCTAssertTrue(installer.executed.isEmpty, "nothing installs before the download ends")

        engine.answer(FlareUpdateOperation.getState, status("readyToInstall"))
        _ = await run.value
        XCTAssertEqual(installer.executed.count, 1)
    }

    /// A failed download ends the flow: nothing is installed.
    func testStopsWhenTheDownloadFails() async throws {
        let controller = try await makeController()
        engine.answer(
            FlareUpdateOperation.download,
            status("failed", error: ["code": FlareUpdateErrorCode.hashMismatch, "retryable": true])
        )
        await controller.update()
        XCTAssertTrue(installer.executed.isEmpty)
        XCTAssertEqual(engine.count(FlareUpdateOperation.install), 0)
        XCTAssertEqual(controller.status?.error?.code, FlareUpdateErrorCode.hashMismatch)
    }

    /// The first tap asks; the second, with the error on screen, is the confirmation.
    func testAMeteredRefusalMakesTheNextUpdateAllowMetered() async throws {
        let controller = try await makeController()
        engine.refuse(
            FlareUpdateOperation.download,
            FlareUpdateException(code: FlareUpdateErrorCode.meteredConfirmationRequired, retryable: true)
        )
        await controller.update()
        XCTAssertEqual(controller.status?.error?.code, FlareUpdateErrorCode.meteredConfirmationRequired)

        engine.answer(FlareUpdateOperation.download, status("readyToInstall"))
        engine.answer(FlareUpdateOperation.install, storePlan)
        engine.answer(FlareUpdateOperation.reportInstall, status("installing"))
        await controller.update()

        XCTAssertEqual(
            engine.params(of: FlareUpdateOperation.download).map { $0["allowMetered"] as? Bool },
            [false, true]
        )
        XCTAssertNil(controller.status?.error)
    }

    /// `later` is always the engine's to decide, the download phases included.
    func testLaterAlwaysDefers() async throws {
        for state in ["available", "downloading", "verifying"] {
            engine = FakeEngine()
            let controller = try await makeController(status(state, prompt: "sheet"))
            engine.answer(FlareUpdateOperation.defer, status(state, prompt: "none"))

            await controller.later()

            XCTAssertEqual(engine.count(FlareUpdateOperation.defer), 1, state)
            XCTAssertEqual(controller.status?.prompt, FlareUpdatePromptForm.none, state)
            controller.dispose()
        }
    }

    /// A download the user walked away from ends in a prompt: nothing starts by itself.
    func testADownloadPutAsideWaitsForTheUser() async throws {
        let controller = try await makeController()
        engine.answer(FlareUpdateOperation.getState, status("downloading"))
        engine.answer(FlareUpdateOperation.download, status("downloading"))
        engine.answer(FlareUpdateOperation.defer, status("downloading"))
        let run = Task { await controller.update() }
        try await until { self.engine.count(FlareUpdateOperation.download) == 1 }

        await controller.later()
        engine.answer(FlareUpdateOperation.getState, status("readyToInstall", prompt: "sheet"))
        _ = await run.value

        XCTAssertTrue(installer.executed.isEmpty)
        XCTAssertEqual(engine.count(FlareUpdateOperation.install), 0)
        XCTAssertEqual(controller.status?.state, .readyToInstall)

        engine.answer(FlareUpdateOperation.install, storePlan)
        engine.answer(FlareUpdateOperation.reportInstall, status("installing"))
        await controller.update()
        XCTAssertEqual(installer.executed.count, 1, "the user's own tap installs")
    }

    /// The engine maintains the prompt: what it says is what the status shows.
    func testBindsThePromptTheEngineGives() async throws {
        let controller = try await makeController(status("available", prompt: "sheet"))
        engine.answer(FlareUpdateOperation.markPrompted, status("available", prompt: "badge"))

        await controller.markPrompted()

        let params = engine.params(of: FlareUpdateOperation.markPrompted).first
        XCTAssertEqual(params?["build"] as? Int64, 20400)
        XCTAssertEqual(params?["form"] as? String, "sheet")
        XCTAssertEqual(controller.status?.prompt, .badge)
    }

    /// The server can refuse this build before the manifest arrives: forced, with no release yet.
    func testAForcedStateNeedsNoRelease() async throws {
        let controller = try await makeController(status("required", release: nil, prompt: "modal"))
        XCTAssertEqual(controller.status?.canContinueReadOnly, true)

        await controller.markPrompted()
        let params = engine.params(of: FlareUpdateOperation.markPrompted).first
        XCTAssertNil(params?["build"])
        XCTAssertEqual(params?["form"] as? String, "modal")

        await controller.update()
        XCTAssertEqual(engine.count(FlareUpdateOperation.install), 0)
        XCTAssertTrue(installer.executed.isEmpty)

        engine.answer(FlareUpdateOperation.defer, status("required", release: nil, readOnly: true))
        await controller.continueReadOnly()
        XCTAssertEqual(engine.count(FlareUpdateOperation.defer), 1)
        XCTAssertEqual(controller.status?.prompt, FlareUpdatePromptForm.none)
        XCTAssertEqual(controller.status?.readOnly, true)
    }

    /// `update()` looks for the release the refusal did not bring; the check it starts ends in the background.
    func testUpdateLooksForTheReleaseARefusalDidNotBring() async throws {
        let controller = try await makeController(status("required", release: nil, prompt: "modal"))
        engine.answer(FlareUpdateOperation.check, status("checking", release: nil, prompt: "modal"))
        engine.answer(FlareUpdateOperation.getState, status("checking", release: nil, prompt: "modal"))

        let answer = await controller.update()

        XCTAssertEqual(answer?.state, .checking)
        XCTAssertEqual(engine.params(of: FlareUpdateOperation.check).first?["manual"] as? Bool, true)
        XCTAssertEqual(engine.count(FlareUpdateOperation.install), 0)

        engine.answer(FlareUpdateOperation.getState, status("required", release: releaseWire(mandatory: true), prompt: "modal"))
        try await until { controller.status?.release != nil }
        XCTAssertEqual(controller.status?.state, .required)
        XCTAssertEqual(engine.count(FlareUpdateOperation.install), 0)
    }

    /// The answer to a new language is a status like any other: the words of the reason come with it.
    func testALanguageChangeReachesTheEngineAndComesBack() async throws {
        let controller = try await makeController()
        engine.answer(
            FlareUpdateOperation.setLocale,
            status("required", release: releaseWire(mandatory: true), blockReason: "No longer supported")
        )

        await controller.setLocale("en-US")

        XCTAssertEqual(engine.params(of: FlareUpdateOperation.setLocale).first?["locale"] as? String, "en-US")
        XCTAssertEqual(controller.status?.blockReason, "No longer supported")
    }

    /// The engine refuses a language before `init` and does not keep it: it waits for the first status.
    func testALanguageSetBeforeTheEngineIsUpWaitsForItsFirstStatus() async throws {
        engine.answer(FlareUpdateOperation.getState, status("available"))
        let controller = FlareUpdateController(engine: engine, installer: installer, appState: appState, pollInterval: interval)

        await controller.setLocale("en-US")
        XCTAssertEqual(engine.count(FlareUpdateOperation.setLocale), 0)

        controller.install()
        try await until { self.engine.count(FlareUpdateOperation.setLocale) == 1 }
        XCTAssertEqual(engine.params(of: FlareUpdateOperation.setLocale).first?["locale"] as? String, "en-US")
    }

    func testALanguageTheEngineRefusedGoesAgainWithTheNextStatus() async throws {
        let controller = try await makeController()
        engine.refuse(FlareUpdateOperation.setLocale, FlareUpdateException(code: FlareUpdateErrorCode.installFailed))

        await controller.setLocale("en-US")
        XCTAssertEqual(engine.count(FlareUpdateOperation.setLocale), 1)

        controller.onLoginSucceeded()
        try await until { self.engine.count(FlareUpdateOperation.setLocale) == 2 }

        controller.onLoginSucceeded()
        try await wait(intervals: 2)
        XCTAssertEqual(engine.count(FlareUpdateOperation.setLocale), 2, "one that went through is not sent again")
    }

    /// Language is no step of the update: a refusal does not show up as an update failure.
    func testALanguageTheEngineRefusesIsNoUpdateError() async throws {
        let controller = try await makeController()
        engine.refuse(FlareUpdateOperation.setLocale, FlareUpdateException(code: FlareUpdateErrorCode.installFailed))

        await controller.setLocale("en-US")

        XCTAssertNil(controller.status?.error)
    }

    /// A forced download stays forced after it leaves the `required` state.
    func testAForcedDownloadCanStillBePutAside() async throws {
        let controller = try await makeController(status("downloading", release: releaseWire(mandatory: true)))
        XCTAssertEqual(controller.status?.canContinueReadOnly, true)
    }

    /// A refused route leaves its facts in the status: what the engine recorded replaces what the exception said.
    func testARefusalReadsWhatTheEngineRecorded() async throws {
        let controller = try await makeController(status("available", release: releaseWire(kind: "store")))
        let recorded: [String: Any] = [
            "code": FlareUpdateErrorCode.noArtifact,
            "retryable": true,
            "fallbackUrl": "https://example.com/download",
        ]
        engine.refuse(FlareUpdateOperation.install, FlareUpdateException(code: FlareUpdateErrorCode.noArtifact))
        engine.answer(FlareUpdateOperation.getState, status("available", release: releaseWire(kind: "store"), error: recorded))

        await controller.update()

        XCTAssertEqual(controller.status?.error?.retryable, true)
        XCTAssertEqual(controller.status?.error?.fallbackUrl, "https://example.com/download")
    }

    func testNamesTheCodeInAnErrorText() {
        XCTAssertEqual(FlareUpdateErrorCode.named(in: "INVALID_PARAMETER: update.noArtifact"), FlareUpdateErrorCode.noArtifact)
        XCTAssertNil(FlareUpdateErrorCode.named(in: "the update center is not initialised; call init first"))
        XCTAssertNil(FlareUpdateErrorCode.named(in: nil))
    }

    func testABadgeIsNotMarked() async throws {
        let controller = try await makeController(status("available", prompt: "badge"))
        await controller.markPrompted()
        XCTAssertEqual(engine.count(FlareUpdateOperation.markPrompted), 0)
    }

    func testSkipsTheReleaseOnOffer() async throws {
        let controller = try await makeController()
        engine.answer(FlareUpdateOperation.skip, status("idle", release: nil))
        await controller.skip()
        XCTAssertEqual(engine.params(of: FlareUpdateOperation.skip).first?["build"] as? Int64, 20400)
    }

    /// The engine refuses to skip a forced release; the refusal shows in the status.
    func testARefusedRouteReachesTheStatus() async throws {
        let controller = try await makeController(status("required", release: releaseWire(mandatory: true)))
        engine.refuse(FlareUpdateOperation.skip, FlareUpdateException(code: FlareUpdateErrorCode.notSkippable))
        await controller.skip()
        XCTAssertEqual(controller.status?.error?.code, FlareUpdateErrorCode.notSkippable)
    }

    /// Read-only browsing is the engine's: `update.defer` folds the prompt away, and nothing is kept here.
    func testContinueReadOnlyGoesThroughTheEngine() async throws {
        let forced = status("required", release: releaseWire(mandatory: true), prompt: "modal")
        let controller = try await makeController(forced)
        XCTAssertEqual(controller.status?.canContinueReadOnly, true)
        engine.answer(FlareUpdateOperation.defer, status("required", release: releaseWire(mandatory: true), readOnly: true))

        await controller.continueReadOnly()

        XCTAssertEqual(engine.count(FlareUpdateOperation.defer), 1)
        XCTAssertEqual(controller.status?.prompt, FlareUpdatePromptForm.none)
        XCTAssertEqual(controller.status?.readOnly, true)

        appState.emit(.background)
        appState.emit(.foreground)
        try await until { controller.status?.prompt == .modal }
        XCTAssertEqual(controller.status?.readOnly, false)
    }

    /// A blocking update cannot be put aside.
    func testABlockingUpdateHasNoReadOnlyWayOut() async throws {
        let controller = try await makeController(
            status("required", release: releaseWire(mandatory: true), prompt: "fullscreen", blockUi: true)
        )
        XCTAssertEqual(controller.status?.canContinueReadOnly, false)
        await controller.continueReadOnly()
        XCTAssertEqual(engine.count(FlareUpdateOperation.defer), 0)
        XCTAssertEqual(controller.status?.prompt, .fullscreen)
    }

    /// The Kit gets retryable as sent, and the fallback target from the distribution.
    func testExposesRetryableAndTheFallbackTarget() async throws {
        let failed: [String: Any] = [
            "code": FlareUpdateErrorCode.hashMismatch,
            "retryable": true,
            "fallbackUrl": "https://example.com/download",
        ]
        let controller = try await makeController(status("failed", error: failed, distribution: "direct"))
        XCTAssertEqual(controller.status?.error?.retryable, true)
        XCTAssertEqual(controller.status?.fallbackTarget, .website)

        let opened = await controller.openFallback()
        XCTAssertTrue(opened)
        XCTAssertEqual(installer.executed, [
            .openStore(FlareUpdateStoreTarget(store: FlareUpdateStoreTarget.website, url: "https://example.com/download")),
        ])
    }

    /// The content stays the text the engine verified, for the Kit to read.
    func testLoadsTheResourcePacksOfThisRun() async throws {
        let controller = try await makeController(status("available"))
        engine.answer(FlareUpdateOperation.getResources, [
            "packs": [
                ["id": "emoji", "kind": "emoji", "packVersion": 3, "contentJson": "{\"packs\":[]}"],
                ["id": "strings", "kind": "strings", "packVersion": 12, "contentJson": "{}"],
            ],
        ])

        let packs = await controller.loadResources()

        XCTAssertEqual(packs, [
            FlareUpdateResourcePack(id: "emoji", kind: "emoji", packVersion: 3, contentJson: "{\"packs\":[]}"),
            FlareUpdateResourcePack(id: "strings", kind: "strings", packVersion: 12, contentJson: "{}"),
        ])
        XCTAssertEqual(engine.count(FlareUpdateOperation.getResources), 1)
    }

    func testNoResourcePacksIsAnEmptyList() async throws {
        let controller = try await makeController(status("available"))
        engine.answer(FlareUpdateOperation.getResources, ["packs": [[String: Any]]()])
        let packs = await controller.loadResources()
        XCTAssertEqual(packs, [])
    }

    /// Packs are no step of the update: the app stays on its built-in resources and the prompt shows no error.
    func testAFailedResourceReadOnlyReachesOnError() async throws {
        let controller = try await makeController(status("available"))
        engine.refuse(FlareUpdateOperation.getResources, FlareUpdateException(code: FlareUpdateErrorCode.installFailed))

        let packs = await controller.loadResources()

        XCTAssertEqual(packs, [])
        XCTAssertNil(controller.status?.error)
    }

    /// A pack with a field missing is a broken answer: nothing of it is used.
    func testAMalformedResourceAnswerIsNoPacks() async throws {
        let controller = try await makeController(status("available"))
        engine.answer(FlareUpdateOperation.getResources, ["packs": [["id": "strings"]]])
        let packs = await controller.loadResources()
        XCTAssertEqual(packs, [])
    }

    /// Nothing moves after dispose.
    func testDisposeStopsEverything() async throws {
        let controller = try await makeController(status("downloading"))
        controller.dispose()
        XCTAssertTrue(engine.closed)
        try await wait(intervals: 3)
        XCTAssertEqual(engine.count(FlareUpdateOperation.getState), 1)
    }
}
