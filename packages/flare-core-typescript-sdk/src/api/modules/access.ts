/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `access` — Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page.
 */
import type { AccessImportRecoveryRequest, AccessPin, AccessPinRequest, AccessPointInfo, AccessRecoveryImport, AccessRefreshReport, AccessStatus } from '../../model';

/** Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page. */
export interface AccessApi {
  /** getStatus maps to `flare_sdk_invoke_json`. Operation: `access.get_status`. */
  getStatus(): Promise<AccessStatus>;
  /** listAccessPoints maps to `flare_sdk_invoke_json`. Operation: `access.list_access_points`. */
  listAccessPoints(): Promise<AccessPointInfo[]>;
  /** pin maps to `flare_sdk_invoke_json`. Operation: `access.pin`. */
  pin(request: AccessPinRequest): Promise<AccessPin>;
  /** unpin maps to `flare_sdk_invoke_json`. Operation: `access.unpin`. */
  unpin(): Promise<void>;
  /** refresh maps to `flare_sdk_invoke_json`. Operation: `access.refresh`. */
  refresh(): Promise<AccessRefreshReport>;
  /** importRecovery maps to `flare_sdk_invoke_json`. Operation: `access.import_recovery`. */
  importRecovery(request: AccessImportRecoveryRequest): Promise<AccessRecoveryImport>;
  /** exportDiagnostics maps to `flare_sdk_invoke_json`. Operation: `access.export_diagnostics`. */
  exportDiagnostics(): Promise<unknown>;
}
