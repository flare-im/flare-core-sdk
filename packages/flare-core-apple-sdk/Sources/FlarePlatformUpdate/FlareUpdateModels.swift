import Foundation

/// The wire names of the update routes.
public enum FlareUpdateOperation {
    public static let getState = "update.get_state"
    public static let check = "update.check"
    public static let download = "update.download"
    public static let install = "update.install"
    public static let reportInstall = "update.report_install"
    public static let `defer` = "update.defer"
    public static let skip = "update.skip"
    public static let markPrompted = "update.mark_prompted"
    public static let setLocale = "update.set_locale"
    public static let getResources = "update.get_resources"
}

/// The cross-platform update error codes.
public enum FlareUpdateErrorCode {
    public static let manifestUnavailable = "update.manifestUnavailable"
    public static let manifestRejected = "update.manifestRejected"
    public static let noArtifact = "update.noArtifact"
    public static let meteredConfirmationRequired = "update.meteredConfirmationRequired"
    public static let insufficientSpace = "update.insufficientSpace"
    public static let downloadFailed = "update.downloadFailed"
    public static let hashMismatch = "update.hashMismatch"
    public static let installFailed = "update.installFailed"
    public static let signatureMismatch = "update.signatureMismatch"
    public static let downgradeRejected = "update.downgradeRejected"
    public static let notSkippable = "update.notSkippable"

    private static let all = [
        manifestUnavailable, manifestRejected, noArtifact, meteredConfirmationRequired, insufficientSpace,
        downloadFailed, hashMismatch, installFailed, signatureMismatch, downgradeRejected, notSkippable,
    ]

    /// The code `text` names, nil when it names none: `update.install` raises the code as its error text.
    public static func named(in text: String?) -> String? {
        guard let text else { return nil }
        return all.first { text.contains($0) }
    }
}

/// Where the update flow stands; the raw values are the SDK wire values.
public enum FlareUpdateState: String, Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case available
    case required
    case downloading
    case verifying
    case readyToInstall
    case installing
    case failed
}

/// How the update should be put in front of the user.
public enum FlareUpdatePromptForm: String, Equatable, Sendable {
    case none
    case badge
    case sheet
    case modal
    case fullscreen

    /// The forms that interrupt the user, as opposed to a quiet badge.
    public var interrupts: Bool {
        self == .sheet || self == .modal || self == .fullscreen
    }
}

/// How a release reaches the device.
public enum FlareUpdateKind: String, Equatable, Sendable {
    case store
    case `package`
    case webBundle
    case desktop
}

/// Where a failed update sends the user instead: the Kit words its fallback button by this.
public enum FlareUpdateFallbackTarget: String, Equatable, Sendable {
    case website
    case store
}

/// The installed app, as the engine knows it.
public struct FlareUpdateCurrent: Equatable, Sendable {
    public var version: String?
    public var build: Int64?
    public var channel: String?
    public var distribution: String?

    public init(version: String? = nil, build: Int64? = nil, channel: String? = nil, distribution: String? = nil) {
        self.version = version
        self.build = build
        self.channel = channel
        self.distribution = distribution
    }
}

/// The release on offer. `notes` are already in the app's language.
public struct FlareUpdateRelease: Equatable, Sendable {
    public var releaseId: String
    public var version: String
    public var build: Int64
    public var notes: [String]
    /// Nil for a store release: the store knows the size, the manifest does not.
    public var sizeBytes: Int64?
    public var mandatory: Bool
    public var recommended: Bool
    public var kind: FlareUpdateKind

    public init(
        releaseId: String,
        version: String,
        build: Int64,
        notes: [String] = [],
        sizeBytes: Int64? = nil,
        mandatory: Bool = false,
        recommended: Bool = false,
        kind: FlareUpdateKind
    ) {
        self.releaseId = releaseId
        self.version = version
        self.build = build
        self.notes = notes
        self.sizeBytes = sizeBytes
        self.mandatory = mandatory
        self.recommended = recommended
        self.kind = kind
    }
}

/// Download progress in bytes.
public struct FlareUpdateProgress: Equatable, Sendable {
    public var received: Int64
    public var total: Int64?

    public init(received: Int64, total: Int64?) {
        self.received = received
        self.total = total
    }
}

/// A resource pack of this run. It is data for the Kit, so `contentJson` stays the text the engine verified.
public struct FlareUpdateResourcePack: Equatable, Sendable {
    public var id: String
    public var kind: String
    public var packVersion: Int64
    public var contentJson: String

    public init(id: String, kind: String, packVersion: Int64, contentJson: String) {
        self.id = id
        self.kind = kind
        self.packVersion = packVersion
        self.contentJson = contentJson
    }
}

/// The last failure.
public struct FlareUpdateError: Equatable, Sendable {
    public var code: String
    public var retryable: Bool
    public var fallbackUrl: String?

    public init(code: String, retryable: Bool = false, fallbackUrl: String? = nil) {
        self.code = code
        self.retryable = retryable
        self.fallbackUrl = fallbackUrl
    }
}

/// The `update://state` payload, and what every `update.*` route except `update.install` returns.
public struct FlareUpdateStatus: Equatable, Sendable {
    public var state: FlareUpdateState
    public var current: FlareUpdateCurrent
    public var release: FlareUpdateRelease?
    public var progress: FlareUpdateProgress?
    public var prompt: FlareUpdatePromptForm
    public var blockUi: Bool
    public var readOnly: Bool
    /// Why this build is blocked, in the app's language; nil when it is not.
    public var blockReason: String?
    /// Milliseconds; nil when no check has run yet.
    public var lastCheckedAt: Int64?
    public var error: FlareUpdateError?

    public init(
        state: FlareUpdateState,
        current: FlareUpdateCurrent = FlareUpdateCurrent(),
        release: FlareUpdateRelease? = nil,
        progress: FlareUpdateProgress? = nil,
        prompt: FlareUpdatePromptForm = .none,
        blockUi: Bool = false,
        readOnly: Bool = false,
        blockReason: String? = nil,
        lastCheckedAt: Int64? = nil,
        error: FlareUpdateError? = nil
    ) {
        self.state = state
        self.current = current
        self.release = release
        self.progress = progress
        self.prompt = prompt
        self.blockUi = blockUi
        self.readOnly = readOnly
        self.blockReason = blockReason
        self.lastCheckedAt = lastCheckedAt
        self.error = error
    }

    /// The direct channel falls back to the website, every other channel to its store.
    public var fallbackTarget: FlareUpdateFallbackTarget {
        current.distribution == "direct" ? .website : .store
    }

    /// A forced update that does not block the UI can be put aside to browse read only. The state says
    /// forced on its own: when the server refuses this build before the manifest arrives, `release` is nil.
    public var canContinueReadOnly: Bool {
        (state == .required || release?.mandatory == true) && !blockUi
    }
}

/// A store page to open.
public struct FlareUpdateStoreTarget: Equatable, Sendable {
    /// The value of `store` for a plain link: no store app is involved.
    public static let website = "website"

    public var store: String
    public var url: String?
    public var packageName: String?
    public var appId: String?

    public init(store: String, url: String? = nil, packageName: String? = nil, appId: String? = nil) {
        self.store = store
        self.url = url
        self.packageName = packageName
        self.appId = appId
    }
}

/// What the platform is asked to do; the engine decides it, the installer only carries it out.
public enum FlareUpdateInstallPlan: Equatable, Sendable {
    case openStore(FlareUpdateStoreTarget)
    /// A plan for another platform; Apple platforms cannot carry it out.
    case unsupported(kind: String)
}

/// The values `update.report_install` takes.
public enum FlareUpdateOutcome: String, Equatable, Sendable {
    case started
    case completed
    case cancelled
    case failed
}

/// What became of a plan. `completed` means nothing is left to do here: for a store that its page
/// opened, whether the user installs being the store's business. `code` is set on `failed`.
public struct FlareUpdateInstallResult: Equatable, Sendable {
    public var outcome: FlareUpdateOutcome
    public var code: String?

    public init(outcome: FlareUpdateOutcome, code: String? = nil) {
        self.outcome = outcome
        self.code = code
    }

    public static func failed(_ code: String) -> FlareUpdateInstallResult {
        FlareUpdateInstallResult(outcome: .failed, code: code)
    }

    /// The `update.report_install` parameters.
    public var reportParams: [String: Any] {
        var params: [String: Any] = ["outcome": outcome.rawValue]
        if let code {
            params["code"] = code
        }
        return params
    }
}

/// A route refused the call. `code` is the cross-platform code when the engine gave one.
public struct FlareUpdateException: Error, Equatable, Sendable {
    public var code: String
    public var message: String?
    public var retryable: Bool
    public var fallbackUrl: String?

    public init(code: String, message: String? = nil, retryable: Bool = false, fallbackUrl: String? = nil) {
        self.code = code
        self.message = message
        self.retryable = retryable
        self.fallbackUrl = fallbackUrl
    }
}

/// A payload does not have the shape of the update contract.
public struct FlareUpdateWireError: Error, Equatable, Sendable {
    public var field: String

    public init(field: String) {
        self.field = field
    }
}

extension FlareUpdateStatus {
    /// Reads the wire shape from decoded JSON.
    public init(wire: [String: Any]) throws {
        guard let state = (wire["state"] as? String).flatMap(FlareUpdateState.init(rawValue:)) else {
            throw FlareUpdateWireError(field: "state")
        }
        self.init(
            state: state,
            current: FlareUpdateCurrent(wire: wire["current"] as? [String: Any] ?? [:]),
            release: try (wire["release"] as? [String: Any]).map(FlareUpdateRelease.init(wire:)),
            progress: (wire["progress"] as? [String: Any]).map(FlareUpdateProgress.init(wire:)),
            prompt: (wire["prompt"] as? String).flatMap(FlareUpdatePromptForm.init(rawValue:)) ?? .none,
            blockUi: wire["blockUi"] as? Bool ?? false,
            readOnly: wire["readOnly"] as? Bool ?? false,
            blockReason: wire["blockReason"] as? String,
            lastCheckedAt: wireInt64(wire["lastCheckedAt"]),
            error: try (wire["error"] as? [String: Any]).map(FlareUpdateError.init(wire:))
        )
    }
}

extension FlareUpdateResourcePack {
    /// The packs of an `update.get_resources` answer.
    public static func list(wire: [String: Any]) throws -> [FlareUpdateResourcePack] {
        try (wire["packs"] as? [[String: Any]] ?? []).map(FlareUpdateResourcePack.init(wire:))
    }

    init(wire: [String: Any]) throws {
        guard let id = wire["id"] as? String else {
            throw FlareUpdateWireError(field: "pack.id")
        }
        guard let kind = wire["kind"] as? String else {
            throw FlareUpdateWireError(field: "pack.kind")
        }
        guard let packVersion = wireInt64(wire["packVersion"]) else {
            throw FlareUpdateWireError(field: "pack.packVersion")
        }
        guard let contentJson = wire["contentJson"] as? String else {
            throw FlareUpdateWireError(field: "pack.contentJson")
        }
        self.init(id: id, kind: kind, packVersion: packVersion, contentJson: contentJson)
    }
}

extension FlareUpdateCurrent {
    init(wire: [String: Any]) {
        self.init(
            version: wire["version"] as? String,
            build: wireInt64(wire["build"]),
            channel: wire["channel"] as? String,
            distribution: wire["distribution"] as? String
        )
    }
}

extension FlareUpdateRelease {
    init(wire: [String: Any]) throws {
        guard let releaseId = wire["releaseId"] as? String else {
            throw FlareUpdateWireError(field: "releaseId")
        }
        guard let version = wire["version"] as? String else {
            throw FlareUpdateWireError(field: "version")
        }
        guard let build = wireInt64(wire["build"]) else {
            throw FlareUpdateWireError(field: "build")
        }
        guard let kind = (wire["kind"] as? String).flatMap(FlareUpdateKind.init(rawValue:)) else {
            throw FlareUpdateWireError(field: "kind")
        }
        self.init(
            releaseId: releaseId,
            version: version,
            build: build,
            notes: wire["notes"] as? [String] ?? [],
            sizeBytes: wireInt64(wire["sizeBytes"]),
            mandatory: wire["mandatory"] as? Bool ?? false,
            recommended: wire["recommended"] as? Bool ?? false,
            kind: kind
        )
    }
}

extension FlareUpdateProgress {
    init(wire: [String: Any]) {
        self.init(received: wireInt64(wire["received"]) ?? 0, total: wireInt64(wire["total"]))
    }
}

extension FlareUpdateError {
    init(wire: [String: Any]) throws {
        guard let code = wire["code"] as? String else {
            throw FlareUpdateWireError(field: "error.code")
        }
        self.init(
            code: code,
            retryable: wire["retryable"] as? Bool ?? false,
            fallbackUrl: wire["fallbackUrl"] as? String
        )
    }
}

extension FlareUpdateInstallPlan {
    /// Reads the wire shape from decoded JSON.
    public init(wire: [String: Any]) throws {
        guard let kind = wire["kind"] as? String else {
            throw FlareUpdateWireError(field: "kind")
        }
        guard kind == "openStore" else {
            self = .unsupported(kind: kind)
            return
        }
        guard let store = wire["store"] as? String else {
            throw FlareUpdateWireError(field: "store")
        }
        self = .openStore(FlareUpdateStoreTarget(
            store: store,
            url: wire["url"] as? String,
            packageName: wire["packageName"] as? String,
            appId: wire["appId"] as? String
        ))
    }
}

private func wireInt64(_ value: Any?) -> Int64? {
    (value as? NSNumber)?.int64Value
}
