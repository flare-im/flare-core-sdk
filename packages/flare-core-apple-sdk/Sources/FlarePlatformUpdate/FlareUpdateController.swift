import Combine
import FlarePlatformLifecycle
import Foundation
import os

private let log = Logger(subsystem: "com.flare.im.update", category: "update")

/// The engine as the controller needs it. It references no SDK, so a host wires in whichever engine
/// it runs: the core client or its own C ABI.
public protocol FlareUpdateEngine: Sendable {
    /// Calls an `update.*` route (`FlareUpdateOperation`) and returns its decoded JSON object.
    /// A refusal is a `FlareUpdateException` carrying the error code.
    func dispatch(_ operation: String, params: [String: Any]) async throws -> [String: Any]

    /// Delivers every `update://state` payload, on any thread, until the returned closure is called.
    func subscribeState(_ onState: @escaping @Sendable ([String: Any]) -> Void) -> @Sendable () -> Void
}

/// Binds an app to the update center. The engine decides everything; this runs the steps the
/// platform has to take and keeps `status` current, so an app hands `status` to the Kit and connects
/// the Kit's callbacks to the methods here, with no flow of its own.
///
/// Events only reach the host while there is a session, so they are not the only source of `status`:
/// the status is read on `install()`, on returning to the foreground, on `onLoginSucceeded()` and on
/// `onLoginFailed()`, every route's return value is taken as the latest status, and while the state is
/// `checking`, `downloading` or `verifying` a silence of 500 ms triggers a read. That read is also how a
/// check ends: `update.check` answers at once with `checking` and runs in the background.
///
/// The engine maintains `prompt` and `readOnly`, so an app binds them directly. Methods report a
/// failure through `status.error` rather than by throwing.
@MainActor
public final class FlareUpdateController: ObservableObject {
    /// How long a running operation may stay silent before the status is read.
    public nonisolated static let pollIntervalNanoseconds: UInt64 = 500_000_000

    private static let downloadStates: Set<FlareUpdateState> = [.downloading, .verifying]
    private static let polledStates: Set<FlareUpdateState> = [.checking, .downloading, .verifying]

    private enum Signal: Sendable {
        case event(FlareUpdateStatus)
        case malformed(any Error)
        case appState(PlatformAppState)
    }

    /// The latest status for the UI; nil until the first read.
    @Published public private(set) var status: FlareUpdateStatus?

    private let engine: FlareUpdateEngine
    private let installer: FlareUpdateInstaller
    private let appState: PlatformAppStateSource
    private let onError: @Sendable (any Error) -> Void
    private let pollInterval: UInt64

    private var engineStatus: FlareUpdateStatus?
    private var revision: UInt64 = 0
    private var pollTask: Task<Void, Never>?
    private var signalTask: Task<Void, Never>?
    private var signals: AsyncStream<Signal>.Continuation?
    private var unsubscribe: (@Sendable () -> Void)?
    private var downloadWaiters: [CheckedContinuation<FlareUpdateStatus?, Never>] = []
    private var lastAppState: PlatformAppState?
    private var installed = false
    private var disposed = false
    private var updating = false

    private var localError: FlareUpdateError?
    private var sentToBackground = false
    private var pendingLocale: String?
    private var sendingLocale = false

    public init(
        engine: FlareUpdateEngine,
        installer: FlareUpdateInstaller = FlareSystemUpdateInstaller(),
        appState: PlatformAppStateSource = SystemAppStateSource(),
        onError: (@Sendable (any Error) -> Void)? = nil,
        pollInterval: UInt64 = FlareUpdateController.pollIntervalNanoseconds
    ) {
        self.engine = engine
        self.installer = installer
        self.appState = appState
        self.onError = onError ?? { failure in
            log.warning("update center: \(String(describing: type(of: failure)), privacy: .public)")
        }
        self.pollInterval = pollInterval
    }

    /// Starts listening and reads the current status. Calling it again does nothing.
    @discardableResult
    public func install() -> Self {
        guard !installed, !disposed else { return self }
        installed = true
        let (stream, continuation) = AsyncStream<Signal>.makeStream()
        signals = continuation
        signalTask = Task { [weak self] in
            for await signal in stream {
                self?.receive(signal)
            }
        }
        unsubscribe = engine.subscribeState { payload in
            do {
                continuation.yield(.event(try FlareUpdateStatus(wire: payload)))
            } catch {
                continuation.yield(.malformed(error))
            }
        }
        appState.start { state in
            continuation.yield(.appState(state))
        }
        readInBackground()
        return self
    }

    /// Stops listening; later statuses are dropped.
    public func dispose() {
        guard !disposed else { return }
        disposed = true
        pollTask?.cancel()
        pollTask = nil
        unsubscribe?()
        unsubscribe = nil
        if installed {
            appState.stop()
        }
        signals?.finish()
        signals = nil
        signalTask?.cancel()
        signalTask = nil
        resumeDownloadWaiters(with: status)
    }

    /// Reads the status again; events do not arrive before login, so call this when login succeeds.
    public func onLoginSucceeded() {
        readInBackground()
    }

    /// Reads the status again: a sign-in refused with `UPGRADE_REQUIRED` leaves no session, so no event says so.
    public func onLoginFailed() {
        readInBackground()
    }

    /// Reads the current status from the engine; a failed read goes to `onError`.
    @discardableResult
    public func refresh() async -> FlareUpdateStatus? {
        do {
            return try await call(FlareUpdateOperation.getState)
        } catch {
            onError(error)
            return status
        }
    }

    /// Tells the engine the language the app shows: the release notes and `blockReason` follow it at once.
    /// Call it when the app reads its language at start and when the person changes it.
    ///
    /// Before `init` the engine refuses a language and does not keep it, so the value waits here for the first
    /// status, which only comes once the engine is up. One the engine refused goes again with the next status.
    /// A failure is no step of the update: it goes to `onError`, not to `status.error`.
    public func setLocale(_ locale: String) async {
        pendingLocale = locale
        if engineStatus != nil {
            await sendLocale()
        }
    }

    /// The resource packs of this run, in `id` order. The engine reads them once when it starts, so what a check
    /// brings or withdraws shows on the next start and this answers the same all run. Packs are no step of the
    /// update and nothing waits for them: a failure goes to `onError`, not to `status.error`, and answers no packs,
    /// which leaves the app on its built-in resources.
    public func loadResources() async -> [FlareUpdateResourcePack] {
        do {
            return try FlareUpdateResourcePack.list(
                wire: try await engine.dispatch(FlareUpdateOperation.getResources, params: [:])
            )
        } catch {
            onError(error)
            return []
        }
    }

    /// One call at a time, so two quick changes cannot arrive out of order.
    private func sendLocale() async {
        guard let locale = pendingLocale, !sendingLocale else { return }
        sendingLocale = true
        do {
            try await call(FlareUpdateOperation.setLocale, ["locale": locale])
            if pendingLocale == locale {
                pendingLocale = nil
            }
        } catch {
            onError(error)
        }
        sendingLocale = false
        if let newer = pendingLocale, newer != locale {
            await sendLocale()
        }
    }

    /// Starts a check for a release; `manual` is not held back by the check interval. The engine answers at
    /// once, with `checking` when a check runs, so the result is not what this returns: it reaches `status`
    /// by event or by the poll that state starts.
    @discardableResult
    public func check(manual: Bool = true) async -> FlareUpdateStatus? {
        await userAction(fallback: FlareUpdateErrorCode.manifestUnavailable) {
            try await self.call(FlareUpdateOperation.check, ["manual": manual])
        }
    }

    /// Runs the update: download when the release needs one, then `update.install`, the plan, and
    /// `update.report_install`. When the last error asks for confirmation on a metered network,
    /// calling this again is that confirmation.
    @discardableResult
    public func update() async -> FlareUpdateStatus? {
        sentToBackground = false
        guard !updating else { return status }
        updating = true
        defer { updating = false }
        let allowMetered = status?.error?.code == FlareUpdateErrorCode.meteredConfirmationRequired
        return await userAction(fallback: FlareUpdateErrorCode.installFailed) {
            try await self.runUpdate(allowMetered: allowMetered)
        }
    }

    /// Puts the prompt aside through `update.defer`; what that means is the engine's to decide. A
    /// download put aside goes on, and when it ends it waits for the user: an update they walked away
    /// from does not start by itself.
    @discardableResult
    public func later() async -> FlareUpdateStatus? {
        if let state = engineStatus?.state, Self.downloadStates.contains(state) {
            sentToBackground = true
        }
        return await userAction { try await self.call(FlareUpdateOperation.defer) }
    }

    /// Skips the optional release on offer; the engine refuses a forced one.
    @discardableResult
    public func skip() async -> FlareUpdateStatus? {
        guard let build = engineStatus?.release?.build else { return status }
        return await userAction { try await self.call(FlareUpdateOperation.skip, ["build": build]) }
    }

    /// Tells the engine the prompt in `status` is on screen, which is what its frequency rules count.
    @discardableResult
    public func markPrompted() async -> FlareUpdateStatus? {
        guard let current = status else { return nil }
        guard current.prompt.interrupts else { return current }
        var params: [String: Any] = ["form": current.prompt.rawValue]
        // A forced prompt can stand before the manifest arrives, with no release to name.
        if let build = current.release?.build {
            params["build"] = build
        }
        return await userAction { try await self.call(FlareUpdateOperation.markPrompted, params) }
    }

    /// Puts a forced update aside to browse read only, through `update.defer`: the engine folds the
    /// prompt away, sets `readOnly` and asks again on the next start or return to the foreground. Does
    /// nothing when `canContinueReadOnly` is false.
    @discardableResult
    public func continueReadOnly() async -> FlareUpdateStatus? {
        guard engineStatus?.canContinueReadOnly == true else { return status }
        return await later()
    }

    /// Opens the fallback link of the last error; false when there is none or nothing can open it.
    @discardableResult
    public func openFallback() async -> Bool {
        guard let url = status?.error?.fallbackUrl else { return false }
        let target = FlareUpdateStoreTarget(store: FlareUpdateStoreTarget.website, url: url)
        return await installer.execute(.openStore(target)).outcome == .completed
    }

    private func runUpdate(allowMetered: Bool) async throws -> FlareUpdateStatus? {
        var current: FlareUpdateStatus?
        if let engineStatus {
            current = engineStatus
        } else {
            current = try await call(FlareUpdateOperation.getState)
        }
        guard let release = current?.release else {
            // Refused by the server before any manifest arrived: find the release instead of doing nothing. The
            // check runs in the background; the poll of `checking` brings the release to the prompt, which then
            // offers it.
            guard current?.state == .required else { return current }
            return try await call(FlareUpdateOperation.check, ["manual": true])
        }
        if release.kind == .package, current?.state != .readyToInstall {
            if let state = current?.state, !Self.downloadStates.contains(state) {
                current = try await call(FlareUpdateOperation.download, ["allowMetered": allowMetered])
            }
            current = await downloaded(current)
            guard current?.state == .readyToInstall, !sentToBackground else { return current }
        }
        let payload = try await engine.dispatch(FlareUpdateOperation.install, params: [:])
        let plan = try FlareUpdateInstallPlan(wire: payload)
        // The route returns the plan, not a status; the state moved to `installing`.
        try await call(FlareUpdateOperation.getState)
        let result = await installer.execute(plan)
        return try await call(FlareUpdateOperation.reportInstall, result.reportParams)
    }

    private func downloaded(_ current: FlareUpdateStatus?) async -> FlareUpdateStatus? {
        guard let state = current?.state, Self.downloadStates.contains(state), !disposed else { return current }
        return await withCheckedContinuation { downloadWaiters.append($0) }
    }

    private func resumeDownloadWaiters(with status: FlareUpdateStatus?) {
        let waiters = downloadWaiters
        downloadWaiters = []
        waiters.forEach { $0.resume(returning: status) }
    }

    @discardableResult
    private func call(_ operation: String, _ params: [String: Any] = [:]) async throws -> FlareUpdateStatus? {
        let payload = try await engine.dispatch(operation, params: params)
        return adopt(try FlareUpdateStatus(wire: payload))
    }

    /// A step the user asked for: an earlier failure no longer stands, and a new one reaches
    /// `status.error` with the engine's code, or `fallback` when the failure carries none.
    private func userAction(
        fallback: String? = nil,
        _ action: () async throws -> FlareUpdateStatus?
    ) async -> FlareUpdateStatus? {
        localError = nil
        do {
            return try await action()
        } catch {
            onError(error)
            let refused = error as? FlareUpdateException
            if let code = refused?.code ?? fallback {
                localError = FlareUpdateError(
                    code: code,
                    retryable: refused?.retryable ?? true,
                    fallbackUrl: refused?.fallbackUrl
                )
                publish()
            }
            // The engine recorded a refusal with what the exception cannot carry: retry and the fallback link.
            if refused != nil {
                await refresh()
            }
            return status
        }
    }

    private func receive(_ signal: Signal) {
        switch signal {
        case .event(let status):
            adopt(status)
        case .malformed(let error):
            onError(error)
        case .appState(let state):
            let returned = state == .foreground && lastAppState == .background
            lastAppState = state
            if returned {
                readOnForeground()
            }
        }
    }

    /// Says so itself: `lifecycle.set_app_state` may arrive after this read, and what is due on a return would
    /// then be missed until the next one.
    private func readOnForeground() {
        Task {
            do {
                try await self.call(FlareUpdateOperation.getState, ["foreground": true])
            } catch {
                self.onError(error)
            }
        }
    }

    private func readInBackground() {
        Task { await self.refresh() }
    }

    /// Takes `status` as the latest word from the engine and returns what the UI now shows.
    @discardableResult
    private func adopt(_ status: FlareUpdateStatus) -> FlareUpdateStatus? {
        guard !disposed else { return self.status }
        engineStatus = status
        revision &+= 1
        armPoll(status)
        publish()
        if !Self.downloadStates.contains(status.state) {
            resumeDownloadWaiters(with: self.status)
        }
        if pendingLocale != nil, !sendingLocale {
            Task { await self.sendLocale() }
        }
        return self.status
    }

    /// Any status restarts the wait, so a poll only runs after a real silence.
    private func armPoll(_ status: FlareUpdateStatus) {
        pollTask?.cancel()
        pollTask = nil
        guard Self.polledStates.contains(status.state) else { return }
        let seen = revision
        let interval = pollInterval
        pollTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            guard !Task.isCancelled else { return }
            await self?.poll(seen: seen)
        }
    }

    private func poll(seen: UInt64) async {
        do {
            let payload = try await engine.dispatch(FlareUpdateOperation.getState, params: [:])
            // A status that arrived while this read was out is newer than what it brings back.
            if revision == seen {
                adopt(try FlareUpdateStatus(wire: payload))
            }
        } catch {
            onError(error)
        }
    }

    private func publish() {
        guard let engineStatus else { return }
        status = present(engineStatus)
    }

    private func present(_ engineStatus: FlareUpdateStatus) -> FlareUpdateStatus {
        var result = engineStatus
        if result.error == nil {
            result.error = localError
        }
        return result
    }
}
