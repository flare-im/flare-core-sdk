// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { DiagnosticsApi } from '../../api/modules/diagnostics';
import type { RuntimeHealthResponse } from '../../model';
import { invokeMap } from '../codec/NativeInvoke';
import { runtimeHealthResponseFromJson } from '../codec/WireCodec';

export class DefaultDiagnosticsApi implements DiagnosticsApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getSdkVersion(): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.diagnosticsSdkVersion);
  }

  async getFfiContractVersion(): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.diagnosticsFfiContractVersion);
  }

  async getDataRoot(): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.diagnosticsDataRoot);
  }

  async getRuntimeHealth(): Promise<RuntimeHealthResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.diagnosticsRuntimeHealth);
    return runtimeHealthResponseFromJson(raw);
  }
}
