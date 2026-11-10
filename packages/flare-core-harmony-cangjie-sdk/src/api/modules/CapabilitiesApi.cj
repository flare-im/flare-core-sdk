package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Capability discovery and optional plugin dispatch through capability dispatch ops.
public interface CapabilitiesApi {
    func preparePluginCommand(request: PluginCommandRequest): String
    func pendingPluginCommand(request: PluginCommandRequest): String
    func reconcilePluginCommand(request: PluginCommandRequest): String
    func submitPluginCommand(request: PluginCommandRequest): String
    func acknowledgePluginCommand(request: PluginCommandRequest): String
    func invokePluginAction(request: PluginUiEvaluationRequest): String
    func presentPluginMessage(request: PluginUiEvaluationRequest): String
    func pluginUiAction(request: PluginUiEvaluationRequest): String
    func resolvePluginMessage(request: PluginUiEvaluationRequest): String
    func pluginUiCatalog(requestJson: String): String
    func pluginComposerActions(request: PluginUiEvaluationRequest): String
    func pluginDetail(request: PluginUiEvaluationRequest): String
    func pluginPage(request: PluginUiEvaluationRequest): String
    func pluginFileUpload(request: PluginUiEvaluationRequest): String
    func pluginAccountEntries(request: PluginUiEvaluationRequest): String
    func invalidatePluginCatalog(requestJson: String): Unit
    func listCapabilities(requestJson: String): String
    func dispatchCapability(requestJson: String): String
}
