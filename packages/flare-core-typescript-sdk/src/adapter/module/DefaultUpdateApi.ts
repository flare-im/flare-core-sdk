// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { UpdateApi } from '../../api/modules/update';
import { UpdateCheckRequest, UpdateDownloadRequest, UpdateGetResourcesRequest, UpdateGetStateRequest, UpdateInstallPlan, UpdateMarkPromptedRequest, UpdateReportInstallRequest, UpdateResources, UpdateSetLocaleRequest, UpdateSkipRequest, UpdateStatus } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap, updateCheckRequestToMap, updateDownloadRequestToMap, updateGetResourcesRequestToMap, updateGetStateRequestToMap, updateMarkPromptedRequestToMap, updateReportInstallRequestToMap, updateSetLocaleRequestToMap, updateSkipRequestToMap } from '../codec/wireCodec';

export class DefaultUpdateApi implements UpdateApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getState(request: UpdateGetStateRequest): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateGetState, updateGetStateRequestToMap(request))) as unknown as UpdateStatus;
  }

  async check(request: UpdateCheckRequest): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateCheck, updateCheckRequestToMap(request))) as unknown as UpdateStatus;
  }

  async download(request: UpdateDownloadRequest): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateDownload, updateDownloadRequestToMap(request))) as unknown as UpdateStatus;
  }

  async install(): Promise<UpdateInstallPlan> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateInstall)) as unknown as UpdateInstallPlan;
  }

  async reportInstall(request: UpdateReportInstallRequest): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateReportInstall, updateReportInstallRequestToMap(request))) as unknown as UpdateStatus;
  }

  async defer(): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateDefer)) as unknown as UpdateStatus;
  }

  async skip(request: UpdateSkipRequest): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateSkip, updateSkipRequestToMap(request))) as unknown as UpdateStatus;
  }

  async markPrompted(request: UpdateMarkPromptedRequest): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateMarkPrompted, updateMarkPromptedRequestToMap(request))) as unknown as UpdateStatus;
  }

  async setLocale(request: UpdateSetLocaleRequest): Promise<UpdateStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.updateSetLocale, updateSetLocaleRequestToMap(request))) as unknown as UpdateStatus;
  }

  async getResources(request: UpdateGetResourcesRequest): Promise<UpdateResources> {
    return await invokeMap(this.bridge, NativeCallMap.updateGetResources, updateGetResourcesRequestToMap(request)) as unknown as UpdateResources;
  }
}
