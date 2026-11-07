// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { ConversationsApi } from '../../api/modules/conversations';
import { BootstrapHomeTimelineRequest, Conversation, ConversationListQuery, ConversationTimelineSnapshot, ConversationTotalUnreadResponse, HomeTimelineSnapshot, ListConversationsResponse, OpenConversationTimelineRequest, UpdateConversationDraftRequest } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { bootstrapHomeTimelineRequestToMap, conversationFromJson, conversationListQueryToMap, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, openConversationTimelineRequestToMap, sendAckFromJson, sendMessageRequestToMap, updateConversationDraftRequestToMap } from '../codec/wireCodec';

export class DefaultConversationsApi implements ConversationsApi {
  constructor(private readonly bridge: NativeBridge) {}

  async listConversations(): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationList);
  }

  async listConversationsByQuery(request: ConversationListQuery): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationListByQuery, conversationListQueryToMap(request));
  }

  async listConversationsIncludingArchived(): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationListIncludingArchived);
  }

  async getConversation(request: Record<string, unknown>): Promise<Conversation> {
    return await invokeConversation(this.bridge, NativeCallMap.conversationGet, request);
  }

  async getOneConversation(request: Record<string, unknown>): Promise<Conversation> {
    return await invokeConversation(this.bridge, NativeCallMap.conversationGetOne, request);
  }

  async getGroupConversationByUserIds(request: Record<string, unknown>): Promise<Conversation> {
    return await invokeConversation(this.bridge, NativeCallMap.conversationGetGroupByUserIds, request);
  }

  async getMultipleConversations(request: Record<string, unknown>): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationGetMultiple, request);
  }

  async listConversationsPaginated(request: Record<string, unknown>): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationListPaginated, request);
  }

  async listRawConversations(): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationListRaw);
  }

  async getTotalUnread(): Promise<ConversationTotalUnreadResponse> {
    return await invokeMap(this.bridge, NativeCallMap.conversationTotalUnread) as unknown as ConversationTotalUnreadResponse;
  }

  async bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): Promise<HomeTimelineSnapshot> {
    return await invokeHomeTimelineSnapshot(this.bridge, NativeCallMap.conversationBootstrapHome, bootstrapHomeTimelineRequestToMap(request));
  }

  async openConversationTimeline(request: OpenConversationTimelineRequest): Promise<ConversationTimelineSnapshot> {
    return await invokeConversationTimelineSnapshot(this.bridge, NativeCallMap.conversationOpenTimeline, openConversationTimelineRequestToMap(request));
  }

  async markConversationRead(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationMarkRead, request);
  }

  async setConversationPinned(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationSetPinned, request);
  }

  async setConversationMuted(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationSetMuted, request);
  }

  async setConversationArchived(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationSetArchived, request);
  }

  async markConversationUnread(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationMarkUnread, request);
  }

  async deleteConversation(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationDelete, request);
  }

  async updateConversationDraft(request: UpdateConversationDraftRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationUpdateDraft, updateConversationDraftRequestToMap(request));
  }

  async clearLocalChatHistory(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationClearLocalChatHistory, request);
  }

  async clearChatHistoryForSelf(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationClearChatHistoryForSelf, request);
  }
}
