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
  /// pluginCapabilityInvoke maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_capability_invoke`. Operation: `capability.plugin_capability_invoke`.
  Future<Map<String, Object?>> pluginCapabilityInvoke(PluginUiEvaluationRequest request);
  /// pluginCapabilityConsents maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_capability_consents`. Operation: `capability.plugin_capability_consents`.
  Future<Map<String, Object?>> pluginCapabilityConsents(PluginUiEvaluationRequest request);
  /// revokePluginCapabilityConsent maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_capability_consent_revoke`. Operation: `capability.plugin_capability_consent_revoke`.
  Future<Map<String, Object?>> revokePluginCapabilityConsent(PluginUiEvaluationRequest request);
  /// pluginBundleOpen maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_bundle_open`. Operation: `capability.plugin_bundle_open`.
  Future<Map<String, Object?>> pluginBundleOpen(PluginUiEvaluationRequest request);
  /// pluginBundleBridge maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_bundle_bridge`. Operation: `capability.plugin_bundle_bridge`.
  Future<Map<String, Object?>> pluginBundleBridge(PluginUiEvaluationRequest request);
  /// pluginBundleHostResult maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_bundle_host_result`. Operation: `capability.plugin_bundle_host_result`.
  Future<Map<String, Object?>> pluginBundleHostResult(PluginUiEvaluationRequest request);
  /// pluginBundleHostEvent maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_bundle_host_event`. Operation: `capability.plugin_bundle_host_event`.
  Future<Map<String, Object?>> pluginBundleHostEvent(PluginUiEvaluationRequest request);
  /// pluginBundleClose maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_bundle_close`. Operation: `capability.plugin_bundle_close`.
  Future<Map<String, Object?>> pluginBundleClose(PluginUiEvaluationRequest request);
  /// pluginBundlePrefetch maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_bundle_prefetch`. Operation: `capability.plugin_bundle_prefetch`.
  Future<Map<String, Object?>> pluginBundlePrefetch(PluginUiEvaluationRequest request);
  /// completePluginCapabilityRequest maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `plugin.capability_complete`.
  Future<void> completePluginCapabilityRequest(PluginCapabilityCompletion request);
  /// pluginAccountEntries maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_account_entries`. Operation: `capability.plugin_account_entries`.
  Future<Map<String, Object?>> pluginAccountEntries(PluginUiEvaluationRequest request);
  /// pluginScanHandlers maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_scan_handlers`. Operation: `capability.plugin_scan_handlers`.
  Future<Map<String, Object?>> pluginScanHandlers(PluginUiEvaluationRequest request);
  /// invalidatePluginCatalog maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_catalog_invalidate`. Operation: `capability.plugin_catalog_invalidate`.
  Future<void> invalidatePluginCatalog(Map<String, Object?> request);
  /// setPluginHostProfile maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `plugin.set_host_profile`.
  Future<void> setPluginHostProfile(PluginHostProfile request);
  /// listCapabilities maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_list`. Operation: `capability.list`.
  Future<Map<String, Object?>> listCapabilities(Map<String, Object?> request);
  /// dispatchCapability maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_dispatch`. Operation: `capability.dispatch`.
  Future<Map<String, Object?>> dispatchCapability(Map<String, Object?> request);
  /// pluginNativeInvoke maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_native_invoke`. Operation: `capability.plugin_native_invoke`.
  Future<Map<String, Object?>> pluginNativeInvoke(PluginUiEvaluationRequest request);
}
