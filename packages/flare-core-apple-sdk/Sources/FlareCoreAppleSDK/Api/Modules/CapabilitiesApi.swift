import Foundation

/// GENERATED. Do not edit by hand.
/// Capability discovery and optional plugin dispatch through capability dispatch ops.
public protocol CapabilitiesApiProtocol: AnyObject {
    func preparePluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable]
    func pendingPluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable]
    func reconcilePluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable]
    func submitPluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable]
    func acknowledgePluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable]
    func invokePluginAction(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func presentPluginMessage(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginUiAction(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func resolvePluginMessage(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginUiCatalog(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func pluginComposerActions(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginDetail(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginPage(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginFileUpload(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginCapabilityInvoke(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginCapabilityConsents(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func revokePluginCapabilityConsent(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginBundleOpen(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginBundleBridge(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginBundleHostResult(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginBundleHostEvent(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginBundleClose(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginBundlePrefetch(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func completePluginCapabilityRequest(_ request: PluginCapabilityCompletion) async throws -> Void
    func pluginAccountEntries(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func pluginScanHandlers(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func invalidatePluginCatalog(_ request: [String: AnySendable]) async throws -> Void
    func setPluginHostProfile(_ request: PluginHostProfile) async throws -> Void
    func listCapabilities(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func dispatchCapability(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func pluginNativeInvoke(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
}
