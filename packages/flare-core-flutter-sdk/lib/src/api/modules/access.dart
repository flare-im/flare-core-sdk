// GENERATED. Do not edit by hand.
// Module API: `access` — Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page.
import '../../model/model.dart';

/// Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page.
abstract interface class AccessApi {
  /// getStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.get_status`.
  Future<AccessStatus> getStatus();
  /// listAccessPoints maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.list_access_points`.
  Future<List<AccessPointInfo>> listAccessPoints();
  /// pin maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.pin`.
  Future<AccessPin> pin(AccessPinRequest request);
  /// unpin maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.unpin`.
  Future<void> unpin();
  /// refresh maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.refresh`.
  Future<AccessRefreshReport> refresh();
  /// importRecovery maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.import_recovery`.
  Future<AccessRecoveryImport> importRecovery(AccessImportRecoveryRequest request);
  /// exportDiagnostics maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.export_diagnostics`.
  Future<Map<String, Object?>> exportDiagnostics();
}
