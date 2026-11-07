import FlarePlatformUpdate
import Foundation

/// The update controller's port on a core client. `client` is asked for on every call, so a host that
/// brings a client up on demand, or replaces it, answers with the current one. The host forwards
/// `events.onUpdateState` of whichever client it runs to ``receive(_:)``.
public final class ClientUpdateEngine: FlareUpdateEngine, @unchecked Sendable {
    private let client: @Sendable () async throws -> any FlareImClientProtocol
    private let lock = NSLock()
    private var listener: (@Sendable ([String: Any]) -> Void)?

    public init(client: @escaping @Sendable () async throws -> any FlareImClientProtocol) {
        self.client = client
    }

    /// An `update://state` from the client.
    public func receive(_ status: UpdateStatus) {
        lock.lock()
        let listener = self.listener
        lock.unlock()
        guard let listener, let payload = try? clientUpdateWire(status) else { return }
        listener(payload)
    }

    public func subscribeState(_ onState: @escaping @Sendable ([String: Any]) -> Void) -> @Sendable () -> Void {
        lock.lock()
        listener = onState
        lock.unlock()
        return { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.listener = nil
            self.lock.unlock()
        }
    }

    public func dispatch(_ operation: String, params: [String: Any]) async throws -> [String: Any] {
        do {
            return try await route(operation, params)
        } catch let failure as FlareSdkException {
            guard let code = FlareUpdateErrorCode.named(in: failure.reason) ?? FlareUpdateErrorCode.named(in: failure.message) else {
                throw failure
            }
            throw FlareUpdateException(code: code, message: failure.message)
        }
    }

    private func route(_ operation: String, _ params: [String: Any]) async throws -> [String: Any] {
        let update = try await client().update
        switch operation {
        case FlareUpdateOperation.getState:
            let request = UpdateGetStateRequest(foreground: params["foreground"] as? Bool)
            return try clientUpdateWire(try await update.getState(request))
        case FlareUpdateOperation.check:
            return try clientUpdateWire(try await update.check(UpdateCheckRequest(manual: params["manual"] as? Bool ?? false)))
        case FlareUpdateOperation.download:
            let request = UpdateDownloadRequest(allowMetered: params["allowMetered"] as? Bool ?? false)
            return try clientUpdateWire(try await update.download(request))
        case FlareUpdateOperation.install:
            return try clientUpdateWire(try await update.install())
        case FlareUpdateOperation.reportInstall:
            let request = UpdateReportInstallRequest(outcome: params["outcome"] as? String ?? "", code: params["code"] as? String)
            return try clientUpdateWire(try await update.reportInstall(request))
        case FlareUpdateOperation.defer:
            return try clientUpdateWire(try await update.defer())
        case FlareUpdateOperation.skip:
            return try clientUpdateWire(try await update.skip(UpdateSkipRequest(build: clientUpdateBuild(params) ?? 0)))
        case FlareUpdateOperation.markPrompted:
            let request = UpdateMarkPromptedRequest(build: clientUpdateBuild(params), form: params["form"] as? String ?? "")
            return try clientUpdateWire(try await update.markPrompted(request))
        case FlareUpdateOperation.setLocale:
            let request = UpdateSetLocaleRequest(locale: params["locale"] as? String ?? "")
            return try clientUpdateWire(try await update.setLocale(request))
        case FlareUpdateOperation.getResources:
            return try clientUpdateWire(try await update.getResources(UpdateGetResourcesRequest()))
        default:
            throw FlareUpdateWireError(field: operation)
        }
    }
}

/// The value as the port speaks it: the models' property names are the wire's.
func clientUpdateWire<Value: Encodable>(_ value: Value) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw FlareUpdateWireError(field: String(describing: Value.self))
    }
    return object
}

/// `build` as the routes take it; absent when a forced prompt has no release to name.
func clientUpdateBuild(_ params: [String: Any]) -> UInt64? {
    (params["build"] as? NSNumber)?.uint64Value
}
