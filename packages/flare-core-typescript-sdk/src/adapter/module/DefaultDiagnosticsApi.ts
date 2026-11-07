// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { DiagnosticsApi } from '../../api/modules/diagnostics';
import { RuntimeHealthResponse } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap } from '../codec/wireCodec';

export class DefaultDiagnosticsApi implements DiagnosticsApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getSdkVersion(): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.diagnosticsSdkVersion);
  }

  async getFfiContractVersion(): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.diagnosticsFfiContractVersion);
  }

  async getDataRoot(): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.diagnosticsDataRoot);
  }

  async getRuntimeHealth(): Promise<RuntimeHealthResponse> {
    return await invokeMap(this.bridge, NativeCallMap.diagnosticsRuntimeHealth) as unknown as RuntimeHealthResponse;
  }
}
