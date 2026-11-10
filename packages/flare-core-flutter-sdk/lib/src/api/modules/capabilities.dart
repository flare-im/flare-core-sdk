// GENERATED. Do not edit by hand.
// Module API: `capabilities` — Capability discovery and optional plugin dispatch through capability dispatch ops.
import '../../model/model.dart';

/// Capability discovery and optional plugin dispatch through capability dispatch ops.
abstract interface class CapabilitiesApi {
  /// preparePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `prepare_plugin_command`. Operation: `capability.prepare_plugin_command`.
  Future<Map<String, Object?>> preparePluginCommand(PluginCommandRequest request);
  /// pendingPluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `pending_plugin_command`. Operation: `capability.pending_plugin_command`.
  Future<Map<String, Object?>> pendingPluginCommand(PluginCommandRequest request);
  /// reconcilePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `reconcile_plugin_command`. Operation: `capability.reconcile_plugin_command`.
  Future<Map<String, Object?>> reconcilePluginCommand(PluginCommandRequest request);
  /// submitPluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `submit_plugin_command`. Operation: `capability.submit_plugin_command`.
  Future<Map<String, Object?>> submitPluginCommand(PluginCommandRequest request);
  /// acknowledgePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `acknowledge_plugin_command`. Operation: `capability.acknowledge_plugin_command`.
  Future<Map<String, Object?>> acknowledgePluginCommand(PluginCommandRequest request);
  /// invokePluginAction maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_invoke`. Operation: `capability.plugin_ui_invoke`.
  Future<Map<String, Object?>> invokePluginAction(PluginUiEvaluationRequest request);
  /// presentPluginMessage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_present`. Operation: `capability.plugin_ui_present`.
  Future<Map<String, Object?>> presentPluginMessage(PluginUiEvaluationRequest request);
  /// pluginUiAction maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_action`. Operation: `capability.plugin_ui_action`.
  Future<Map<String, Object?>> pluginUiAction(PluginUiEvaluationRequest request);
  /// resolvePluginMessage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_resolve`. Operation: `capability.plugin_ui_resolve`.
  Future<Map<String, Object?>> resolvePluginMessage(PluginUiEvaluationRequest request);
  /// pluginUiCatalog maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_catalog`. Operation: `capability.plugin_ui_catalog`.
  Future<Map<String, Object?>> pluginUiCatalog(Map<String, Object?> request);
  /// pluginComposerActions maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_composer_actions`. Operation: `capability.plugin_composer_actions`.
  Future<Map<String, Object?>> pluginComposerActions(PluginUiEvaluationRequest request);
  /// pluginDetail maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_detail`. Operation: `capability.plugin_detail`.
  Future<Map<String, Object?>> pluginDetail(PluginUiEvaluationRequest request);
  /// pluginPage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_page`. Operation: `capability.plugin_page`.
  Future<Map<String, Object?>> pluginPage(PluginUiEvaluationRequest request);
  /// pluginFileUpload maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_file_upload`. Operation: `capability.plugin_file_upload`.
  Future<Map<String, Object?>> pluginFileUpload(PluginUiEvaluationRequest request);
  /// pluginAccountEntries maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_account_entries`. Operation: `capability.plugin_account_entries`.
  Future<Map<String, Object?>> pluginAccountEntries(PluginUiEvaluationRequest request);
  /// invalidatePluginCatalog maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_catalog_invalidate`. Operation: `capability.plugin_catalog_invalidate`.
  Future<void> invalidatePluginCatalog(Map<String, Object?> request);
  /// listCapabilities maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_list`. Operation: `capability.list`.
  Future<Map<String, Object?>> listCapabilities(Map<String, Object?> request);
  /// dispatchCapability maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_dispatch`. Operation: `capability.dispatch`.
  Future<Map<String, Object?>> dispatchCapability(Map<String, Object?> request);
}
