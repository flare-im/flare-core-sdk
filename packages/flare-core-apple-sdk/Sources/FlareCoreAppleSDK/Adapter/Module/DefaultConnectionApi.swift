import Foundation

/// GENERATED. Do not edit by hand.
public final class DefaultConnectionApi: ConnectionApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func getStatus() async throws -> ConnectionStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.connectionGetStatus, request: nil)
        return try connectionStatusFromJson(raw)
    }

    public func reconnectNow() async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.connectionReconnectNow, request: nil)
    }

    public func replaceEndpoints(_ request: CoreEndpoints) async throws -> EndpointUpdate {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.connectionReplaceEndpoints, request: coreEndpointsToMap(request))
        return try endpointUpdateFromJson(raw)
    }

    public func setProtocolMode(_ request: SetProtocolModeRequest) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.connectionSetProtocolMode, request: AnySendable(setProtocolModeRequestToMap(request)))
    }

    public func disconnect() async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.connectionDisconnect, request: nil)
    }

    public func getServerClock() async throws -> ServerClockResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.connectionServerClock, request: nil)
        return try serverClockResponseFromJson(raw)
    }

    public func notifyNetworkChange(_ request: NetworkChangeRequest) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.connectionNotifyNetworkChange, request: AnySendable(networkChangeRequestToMap(request)))
    }
}
