// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { ConversationsApi } from '../../api/modules/conversations';
import { BootstrapHomeTimelineRequest, Conversation, ConversationListQuery, ConversationTimelineSnapshot, ConversationTotalUnreadResponse, HomeTimelineSnapshot, ListConversationsResponse, OpenConversationTimelineRequest } from '../../model';
import { invokeBool, invokeConversation, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError } from '../codec/NativeInvoke';
import { bootstrapHomeTimelineRequestToMap, conversationFromJson, conversationListQueryToMap, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, openConversationTimelineRequestToMap, sendAckFromJson, sendMessageRequestToMap, updateConversationDraftRequestToMap } from '../codec/WireCodec';

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

  async getConversation(request: Record<string, Object>): Promise<Conversation> {
    return await invokeConversation(this.bridge, NativeCallMap.conversationGet, request);
  }

  async getOneConversation(request: Record<string, Object>): Promise<Conversation> {
    return await invokeConversation(this.bridge, NativeCallMap.conversationGetOne, request);
  }

  async getGroupConversationByUserIds(request: Record<string, Object>): Promise<Conversation> {
    return await invokeConversation(this.bridge, NativeCallMap.conversationGetGroupByUserIds, request);
  }

  async getMultipleConversations(request: Record<string, Object>): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationGetMultiple, request);
  }

  async listConversationsPaginated(request: Record<string, Object>): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationListPaginated, request);
  }

  async listRawConversations(): Promise<ListConversationsResponse> {
    return await invokeListConversations(this.bridge, NativeCallMap.conversationListRaw);
  }

  async getTotalUnread(): Promise<ConversationTotalUnreadResponse> {
    return await this.bridge.invoke<ConversationTotalUnreadResponse>(NativeCallMap.conversationTotalUnread);
  }

  async bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): Promise<HomeTimelineSnapshot> {
    return await this.bridge.invoke<HomeTimelineSnapshot>(NativeCallMap.conversationBootstrapHome, bootstrapHomeTimelineRequestToMap(request));
  }

  async openConversationTimeline(request: OpenConversationTimelineRequest): Promise<ConversationTimelineSnapshot> {
    return await this.bridge.invoke<ConversationTimelineSnapshot>(NativeCallMap.conversationOpenTimeline, openConversationTimelineRequestToMap(request));
  }

  async markConversationRead(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationMarkRead, request);
  }

  async setConversationPinned(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationSetPinned, request);
  }

  async setConversationMuted(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationSetMuted, request);
  }

  async setConversationArchived(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationSetArchived, request);
  }

  async markConversationUnread(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.conversationMarkUnread, request);
  }

  async deleteConversation(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationDelete, request);
  }

  async updateConversationDraft(request: UpdateConversationDraftRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationUpdateDraft, updateConversationDraftRequestToMap(request));
  }

  async clearLocalChatHistory(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationClearLocalChatHistory, request);
  }

  async clearChatHistoryForSelf(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.conversationClearChatHistoryForSelf, request);
  }
}
