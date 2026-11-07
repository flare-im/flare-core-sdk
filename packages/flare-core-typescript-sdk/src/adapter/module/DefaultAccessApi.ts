// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { AccessApi } from '../../api/modules/access';
import { AccessImportRecoveryRequest, AccessPin, AccessPinRequest, AccessPointInfo, AccessRecoveryImport, AccessRefreshReport, AccessStatus } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { accessImportRecoveryRequestToMap, accessPinRequestToMap, conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap } from '../codec/wireCodec';

export class DefaultAccessApi implements AccessApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getStatus(): Promise<AccessStatus> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.accessGetStatus)) as unknown as AccessStatus;
  }

  async listAccessPoints(): Promise<AccessPointInfo[]> {
    return await invokeList(this.bridge, NativeCallMap.accessListAccessPoints) as unknown as AccessPointInfo[];
  }

  async pin(request: AccessPinRequest): Promise<AccessPin> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.accessPin, accessPinRequestToMap(request))) as unknown as AccessPin;
  }

  async unpin(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.accessUnpin);
  }

  async refresh(): Promise<AccessRefreshReport> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.accessRefresh)) as unknown as AccessRefreshReport;
  }

  async importRecovery(request: AccessImportRecoveryRequest): Promise<AccessRecoveryImport> {
    return withoutNullFields(await invokeMap(this.bridge, NativeCallMap.accessImportRecovery, accessImportRecoveryRequestToMap(request))) as unknown as AccessRecoveryImport;
  }

  async exportDiagnostics(): Promise<unknown> {
    return await this.bridge.invoke<unknown>(NativeCallMap.accessExportDiagnostics);
  }
}
