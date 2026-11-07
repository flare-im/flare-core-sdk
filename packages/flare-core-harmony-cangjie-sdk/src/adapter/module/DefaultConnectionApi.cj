package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultConnectionApi <: ConnectionApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func getStatus(): ConnectionStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.connectionGetStatus, requestJson: wireEncodeRequest("{}"))
        return connectionStatusFromJson(raw)
    }

    public func reconnectNow(): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.connectionReconnectNow, requestJson: wireEncodeRequest("{}"))
    }

    public func disconnect(): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.connectionDisconnect, requestJson: wireEncodeRequest("{}"))
    }

    public func getServerClock(): ServerClockResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.connectionServerClock, requestJson: wireEncodeRequest("{}"))
        return serverClockResponseFromJson(raw)
    }

    public func notifyNetworkChange(request: NetworkChangeRequest): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.connectionNotifyNetworkChange, requestJson: wireEncodeRequest(networkChangeRequestToJson(request)))
    }
}
