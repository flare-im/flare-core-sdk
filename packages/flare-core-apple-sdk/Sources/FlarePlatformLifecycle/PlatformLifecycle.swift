import Foundation
#if canImport(Network)
import Network
#endif
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Whether the app is in the foreground or the background.
public enum PlatformAppState: String, Equatable, Sendable {
    case foreground
    case background
}

/// The kind of the active network interface; the raw values are the SDK wire values.
public enum PlatformNetworkInterface: String, Equatable, Sendable {
    case unknown
    case wifi
    case cellular
    case ethernet
    case other
}

/// The network as the platform sees it.
public struct PlatformNetworkState: Equatable, Sendable {
    public var available: Bool
    public var interface: PlatformNetworkInterface?
    public var expensive: Bool?
    /// Low Data Mode on Apple platforms.
    public var metered: Bool?
    /// Coarse network identity, hashed locally into the network fingerprint: the default gateway's
    /// IPv4 /24 (or global IPv6 /64) prefix. Never an SSID or BSSID.
    public var fingerprintHint: String?

    public init(
        available: Bool,
        interface: PlatformNetworkInterface? = nil,
        expensive: Bool? = nil,
        metered: Bool? = nil,
        fingerprintHint: String? = nil
    ) {
        self.available = available
        self.interface = interface
        self.expensive = expensive
        self.metered = metered
        self.fingerprintHint = fingerprintHint
    }
}

/// Where network changes come from. `start` delivers the current state first, then every change,
/// on any thread, until `stop`.
public protocol PlatformNetworkSource: AnyObject {
    func start(_ onChange: @escaping @Sendable (PlatformNetworkState) -> Void)
    func stop()
}

/// Where foreground and background come from. `start` delivers the current state first when the
/// platform knows it, then every change, on any thread, until `stop`.
public protocol PlatformAppStateSource: AnyObject {
    func start(_ onChange: @escaping @Sendable (PlatformAppState) -> Void)
    func stop()
}

/// Reports the platform's network and foreground state to an SDK.
///
/// It references no SDK: the two report functions are injected. The core client wires them to
/// `connection.notifyNetworkChange` and `lifecycle.setAppState`, installs it when `init` succeeds
/// and removes it on `uninit`, `dispose` and `hardReset`; other SDKs reuse it the same way. Network
/// paths come from `NWPathMonitor`, foreground and background from `UIApplication` notifications
/// (`NSApplication` activation on macOS). The current state is reported once on install, repeats
/// are dropped, and reports are delivered in order. What to do with them is the SDK's decision;
/// apps add no wiring of their own.
public final class PlatformLifecycle: @unchecked Sendable {
    /// Reports a network change; `reason` is `initial` for the first report, then `path_change`.
    public typealias NotifyNetworkChange = @Sendable (_ state: PlatformNetworkState, _ reason: String) async throws -> Void
    /// Reports the app moving to the foreground or the background.
    public typealias SetAppState = @Sendable (_ state: PlatformAppState) async throws -> Void

    private enum Signal: Sendable {
        case network(PlatformNetworkState)
        case appState(PlatformAppState)
    }

    private let notifyNetworkChange: NotifyNetworkChange
    private let setAppState: SetAppState
    private let network: any PlatformNetworkSource
    private let appState: any PlatformAppStateSource
    private let onError: @Sendable (Error) -> Void
    private let lock = NSLock()
    private var continuation: AsyncStream<Signal>.Continuation?
    private var worker: Task<Void, Never>?
    private var installed = false
    private var disposed = false

    /// - Parameter onError: called when a report fails; reports are best effort.
    public init(
        notifyNetworkChange: @escaping NotifyNetworkChange,
        setAppState: @escaping SetAppState,
        network: any PlatformNetworkSource = SystemNetworkSource(),
        appState: any PlatformAppStateSource = SystemAppStateSource(),
        onError: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.notifyNetworkChange = notifyNetworkChange
        self.setAppState = setAppState
        self.network = network
        self.appState = appState
        self.onError = onError
    }

    deinit {
        dispose()
    }

    /// Starts listening and reports the current state. Calling it again does nothing.
    @discardableResult
    public func install() -> Self {
        lock.lock()
        guard !installed, !disposed else {
            lock.unlock()
            return self
        }
        installed = true
        var captured: AsyncStream<Signal>.Continuation?
        let stream = AsyncStream<Signal>(bufferingPolicy: .unbounded) { captured = $0 }
        let continuation = captured!
        self.continuation = continuation
        worker = Task { [notifyNetworkChange, setAppState, onError] in
            await Self.report(stream, notifyNetworkChange: notifyNetworkChange, setAppState: setAppState, onError: onError)
        }
        lock.unlock()
        network.start { continuation.yield(.network($0)) }
        appState.start { continuation.yield(.appState($0)) }
        return self
    }

    /// Stops listening; later changes are not reported.
    public func dispose() {
        lock.lock()
        guard !disposed else {
            lock.unlock()
            return
        }
        disposed = true
        let wasInstalled = installed
        let continuation = self.continuation
        let worker = self.worker
        self.continuation = nil
        self.worker = nil
        lock.unlock()
        guard wasInstalled else { return }
        network.stop()
        appState.stop()
        continuation?.finish()
        worker?.cancel()
    }

    private static func report(
        _ signals: AsyncStream<Signal>,
        notifyNetworkChange: NotifyNetworkChange,
        setAppState: SetAppState,
        onError: @Sendable (Error) -> Void
    ) async {
        var lastNetwork: PlatformNetworkState?
        var lastAppState: PlatformAppState?
        for await signal in signals {
            switch signal {
            case .network(let state):
                guard state != lastNetwork else { continue }
                let reason = lastNetwork == nil ? "initial" : "path_change"
                lastNetwork = state
                do {
                    try await notifyNetworkChange(state, reason)
                } catch {
                    onError(error)
                }
            case .appState(let state):
                guard state != lastAppState else { continue }
                lastAppState = state
                do {
                    try await setAppState(state)
                } catch {
                    onError(error)
                }
            }
        }
    }
}

/// The system network path, from `NWPathMonitor`.
public final class SystemNetworkSource: PlatformNetworkSource, @unchecked Sendable {
    private let queue = DispatchQueue(label: "im.flare.sdk.platform-lifecycle.network")
    private let lock = NSLock()
    #if canImport(Network)
    private var monitor: NWPathMonitor?
    #endif

    public init() {}

    public func start(_ onChange: @escaping @Sendable (PlatformNetworkState) -> Void) {
        #if canImport(Network)
        let monitor = NWPathMonitor()
        // The first update is the current path.
        monitor.pathUpdateHandler = { path in onChange(Self.state(of: path)) }
        lock.lock()
        self.monitor?.cancel()
        self.monitor = monitor
        lock.unlock()
        monitor.start(queue: queue)
        #endif
    }

    public func stop() {
        #if canImport(Network)
        lock.lock()
        let monitor = self.monitor
        self.monitor = nil
        lock.unlock()
        monitor?.cancel()
        #endif
    }

    #if canImport(Network)
    static func state(of path: NWPath) -> PlatformNetworkState {
        guard path.status == .satisfied else {
            return PlatformNetworkState(available: false)
        }
        let kind: PlatformNetworkInterface
        if path.usesInterfaceType(.wifi) {
            kind = .wifi
        } else if path.usesInterfaceType(.cellular) {
            kind = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            kind = .ethernet
        } else {
            kind = .other
        }
        // A cellular path has no stable gateway, and its MCC-MNC is not readable without
        // deprecated CoreTelephony placeholders: cellular reports no hint.
        return PlatformNetworkState(
            available: true,
            interface: kind,
            expensive: path.isExpensive,
            metered: path.isConstrained,
            fingerprintHint: kind == .cellular ? nil : gatewayPrefix(path.gateways)
        )
    }

    /// The first IPv4 gateway's /24, else the first global IPv6 gateway's /64.
    static func gatewayPrefix(_ gateways: [NWEndpoint]) -> String? {
        var ipv6: IPv6Address?
        for gateway in gateways {
            guard case let .hostPort(host, _) = gateway else { continue }
            switch host {
            case .ipv4(let address):
                let bytes = [UInt8](address.rawValue)
                guard bytes.count == 4 else { continue }
                return "\(bytes[0]).\(bytes[1]).\(bytes[2]).0/24"
            case .ipv6(let address):
                if ipv6 == nil, !address.isLinkLocal, !address.isLoopback {
                    ipv6 = address
                }
            default:
                continue
            }
        }
        guard let ipv6 else { return nil }
        let bytes = [UInt8](ipv6.rawValue)
        guard bytes.count == 16 else { return nil }
        let groups = stride(from: 0, to: 8, by: 2).map { index in
            String(UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1]), radix: 16)
        }
        return groups.joined(separator: ":") + "::/64"
    }
    #endif
}

/// Foreground and background: `UIApplication` notifications on iOS, activation on macOS.
public final class SystemAppStateSource: PlatformAppStateSource, @unchecked Sendable {
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func start(_ onChange: @escaping @Sendable (PlatformAppState) -> Void) {
        let center = NotificationCenter.default
        var added: [NSObjectProtocol] = []
        #if canImport(UIKit) && !os(watchOS)
        added.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            onChange(.background)
        })
        added.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            onChange(.foreground)
        })
        added.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            onChange(.foreground)
        })
        #elseif canImport(AppKit)
        added.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            onChange(.foreground)
        })
        added.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: nil) { _ in
            onChange(.background)
        })
        #endif
        lock.lock()
        observers.forEach(center.removeObserver)
        observers = added
        lock.unlock()
        Task { @MainActor in
            if let state = Self.currentState() {
                onChange(state)
            }
        }
    }

    public func stop() {
        lock.lock()
        let removed = observers
        observers = []
        lock.unlock()
        removed.forEach(NotificationCenter.default.removeObserver)
    }

    /// The application's state now, or nil outside an app (tests, command line tools).
    @MainActor
    private static func currentState() -> PlatformAppState? {
        #if canImport(UIKit) && !os(watchOS)
        // `UIApplication.shared` is unavailable to app extensions; look it up at run time so the
        // package also links into them (where there is no application to ask).
        let selector = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: selector),
              let application = UIApplication.perform(selector)?.takeUnretainedValue() as? UIApplication else {
            return nil
        }
        return application.applicationState == .background ? .background : .foreground
        #elseif canImport(AppKit)
        guard let application = NSApp else { return nil }
        return application.isActive ? .foreground : .background
        #else
        return nil
        #endif
    }
}
