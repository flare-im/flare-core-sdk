package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Connection status and manual network lifecycle.
public interface ConnectionApi {
    func getStatus(): ConnectionStatus
    func reconnectNow(): Unit
    func disconnect(): Unit
    func getServerClock(): ServerClockResponse
    func notifyNetworkChange(request: NetworkChangeRequest): Unit
}
