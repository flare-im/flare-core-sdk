package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultLifecycleApi <: LifecycleApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func setAppState(request: SetAppStateRequest): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.lifecycleSetAppState, requestJson: wireEncodeRequest(setAppStateRequestToJson(request)))
    }
}
