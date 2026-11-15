import Foundation
#if canImport(Network)
import Network
#endif
#if canImport(CryptoKit)
import CryptoKit
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
    /// Coarse network identity, hashed again by the SDK into the network fingerprint: a hash of the
    /// interface kind and the default gateway that changes from one network to the next without
    /// location permission. Never an address, an SSID or a BSSID.
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
///
/// 进后台时，系统在通知回调返回后随时可能挂起进程，而 iOS 上 `setAppState(background)` 要等托管
/// 交接做完才返回（约 3.5 秒以内）。所以后台执行在通知回调里同步申请，这次上报返回（或被判为重复）
/// 后结束，系统先收回时也随之结束。
public final class PlatformLifecycle: @unchecked Sendable {
    /// Reports a network change; `reason` is `initial` for the first report, then `path_change`.
    public typealias NotifyNetworkChange = @Sendable (_ state: PlatformNetworkState, _ reason: String) async throws -> Void
    /// Reports the app moving to the foreground or the background.
    public typealias SetAppState = @Sendable (_ state: PlatformAppState) async throws -> Void

    private enum Signal: Sendable {
        case network(PlatformNetworkState)
        case appState(PlatformAppState, PlatformBackgroundTask?)
    }

    private let notifyNetworkChange: NotifyNetworkChange
    private let setAppState: SetAppState
    private let network: any PlatformNetworkSource
    private let appState: any PlatformAppStateSource
    private let backgroundExecution: any PlatformBackgroundExecution
    private let onError: @Sendable (Error) -> Void
    private let openTasks = OpenBackgroundTasks()
    private let lock = NSLock()
    private var continuation: AsyncStream<Signal>.Continuation?
    private var worker: Task<Void, Never>?
    private var installed = false
    private var disposed = false

    /// - Parameter backgroundExecution: 进后台上报期间持有的后台执行；默认是系统的后台任务。
    /// - Parameter onError: called when a report fails; reports are best effort.
    public init(
        notifyNetworkChange: @escaping NotifyNetworkChange,
        setAppState: @escaping SetAppState,
        network: any PlatformNetworkSource = SystemNetworkSource(),
        appState: any PlatformAppStateSource = SystemAppStateSource(),
        backgroundExecution: any PlatformBackgroundExecution = SystemBackgroundExecution(),
        onError: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.notifyNetworkChange = notifyNetworkChange
        self.setAppState = setAppState
        self.network = network
        self.appState = appState
        self.backgroundExecution = backgroundExecution
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
        appState.start { [backgroundExecution, openTasks] state in
            let task = state == .background ? backgroundExecution.begin(name: "im.flare.sdk.app-state") : nil
            if let task {
                openTasks.add(task)
            }
            if case .terminated = continuation.yield(.appState(state, task)) {
                task?.end()
            }
        }
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
        // 取消后排队的信号不再处理，它们带的后台执行在这里结束，不等系统到期
        openTasks.endAll()
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
            case .appState(let state, let task):
                defer { task?.end() }
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

/// 已申请、还没结束的后台执行。
private final class OpenBackgroundTasks: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [PlatformBackgroundTask] = []

    func add(_ task: PlatformBackgroundTask) {
        lock.lock()
        tasks.removeAll { $0.ended }
        tasks.append(task)
        lock.unlock()
    }

    func endAll() {
        lock.lock()
        let open = tasks
        tasks = []
        lock.unlock()
        open.forEach { $0.end() }
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
            fingerprintHint: kind == .cellular ? nil : gatewayFingerprint(kind: kind, gateways: path.gateways)
        )
    }

    /// The network's identity as a hash: 16 hex digits of SHA-256 over the interface kind and the
    /// gateway (see `gatewayIdentity`). Without location permission there is no SSID or BSSID to go
    /// by; the gateway tells most networks apart and is the same every time the device joins one.
    /// Nil without a usable gateway.
    static func gatewayFingerprint(kind: PlatformNetworkInterface, gateways: [NWEndpoint]) -> String? {
        guard let gateway = gatewayIdentity(gateways) else { return nil }
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data("flare.gateway.v1\u{0}\(kind.rawValue)\u{0}\(gateway)".utf8))
        return hex(digest.prefix(8))
        #else
        return nil
        #endif
    }

    /// The gateway the fingerprint is taken from: the first IPv4 gateway's address, else the /64 of
    /// the first global IPv6 gateway, else the first link-local IPv6 gateway (the router's own
    /// address on the link, which stays put while the advertised prefix may be renumbered).
    /// IPv4 wins whenever there is one, so a dual-stack network keeps one identity.
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
        guard let application = SharedApplication.current else {
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
