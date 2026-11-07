// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { SyncApi } from '../../api/modules/sync';
import { ConversationHistoryBackfillRequest, ConversationHistoryBackfillResponse, StartupHomeSyncRequest, StartupHomeSyncResponse, SyncConversationSummariesRequest, SyncConversationSummariesResponse } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, conversationHistoryBackfillRequestToMap, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap, startupHomeSyncRequestToMap, syncConversationSummariesRequestToMap, syncConversationSummariesResponseFromJson } from '../codec/wireCodec';

export class DefaultSyncApi implements SyncApi {
  constructor(private readonly bridge: NativeBridge) {}

  async syncConversationSummaries(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.syncConversationSummaries);
  }

  async syncConversationSummariesWithVersions(request: SyncConversationSummariesRequest): Promise<SyncConversationSummariesResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.syncConversationSummariesWithVersions, syncConversationSummariesRequestToMap(request));
    return syncConversationSummariesResponseFromJson(raw);
  }

  async bootstrapStartupHome(request: StartupHomeSyncRequest): Promise<StartupHomeSyncResponse> {
    return await invokeMap(this.bridge, NativeCallMap.syncBootstrapStartupHome, startupHomeSyncRequestToMap(request)) as unknown as StartupHomeSyncResponse;
  }

  async backfillConversationHistory(request: ConversationHistoryBackfillRequest): Promise<ConversationHistoryBackfillResponse> {
    return await invokeMap(this.bridge, NativeCallMap.syncConversationHistoryBackfill, conversationHistoryBackfillRequestToMap(request)) as unknown as ConversationHistoryBackfillResponse;
  }

  async syncConversation(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.syncConversation, request);
  }

  async syncMessages(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.syncMessages, request);
  }
}
