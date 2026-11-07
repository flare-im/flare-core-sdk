// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { UpdateApi } from '../../api/modules/update';
import type { UpdateCheckRequest, UpdateDownloadRequest, UpdateGetResourcesRequest, UpdateGetStateRequest, UpdateInstallPlan, UpdateMarkPromptedRequest, UpdateReportInstallRequest, UpdateResources, UpdateSetLocaleRequest, UpdateSkipRequest, UpdateStatus } from '../../model';
import { invokeMap } from '../codec/NativeInvoke';
import { updateCheckRequestToMap, updateDownloadRequestToMap, updateGetResourcesRequestToMap, updateGetStateRequestToMap, updateInstallPlanFromJson, updateMarkPromptedRequestToMap, updateReportInstallRequestToMap, updateResourcesFromJson, updateSetLocaleRequestToMap, updateSkipRequestToMap, updateStatusFromJson } from '../codec/WireCodec';

export class DefaultUpdateApi implements UpdateApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getState(request: UpdateGetStateRequest): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateGetState, updateGetStateRequestToMap(request));
    return updateStatusFromJson(raw);
  }

  async check(request: UpdateCheckRequest): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateCheck, updateCheckRequestToMap(request));
    return updateStatusFromJson(raw);
  }

  async download(request: UpdateDownloadRequest): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateDownload, updateDownloadRequestToMap(request));
    return updateStatusFromJson(raw);
  }

  async install(): Promise<UpdateInstallPlan> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateInstall);
    return updateInstallPlanFromJson(raw);
  }

  async reportInstall(request: UpdateReportInstallRequest): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateReportInstall, updateReportInstallRequestToMap(request));
    return updateStatusFromJson(raw);
  }

  async defer(): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateDefer);
    return updateStatusFromJson(raw);
  }

  async skip(request: UpdateSkipRequest): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateSkip, updateSkipRequestToMap(request));
    return updateStatusFromJson(raw);
  }

  async markPrompted(request: UpdateMarkPromptedRequest): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateMarkPrompted, updateMarkPromptedRequestToMap(request));
    return updateStatusFromJson(raw);
  }

  async setLocale(request: UpdateSetLocaleRequest): Promise<UpdateStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateSetLocale, updateSetLocaleRequestToMap(request));
    return updateStatusFromJson(raw);
  }

  async getResources(request: UpdateGetResourcesRequest): Promise<UpdateResources> {
    const raw = await invokeMap(this.bridge, NativeCallMap.updateGetResources, updateGetResourcesRequestToMap(request));
    return updateResourcesFromJson(raw);
  }
}
