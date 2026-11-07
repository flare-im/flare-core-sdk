import Foundation
import FlarePlatformLifecycle

/// Builds the platform lifecycle a client installs after `init`.
public typealias PlatformLifecycleFactory = @Sendable (
    _ connection: any ConnectionApiProtocol,
    _ lifecycle: any LifecycleApiProtocol
) -> PlatformLifecycle

extension PlatformLifecycle {
    /// The platform lifecycle of a core client: network changes go to
    /// `connection.notifyNetworkChange`, foreground and background to `lifecycle.setAppState`.
    public convenience init(
        connection: any ConnectionApiProtocol,
        lifecycle: any LifecycleApiProtocol,
        network: any PlatformNetworkSource = SystemNetworkSource(),
        appState: any PlatformAppStateSource = SystemAppStateSource(),
        onError: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        let apis = ClientLifecycleApis(connection: connection, lifecycle: lifecycle)
        self.init(
            notifyNetworkChange: { state, reason in
                try await apis.connection.notifyNetworkChange(NetworkChangeRequest(
                    available: state.available,
                    interface: state.interface.flatMap { NetworkInterfaceKind(rawValue: $0.rawValue) },
                    expensive: state.expensive,
                    metered: state.metered,
                    reason: reason,
                    fingerprintHint: state.fingerprintHint
                ))
            },
            setAppState: { state in
                let appState: AppState
                switch state {
                case .foreground: appState = .foreground
                case .background: appState = .background
                }
                try await apis.lifecycle.setAppState(SetAppStateRequest(appState: appState))
            },
            network: network,
            appState: appState,
            onError: onError
        )
    }
}

/// The client's connection and lifecycle APIs, handed to the report closures. The generated
/// adapters hold only their bridge and are safe to call from any task.
private final class ClientLifecycleApis: @unchecked Sendable {
    let connection: any ConnectionApiProtocol
    let lifecycle: any LifecycleApiProtocol

    init(connection: any ConnectionApiProtocol, lifecycle: any LifecycleApiProtocol) {
        self.connection = connection
        self.lifecycle = lifecycle
    }
}
