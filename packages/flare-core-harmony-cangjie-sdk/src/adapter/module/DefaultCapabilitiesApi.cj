package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultCapabilitiesApi <: CapabilitiesApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func preparePluginCommand(request: PluginCommandRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPreparePluginCommand, requestJson: wireEncodeRequest(pluginCommandRequestToJson(request)))
    }

    public func pendingPluginCommand(request: PluginCommandRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPendingPluginCommand, requestJson: wireEncodeRequest(pluginCommandRequestToJson(request)))
    }

    public func reconcilePluginCommand(request: PluginCommandRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityReconcilePluginCommand, requestJson: wireEncodeRequest(pluginCommandRequestToJson(request)))
    }

    public func submitPluginCommand(request: PluginCommandRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilitySubmitPluginCommand, requestJson: wireEncodeRequest(pluginCommandRequestToJson(request)))
    }

    public func acknowledgePluginCommand(request: PluginCommandRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityAcknowledgePluginCommand, requestJson: wireEncodeRequest(pluginCommandRequestToJson(request)))
    }

    public func invokePluginAction(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginUiInvoke, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func presentPluginMessage(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginUiPresent, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func pluginUiAction(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginUiAction, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func resolvePluginMessage(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginUiResolve, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func pluginUiCatalog(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginUiCatalog, requestJson: wireEncodeRequest(requestJson))
    }

    public func pluginComposerActions(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginComposerActions, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func pluginDetail(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginDetail, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func pluginPage(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginPage, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func pluginFileUpload(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginFileUpload, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func pluginAccountEntries(request: PluginUiEvaluationRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityPluginAccountEntries, requestJson: wireEncodeRequest(pluginUiEvaluationRequestToJson(request)))
    }

    public func invalidatePluginCatalog(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.capabilityPluginCatalogInvalidate, requestJson: wireEncodeRequest(requestJson))
    }

    public func listCapabilities(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityList, requestJson: wireEncodeRequest(requestJson))
    }

    public func dispatchCapability(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.capabilityDispatch, requestJson: wireEncodeRequest(requestJson))
    }
}
