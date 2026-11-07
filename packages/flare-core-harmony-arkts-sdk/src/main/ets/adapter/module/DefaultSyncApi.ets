// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { SyncApi } from '../../api/modules/sync';
import { SyncConversationSummariesRequest, SyncConversationSummariesResponse } from '../../model';
import { invokeBool, invokeConversation, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError } from '../codec/NativeInvoke';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap, syncConversationSummariesRequestToMap, syncConversationSummariesResponseFromJson } from '../codec/WireCodec';

export class DefaultSyncApi implements SyncApi {
  constructor(private readonly bridge: NativeBridge) {}

  async syncConversationSummaries(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.syncConversationSummaries);
  }

  async syncConversationSummariesWithVersions(request: SyncConversationSummariesRequest): Promise<SyncConversationSummariesResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.syncConversationSummariesWithVersions, syncConversationSummariesRequestToMap(request));
    return syncConversationSummariesResponseFromJson(raw);
  }

  async syncConversation(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.syncConversation, request);
  }

  async syncMessages(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.syncMessages, request);
  }

}
