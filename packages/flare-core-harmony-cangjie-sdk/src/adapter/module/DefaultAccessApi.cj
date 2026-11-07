package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultAccessApi <: AccessApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func getStatus(): AccessStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.accessGetStatus, requestJson: wireEncodeRequest("{}"))
        return accessStatusFromJson(raw)
    }

    public func listAccessPoints(): Array<AccessPointInfo> {
        let raw = bridge.invoke(descriptor: NativeCallMap.accessListAccessPoints, requestJson: wireEncodeRequest("{}"))
        return accessPointInfoListFromJson(raw)
    }

    public func pin(request: AccessPinRequest): AccessPin {
        let raw = bridge.invoke(descriptor: NativeCallMap.accessPin, requestJson: wireEncodeRequest(accessPinRequestToJson(request)))
        return accessPinFromJson(raw)
    }

    public func unpin(): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.accessUnpin, requestJson: wireEncodeRequest("{}"))
    }

    public func refresh(): AccessRefreshReport {
        let raw = bridge.invoke(descriptor: NativeCallMap.accessRefresh, requestJson: wireEncodeRequest("{}"))
        return accessRefreshReportFromJson(raw)
    }

    public func importRecovery(request: AccessImportRecoveryRequest): AccessRecoveryImport {
        let raw = bridge.invoke(descriptor: NativeCallMap.accessImportRecovery, requestJson: wireEncodeRequest(accessImportRecoveryRequestToJson(request)))
        return accessRecoveryImportFromJson(raw)
    }

    public func exportDiagnostics(): JsonValue {
        let raw = bridge.invoke(descriptor: NativeCallMap.accessExportDiagnostics, requestJson: wireEncodeRequest("{}"))
        return JsonValue(raw)
    }
}
