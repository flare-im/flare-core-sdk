// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { AccessApi } from '../../api/modules/access';
import type { AccessImportRecoveryRequest, AccessPin, AccessPinRequest, AccessPointInfo, AccessRecoveryImport, AccessRefreshReport, AccessStatus } from '../../model';
import { invokeMap, invokeVoid } from '../codec/NativeInvoke';
import { accessImportRecoveryRequestToMap, accessPinFromJson, accessPinRequestToMap, accessPointInfoListFromJson, accessRecoveryImportFromJson, accessRefreshReportFromJson, accessStatusFromJson } from '../codec/WireCodec';

export class DefaultAccessApi implements AccessApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getStatus(): Promise<AccessStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.accessGetStatus);
    return accessStatusFromJson(raw);
  }

  async listAccessPoints(): Promise<Array<AccessPointInfo>> {
    const raw = await this.bridge.invoke<Object>(NativeCallMap.accessListAccessPoints);
    return accessPointInfoListFromJson(raw);
  }

  async pin(request: AccessPinRequest): Promise<AccessPin> {
    const raw = await invokeMap(this.bridge, NativeCallMap.accessPin, accessPinRequestToMap(request));
    return accessPinFromJson(raw);
  }

  async unpin(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.accessUnpin);
  }

  async refresh(): Promise<AccessRefreshReport> {
    const raw = await invokeMap(this.bridge, NativeCallMap.accessRefresh);
    return accessRefreshReportFromJson(raw);
  }

  async importRecovery(request: AccessImportRecoveryRequest): Promise<AccessRecoveryImport> {
    const raw = await invokeMap(this.bridge, NativeCallMap.accessImportRecovery, accessImportRecoveryRequestToMap(request));
    return accessRecoveryImportFromJson(raw);
  }

  async exportDiagnostics(): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.accessExportDiagnostics);
  }
}
