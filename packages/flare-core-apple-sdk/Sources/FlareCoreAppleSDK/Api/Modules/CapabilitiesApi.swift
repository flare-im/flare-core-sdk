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
    func pluginAccountEntries(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable]
    func invalidatePluginCatalog(_ request: [String: AnySendable]) async throws -> Void
    func listCapabilities(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func dispatchCapability(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
}
