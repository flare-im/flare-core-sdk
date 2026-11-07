import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Carries out an install plan. Platform capability only: the engine decides what to install and
/// whether it is trustworthy.
public protocol FlareUpdateInstaller: Sendable {
    /// Runs `plan` and says how it went. Apple platforms update through a store, so a plan ends in
    /// `completed` once the store opened: what happens there is the store's.
    func execute(_ plan: FlareUpdateInstallPlan) async -> FlareUpdateInstallResult
}

/// Opens the App Store or TestFlight. The link comes from the release manifest; the version check
/// does not ask the iTunes Lookup API, which knows nothing of the rollout and lags behind it.
public struct FlareSystemUpdateInstaller: FlareUpdateInstaller {
    private let open: @Sendable (URL) async -> Bool

    public init() {
        self.init(open: { url in await Self.openInSystem(url) })
    }

    init(open: @escaping @Sendable (URL) async -> Bool) {
        self.open = open
    }

    public func execute(_ plan: FlareUpdateInstallPlan) async -> FlareUpdateInstallResult {
        guard case let .openStore(target) = plan else {
            return .failed(FlareUpdateErrorCode.installFailed)
        }
        for url in Self.urls(for: target) {
            if await open(url) {
                return FlareUpdateInstallResult(outcome: .completed)
            }
        }
        return .failed(FlareUpdateErrorCode.installFailed)
    }

    /// The links to try, best first: the manifest's own, then the store app and its web page from
    /// the app ID. `canOpenURL` would need the schemes declared by the host, so each is just tried.
    static func urls(for target: FlareUpdateStoreTarget) -> [URL] {
        var links: [String] = []
        if let url = target.url, !url.isEmpty {
            links.append(url)
        }
        if let appId = target.appId, !appId.isEmpty {
            switch target.store {
            case "appstore":
                links.append("\(storeScheme)://apps.apple.com/app/id\(appId)")
                links.append("https://apps.apple.com/app/id\(appId)")
            case "testflight":
                links.append("itms-beta://beta.itunes.apple.com/v1/app/\(appId)")
                links.append("https://beta.itunes.apple.com/v1/app/\(appId)")
            default:
                break
            }
        }
        return links.compactMap(URL.init(string:))
    }

    private static var storeScheme: String {
        #if os(macOS)
        return "macappstore"
        #else
        return "itms-apps"
        #endif
    }

    @MainActor
    private static func openInSystem(_ url: URL) async -> Bool {
        #if canImport(UIKit) && !os(watchOS)
        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
        #elseif canImport(AppKit)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }
}
