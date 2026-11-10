// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { CapabilitiesApi } from '../../api/modules/capabilities';
import type { PluginCommandRequest, PluginUiEvaluationRequest } from '../../model';
import { invokeMap, invokeVoid } from '../codec/NativeInvoke';
import { pluginCommandRequestToMap, pluginUiEvaluationRequestToMap } from '../codec/WireCodec';

export class DefaultCapabilitiesApi implements CapabilitiesApi {
  constructor(private readonly bridge: NativeBridge) {}

  async preparePluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPreparePluginCommand, pluginCommandRequestToMap(request));
  }

  async pendingPluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPendingPluginCommand, pluginCommandRequestToMap(request));
  }

  async reconcilePluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityReconcilePluginCommand, pluginCommandRequestToMap(request));
  }

  async submitPluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilitySubmitPluginCommand, pluginCommandRequestToMap(request));
  }

  async acknowledgePluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityAcknowledgePluginCommand, pluginCommandRequestToMap(request));
  }

  async invokePluginAction(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginUiInvoke, pluginUiEvaluationRequestToMap(request));
  }

  async presentPluginMessage(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginUiPresent, pluginUiEvaluationRequestToMap(request));
  }

  async pluginUiAction(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginUiAction, pluginUiEvaluationRequestToMap(request));
  }

  async resolvePluginMessage(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginUiResolve, pluginUiEvaluationRequestToMap(request));
  }

  async pluginUiCatalog(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginUiCatalog, request);
  }

  async pluginComposerActions(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginComposerActions, pluginUiEvaluationRequestToMap(request));
  }

  async pluginDetail(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginDetail, pluginUiEvaluationRequestToMap(request));
  }

  async pluginPage(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginPage, pluginUiEvaluationRequestToMap(request));
  }

  async pluginFileUpload(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginFileUpload, pluginUiEvaluationRequestToMap(request));
  }

  async pluginAccountEntries(request: PluginUiEvaluationRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityPluginAccountEntries, pluginUiEvaluationRequestToMap(request));
  }

  async invalidatePluginCatalog(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.capabilityPluginCatalogInvalidate, request);
  }

  async listCapabilities(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityList, request);
  }

  async dispatchCapability(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.capabilityDispatch, request);
  }
}
