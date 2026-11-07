package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultDiagnosticsApi <: DiagnosticsApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func getSdkVersion(): String {
        return bridge.invoke(descriptor: NativeCallMap.diagnosticsSdkVersion, requestJson: wireEncodeRequest("{}"))
    }

    public func getFfiContractVersion(): String {
        return bridge.invoke(descriptor: NativeCallMap.diagnosticsFfiContractVersion, requestJson: wireEncodeRequest("{}"))
    }

    public func getDataRoot(): String {
        return bridge.invoke(descriptor: NativeCallMap.diagnosticsDataRoot, requestJson: wireEncodeRequest("{}"))
    }

    public func getRuntimeHealth(): RuntimeHealthResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.diagnosticsRuntimeHealth, requestJson: wireEncodeRequest("{}"))
        return runtimeHealthResponseFromJson(raw)
    }
}
