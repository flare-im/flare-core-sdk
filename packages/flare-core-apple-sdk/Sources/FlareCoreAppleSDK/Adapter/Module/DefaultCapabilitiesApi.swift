import Foundation

/// GENERATED. Do not edit by hand.
public final class DefaultCapabilitiesApi: CapabilitiesApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func preparePluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPreparePluginCommand, request: pluginCommandRequestToMap(request))
    }

    public func pendingPluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPendingPluginCommand, request: pluginCommandRequestToMap(request))
    }

    public func reconcilePluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityReconcilePluginCommand, request: pluginCommandRequestToMap(request))
    }

    public func submitPluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilitySubmitPluginCommand, request: pluginCommandRequestToMap(request))
    }

    public func acknowledgePluginCommand(_ request: PluginCommandRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityAcknowledgePluginCommand, request: pluginCommandRequestToMap(request))
    }

    public func invokePluginAction(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginUiInvoke, request: pluginUiEvaluationRequestToMap(request))
    }

    public func presentPluginMessage(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginUiPresent, request: pluginUiEvaluationRequestToMap(request))
    }

    public func pluginUiAction(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginUiAction, request: pluginUiEvaluationRequestToMap(request))
    }

    public func resolvePluginMessage(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginUiResolve, request: pluginUiEvaluationRequestToMap(request))
    }

    public func pluginUiCatalog(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginUiCatalog, request: unwrapRequest(AnySendable(request)))
    }

    public func pluginComposerActions(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginComposerActions, request: pluginUiEvaluationRequestToMap(request))
    }

    public func pluginDetail(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginDetail, request: pluginUiEvaluationRequestToMap(request))
    }

    public func pluginPage(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginPage, request: pluginUiEvaluationRequestToMap(request))
    }

    public func pluginFileUpload(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginFileUpload, request: pluginUiEvaluationRequestToMap(request))
    }

    public func pluginAccountEntries(_ request: PluginUiEvaluationRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityPluginAccountEntries, request: pluginUiEvaluationRequestToMap(request))
    }

    public func invalidatePluginCatalog(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.capabilityPluginCatalogInvalidate, request: AnySendable(request))
    }

    public func listCapabilities(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityList, request: unwrapRequest(AnySendable(request)))
    }

    public func dispatchCapability(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.capabilityDispatch, request: unwrapRequest(AnySendable(request)))
    }
}
