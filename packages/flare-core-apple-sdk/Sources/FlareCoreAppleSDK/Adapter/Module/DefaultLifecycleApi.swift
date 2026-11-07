import Foundation

/// GENERATED. Do not edit by hand.
public final class DefaultLifecycleApi: LifecycleApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func setAppState(_ request: SetAppStateRequest) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.lifecycleSetAppState, request: AnySendable(setAppStateRequestToMap(request)))
    }
}
