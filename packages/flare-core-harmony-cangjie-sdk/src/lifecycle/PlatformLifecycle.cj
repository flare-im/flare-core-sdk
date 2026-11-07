package flare_core_harmony_cangjie_sdk.lifecycle

import std.sync.Mutex
import flare_core_harmony_cangjie_sdk.api.*
import flare_core_harmony_cangjie_sdk.model.*

// The default network as the platform sees it. `fingerprintHint` is coarse on purpose: a Wi-Fi or
// Ethernet gateway prefix, or a cellular MCC-MNC; never an SSID or BSSID.
public class NetworkSnapshot {
    public let available: Bool
    public let interfaceKind: ?NetworkInterfaceKind
    public let expensive: ?Bool
    public let metered: ?Bool
    public let fingerprintHint: ?String

    public init(available!: Bool, interfaceKind!: ?NetworkInterfaceKind = None, expensive!: ?Bool = None,
        metered!: ?Bool = None, fingerprintHint!: ?String = None) {
        this.available = available
        this.interfaceKind = interfaceKind
        this.expensive = expensive
        this.metered = metered
        this.fingerprintHint = fingerprintHint
    }
}

// Where network changes come from. `onChange` runs on every platform network callback, on any
// thread, with a reason for diagnostics.
public interface PlatformNetworkSource {
    func start(onChange: (String) -> Unit): Unit
    func current(): NetworkSnapshot
    func stop(): Unit
}

// Where foreground and background come from. `onChange` may run on any thread.
public interface PlatformAppStateSource {
    func start(onChange: (AppState) -> Unit): Unit
    func current(): AppState
    func stop(): Unit
}

// Platform lifecycle for the Cangjie package: `initSdk` installs it unless the init JSON says
// `"installPlatformLifecycle": false`; `dispose`, `uninit` and `hardReset` remove it.
//
// Network snapshots go to `connection.notifyNetworkChange` and application states to
// `lifecycle.setAppState`. Right after install it reports the current network and state once;
// afterwards only changes: a network report repeats only when availability, interface, cost or
// fingerprint hint changed. Reports never throw; a rejected report goes to `onError`.
//
// Not wired: this package has no HarmonyOS network or application-state source of its own yet
// (the native bridge is not linked either), so the client installs it without sources and it
// reports nothing. A host that has sources passes them here, with `installPlatformLifecycle: false`.
public class PlatformLifecycle {
    private let client: FlareImClient
    private let network: ?PlatformNetworkSource
    private let appState: ?PlatformAppStateSource
    private let onError: Option<(Exception) -> Unit>
    private let mutex: Mutex = Mutex()
    private var lastNetworkKey: ?String = None
    private var lastAppState: ?String = None
    private var installed: Bool = false
    private var disposed: Bool = false

    public init(client: FlareImClient, network!: ?PlatformNetworkSource = None,
        appState!: ?PlatformAppStateSource = None, onError!: Option<(Exception) -> Unit> = None) {
        this.client = client
        this.network = network
        this.appState = appState
        this.onError = onError
    }

    // Starts both sources and reports the current network and application state once.
    public func install(): PlatformLifecycle {
        var first = false
        synchronized(mutex) {
            if (!installed && !disposed) {
                installed = true
                first = true
            }
        }
        if (!first) {
            return this
        }
        match (network) {
            case Some(source) => source.start({ reason: String => refreshNetwork(reason) })
            case None => ()
        }
        match (appState) {
            case Some(source) => source.start({ state: AppState => reportAppState(state) })
            case None => ()
        }
        sync()
        return this
    }

    // Reports the current network and application state now (each only if it changed).
    public func sync(): Unit {
        refreshNetwork("initial")
        match (appState) {
            case Some(source) => reportAppState(source.current())
            case None => ()
        }
    }

    // Stops both sources; later callbacks are ignored.
    public func dispose(): Unit {
        var stop = false
        synchronized(mutex) {
            if (!disposed) {
                disposed = true
                stop = installed
            }
        }
        if (!stop) {
            return
        }
        match (network) {
            case Some(source) => source.stop()
            case None => ()
        }
        match (appState) {
            case Some(source) => source.stop()
            case None => ()
        }
    }

    private func refreshNetwork(reason: String): Unit {
        match (network) {
            case Some(source) => reportNetwork(source.current(), reason)
            case None => ()
        }
    }

    private func reportNetwork(snapshot: NetworkSnapshot, reason: String): Unit {
        let key = networkSnapshotKey(snapshot)
        var changed = false
        synchronized(mutex) {
            let same = match (lastNetworkKey) {
                case Some(last) => last == key
                case None => false
            }
            if (!disposed && !same) {
                lastNetworkKey = Some(key)
                changed = true
            }
        }
        if (changed) {
            try {
                client.connection.notifyNetworkChange(networkChangeRequest(snapshot, reason))
            } catch (e: Exception) {
                reportError(e)
            }
        }
    }

    private func reportAppState(state: AppState): Unit {
        let key = appStateKey(state)
        var changed = false
        synchronized(mutex) {
            let same = match (lastAppState) {
                case Some(last) => last == key
                case None => false
            }
            if (!disposed && !same) {
                lastAppState = Some(key)
                changed = true
            }
        }
        if (changed) {
            try {
                client.lifecycle.setAppState(SetAppStateRequest(appState: state))
            } catch (e: Exception) {
                reportError(e)
            }
        }
    }

    private func reportError(e: Exception): Unit {
        match (onError) {
            case Some(handler) => handler(e)
            case None => ()
        }
    }
}

public func appStateKey(state: AppState): String {
    return match (state) {
        case AppState.Foreground => "foreground"
        case AppState.Background => "background"
    }
}

// Two snapshots with the same key are the same network to the core; only a new key is reported.
public func networkSnapshotKey(snapshot: NetworkSnapshot): String {
    let available = if (snapshot.available) { "1" } else { "0" }
    let kind = match (snapshot.interfaceKind) {
        case Some(value) => interfaceKindKey(value)
        case None => ""
    }
    let hint = match (snapshot.fingerprintHint) {
        case Some(value) => value
        case None => ""
    }
    return "${available}|${kind}|${optionalBoolKey(snapshot.expensive)}|${optionalBoolKey(snapshot.metered)}|${hint}"
}

public func networkChangeRequest(snapshot: NetworkSnapshot, reason: String): NetworkChangeRequest {
    let hint: ?String = match (snapshot.fingerprintHint) {
        case Some(value) => if (value.isEmpty()) { None } else { Some(value) }
        case None => None
    }
    return NetworkChangeRequest(
        available: Some(snapshot.available),
        interface: snapshot.interfaceKind,
        expensive: snapshot.expensive,
        metered: snapshot.metered,
        reason: Some(reason),
        fingerprintHint: hint
    )
}

func interfaceKindKey(kind: NetworkInterfaceKind): String {
    return match (kind) {
        case NetworkInterfaceKind.Unknown => "unknown"
        case NetworkInterfaceKind.Wifi => "wifi"
        case NetworkInterfaceKind.Cellular => "cellular"
        case NetworkInterfaceKind.Ethernet => "ethernet"
        case NetworkInterfaceKind.Other => "other"
    }
}

func optionalBoolKey(value: ?Bool): String {
    return match (value) {
        case Some(true) => "1"
        case Some(false) => "0"
        case None => ""
    }
}
