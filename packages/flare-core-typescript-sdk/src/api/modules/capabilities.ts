/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `capabilities` — Capability discovery and optional plugin dispatch through capability dispatch ops.
 */
import type { PluginCommandRequest, PluginUiEvaluationRequest } from '../../model';
import type { DispatchCapabilityRequest, DispatchCapabilityResponse, JsonObject, ListCapabilitiesRequest, ListCapabilitiesResponse } from '../types';

/** Capability discovery and optional plugin dispatch through capability dispatch ops. */
export interface CapabilitiesApi {
  /** preparePluginCommand maps to `flare_capability_dispatch_json`, dispatch op `prepare_plugin_command`. Operation: `capability.prepare_plugin_command`. */
  preparePluginCommand(request: PluginCommandRequest): Promise<JsonObject>;
  /** pendingPluginCommand maps to `flare_capability_dispatch_json`, dispatch op `pending_plugin_command`. Operation: `capability.pending_plugin_command`. */
  pendingPluginCommand(request: PluginCommandRequest): Promise<JsonObject>;
  /** reconcilePluginCommand maps to `flare_capability_dispatch_json`, dispatch op `reconcile_plugin_command`. Operation: `capability.reconcile_plugin_command`. */
  reconcilePluginCommand(request: PluginCommandRequest): Promise<JsonObject>;
  /** submitPluginCommand maps to `flare_capability_dispatch_json`, dispatch op `submit_plugin_command`. Operation: `capability.submit_plugin_command`. */
  submitPluginCommand(request: PluginCommandRequest): Promise<JsonObject>;
  /** acknowledgePluginCommand maps to `flare_capability_dispatch_json`, dispatch op `acknowledge_plugin_command`. Operation: `capability.acknowledge_plugin_command`. */
  acknowledgePluginCommand(request: PluginCommandRequest): Promise<JsonObject>;
  /** invokePluginAction maps to `flare_capability_dispatch_json`, dispatch op `plugin_ui_invoke`. Operation: `capability.plugin_ui_invoke`. */
  invokePluginAction(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** presentPluginMessage maps to `flare_capability_dispatch_json`, dispatch op `plugin_ui_present`. Operation: `capability.plugin_ui_present`. */
  presentPluginMessage(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** pluginUiAction maps to `flare_capability_dispatch_json`, dispatch op `plugin_ui_action`. Operation: `capability.plugin_ui_action`. */
  pluginUiAction(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** resolvePluginMessage maps to `flare_capability_dispatch_json`, dispatch op `plugin_ui_resolve`. Operation: `capability.plugin_ui_resolve`. */
  resolvePluginMessage(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** pluginUiCatalog maps to `flare_capability_dispatch_json`, dispatch op `plugin_ui_catalog`. Operation: `capability.plugin_ui_catalog`. */
  pluginUiCatalog(request: ListCapabilitiesRequest): Promise<JsonObject>;
  /** pluginComposerActions maps to `flare_capability_dispatch_json`, dispatch op `plugin_composer_actions`. Operation: `capability.plugin_composer_actions`. */
  pluginComposerActions(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** pluginDetail maps to `flare_capability_dispatch_json`, dispatch op `plugin_detail`. Operation: `capability.plugin_detail`. */
  pluginDetail(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** pluginPage maps to `flare_capability_dispatch_json`, dispatch op `plugin_page`. Operation: `capability.plugin_page`. */
  pluginPage(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** pluginFileUpload maps to `flare_capability_dispatch_json`, dispatch op `plugin_file_upload`. Operation: `capability.plugin_file_upload`. */
  pluginFileUpload(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** pluginAccountEntries maps to `flare_capability_dispatch_json`, dispatch op `plugin_account_entries`. Operation: `capability.plugin_account_entries`. */
  pluginAccountEntries(request: PluginUiEvaluationRequest): Promise<JsonObject>;
  /** invalidatePluginCatalog maps to `flare_capability_dispatch_json`, dispatch op `plugin_catalog_invalidate`. Operation: `capability.plugin_catalog_invalidate`. */
  invalidatePluginCatalog(request: ListCapabilitiesRequest): Promise<void>;
  /** listCapabilities maps to `flare_capability_dispatch_json`, dispatch op `capability_list`. Operation: `capability.list`. */
  listCapabilities(request: ListCapabilitiesRequest): Promise<ListCapabilitiesResponse>;
  /** dispatchCapability maps to `flare_capability_dispatch_json`, dispatch op `capability_dispatch`. Operation: `capability.dispatch`. */
  dispatchCapability(request: DispatchCapabilityRequest): Promise<DispatchCapabilityResponse>;
}
