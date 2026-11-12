#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
import Foundation
import Network

/// Native side of the Flare Core platform lifecycle on iOS and macOS.
///
/// - Method channel `flare_core_flutter_lifecycle`: `appInfo` answers
///   `{version, build, distribution}` from the main bundle.
/// - Event channel `flare_core_flutter_lifecycle/network`: network readings
///   `{available, interface, expensive, fingerprintHint}` from `NWPathMonitor`,
///   the current path first. The hint is the native package's (a hash of the interface kind and the
///   gateway, see `FlareNetworkReading.gatewayFingerprint`), never an address.
/// - Event channel `flare_core_flutter_lifecycle/links`, macOS only: the URLs the system opens the app
///   with. iOS has no need of it: the engine hands a link over as a route, and on macOS it does not.
public final class FlareCoreFlutterLifecyclePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let queue = DispatchQueue(label: "im.flare.lifecycle.network")
    private var monitor: NWPathMonitor?
    #if os(macOS)
    private let openedLinks = FlareOpenedLinks()
    #endif

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        let instance = FlareCoreFlutterLifecyclePlugin()
        let methods = FlutterMethodChannel(name: "flare_core_flutter_lifecycle", binaryMessenger: messenger)
        registrar.addMethodCallDelegate(instance, channel: methods)
        let network = FlutterEventChannel(name: "flare_core_flutter_lifecycle/network", binaryMessenger: messenger)
        network.setStreamHandler(instance)
        #if os(macOS)
        let links = FlutterEventChannel(name: "flare_core_flutter_lifecycle/links", binaryMessenger: messenger)
        links.setStreamHandler(instance.openedLinks)
        registrar.addApplicationDelegate(instance)
        #endif
    }

    #if os(macOS)
    /// `application:openURLs:`, by way of `FlutterAppDelegate`. The selector is spelled out because the
    /// Swift name is the importer's shortening of it.
    @objc(handleOpenURLs:)
    public func handleOpen(_ urls: [URL]) -> Bool {
        urls.forEach { openedLinks.receive($0.absoluteString) }
        return !urls.isEmpty
    }
    #endif

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "appInfo":
            result(FlareAppInfoReader.read(bundle: .main))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        stopMonitor()
        let pathMonitor = NWPathMonitor()
        // The handler runs on `queue`, first with the current path; the sink lives on the main thread.
        pathMonitor.pathUpdateHandler = { [weak self, weak pathMonitor] path in
            let reading = FlareNetworkReading.read(path)
            DispatchQueue.main.async {
                // Readings of a monitor that has since been cancelled are dropped.
                guard let self, let pathMonitor, self.monitor === pathMonitor else { return }
                events(reading)
            }
        }
        monitor = pathMonitor
        pathMonitor.start(queue: queue)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopMonitor()
        return nil
    }

    private func stopMonitor() {
        monitor?.cancel()
        monitor = nil
    }
}

#if os(macOS)
/// The stream of the links channel. The link of a cold start arrives before Dart listens, so it waits here.
final class FlareOpenedLinks: NSObject, FlutterStreamHandler {
    private var pending: [String] = []
    private var sink: FlutterEventSink?

    func receive(_ link: String) {
        if let sink {
            sink(link)
        } else {
            pending.append(link)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        pending.forEach { events($0) }
        pending = []
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}
#endif

/// One `NWPath` as the Dart side reads it. Duplicates are fine: only changes are reported.
enum FlareNetworkReading {
    static func read(_ path: NWPath) -> [String: Any] {
        let available = path.status == .satisfied
        var reading: [String: Any] = ["available": available]
        guard available else { return reading }
        let kind: String
        if path.usesInterfaceType(.wifi) {
            kind = "wifi"
        } else if path.usesInterfaceType(.cellular) {
            kind = "cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            kind = "ethernet"
        } else {
            kind = "other"
        }
        reading["interface"] = kind
        reading["expensive"] = path.isExpensive
        // Cellular gives no hint: MCC-MNC needs CoreTelephony carrier APIs that iOS 16.4 retired.
        if kind != "cellular", let hint = gatewayFingerprint(kind: kind, gateways: path.gateways) {
            reading["fingerprintHint"] = hint
        }
        return reading
    }

    /// The network's identity as a hash: 16 hex digits of SHA-256 over the interface kind and the
    /// gateway (see `gatewayIdentity`). The exact algorithm of the native package's
    /// `SystemNetworkSource.gatewayFingerprint` (`FlarePlatformLifecycle`), so a Flutter app and a
    /// native app report the same hint on the same network. Without location permission there is no
    /// SSID or BSSID to go by; the gateway tells most networks apart and is the same every time the
    /// device joins one. Never an address, an SSID or a BSSID. Nil without a usable gateway.
    static func gatewayFingerprint(kind: String, gateways: [NWEndpoint]) -> String? {
        guard let gateway = gatewayIdentity(gateways) else { return nil }
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data("flare.gateway.v1\u{0}\(kind)\u{0}\(gateway)".utf8))
        return hex(digest.prefix(8))
        #else
        return nil
        #endif
    }

    /// The gateway the fingerprint is taken from: the first IPv4 gateway's address, else the /64 of
    /// the first global IPv6 gateway, else the first link-local IPv6 gateway (the router's own
    /// address on the link, which stays put while the advertised prefix may be renumbered).
    /// IPv4 wins whenever there is one, so a dual-stack network keeps one identity. It only feeds the
    /// hash and never leaves this type.
    static func gatewayIdentity(_ gateways: [NWEndpoint]) -> String? {
        var global: IPv6Address?
        var linkLocal: IPv6Address?
        for gateway in gateways {
            guard case let .hostPort(host, _) = gateway else { continue }
            switch host {
            case .ipv4(let address):
                let bytes = [UInt8](address.rawValue)
                guard bytes.count == 4 else { continue }
                return "4:" + bytes.map { String($0) }.joined(separator: ".")
            case .ipv6(let address):
                if address.isLoopback {
                    continue
                } else if address.isLinkLocal {
                    linkLocal = linkLocal ?? address
                } else {
                    global = global ?? address
                }
            default:
                continue
            }
        }
        if let global {
            return "6g:" + hex([UInt8](global.rawValue).prefix(8))
        }
        if let linkLocal {
            return "6l:" + hex([UInt8](linkLocal.rawValue))
        }
        return nil
    }

    private static func hex<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

/// The bundle's version facts for `sdkConfig.app`; keys it cannot read are left out.
enum FlareAppInfoReader {
    static func read(bundle: Bundle) -> [String: Any] {
        let info = bundle.infoDictionary ?? [:]
        var app: [String: Any] = [:]
        if let version = (info["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespaces), !version.isEmpty {
            app["version"] = version
        }
        if let build = (info["CFBundleVersion"] as? String).flatMap(buildNumber) {
            app["build"] = NSNumber(value: build)
        }
        if let distribution = distribution(bundle: bundle) {
            app["distribution"] = distribution
        }
        return app
    }

    /// `CFBundleVersion` counts as the build only when it is a plain integer: the server compares
    /// builds as integers, and `1.2.3` has no monotonic integer to compare.
    static func buildNumber(_ raw: String) -> Int64? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int64(trimmed)
    }

    /// iOS: `testflight` for a sandbox receipt, `appstore` for a store receipt; development and
    /// ad hoc builds (they carry a provisioning profile) give none. macOS: `appstore` /
    /// `testflight` by the Mac App Store receipt, `direct` without one.
    static func distribution(bundle: Bundle) -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        let receipt = bundle.appStoreReceiptURL
        let receiptExists = receipt.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let sandbox = receipt?.lastPathComponent == "sandboxReceipt"
        #if os(iOS)
        if bundle.path(forResource: "embedded", ofType: "mobileprovision") != nil {
            return nil
        }
        if sandbox {
            return "testflight"
        }
        return receiptExists ? "appstore" : nil
        #else
        guard receiptExists else { return "direct" }
        return sandbox ? "testflight" : "appstore"
        #endif
        #endif
    }
}
