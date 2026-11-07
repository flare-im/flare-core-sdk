package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultUpdateApi <: UpdateApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func getState(request: UpdateGetStateRequest): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateGetState, requestJson: wireEncodeRequest(updateGetStateRequestToJson(request)))
        return updateStatusFromJson(raw)
    }

    public func check(request: UpdateCheckRequest): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateCheck, requestJson: wireEncodeRequest(updateCheckRequestToJson(request)))
        return updateStatusFromJson(raw)
    }

    public func download(request: UpdateDownloadRequest): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateDownload, requestJson: wireEncodeRequest(updateDownloadRequestToJson(request)))
        return updateStatusFromJson(raw)
    }

    public func install(): UpdateInstallPlan {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateInstall, requestJson: wireEncodeRequest("{}"))
        return updateInstallPlanFromJson(raw)
    }

    public func reportInstall(request: UpdateReportInstallRequest): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateReportInstall, requestJson: wireEncodeRequest(updateReportInstallRequestToJson(request)))
        return updateStatusFromJson(raw)
    }

    public func defer(): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateDefer, requestJson: wireEncodeRequest("{}"))
        return updateStatusFromJson(raw)
    }

    public func skip(request: UpdateSkipRequest): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateSkip, requestJson: wireEncodeRequest(updateSkipRequestToJson(request)))
        return updateStatusFromJson(raw)
    }

    public func markPrompted(request: UpdateMarkPromptedRequest): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateMarkPrompted, requestJson: wireEncodeRequest(updateMarkPromptedRequestToJson(request)))
        return updateStatusFromJson(raw)
    }

    public func setLocale(request: UpdateSetLocaleRequest): UpdateStatus {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateSetLocale, requestJson: wireEncodeRequest(updateSetLocaleRequestToJson(request)))
        return updateStatusFromJson(raw)
    }

    public func getResources(request: UpdateGetResourcesRequest): UpdateResources {
        let raw = bridge.invoke(descriptor: NativeCallMap.updateGetResources, requestJson: wireEncodeRequest(updateGetResourcesRequestToJson(request)))
        return updateResourcesFromJson(raw)
    }
}
