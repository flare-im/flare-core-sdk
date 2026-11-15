/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `conversations` — Conversation query and local conversation state.
 */
import type { BootstrapHomeTimelineRequest, Conversation, ConversationListQuery, ConversationTimelineSnapshot, ConversationTotalUnreadResponse, HomeTimelineSnapshot, ListConversationsResponse, OpenConversationTimelineRequest, UpdateConversationDraftRequest } from '../../model';
import type { ClearLocalChatHistoryRequest, DeleteConversationRequest, GetConversationRequest, GetGroupConversationByUserIdsRequest, GetMultipleConversationsRequest, GetOneConversationRequest, ListConversationsPaginatedRequest, MarkConversationReadRequest, MarkConversationUnreadRequest, SetConversationArchivedRequest, SetConversationMutedRequest, SetConversationNotifyAllRequest, SetConversationPinnedRequest } from '../types';

/** Conversation query and local conversation state. */
export interface ConversationsApi {
  /** listConversations maps to `flare_sdk_invoke_json`. Operation: `conversation.list`. */
  listConversations(): Promise<ListConversationsResponse>;
  /** listConversationsByQuery maps to `flare_sdk_invoke_json`. Operation: `conversation.list_by_query`. */
  listConversationsByQuery(request: ConversationListQuery): Promise<ListConversationsResponse>;
  /** listConversationsIncludingArchived maps to `flare_sdk_invoke_json`. Operation: `conversation.list_including_archived`. */
  listConversationsIncludingArchived(): Promise<ListConversationsResponse>;
  /** getConversation maps to `flare_sdk_invoke_json`. Operation: `conversation.get`. */
  getConversation(request: GetConversationRequest): Promise<Conversation>;
  /** getOneConversation maps to `flare_sdk_invoke_json`. Operation: `conversation.get_one`. */
  getOneConversation(request: GetOneConversationRequest): Promise<Conversation>;
  /** getGroupConversationByUserIds maps to `flare_sdk_invoke_json`. Operation: `conversation.get_group_by_user_ids`. */
  getGroupConversationByUserIds(request: GetGroupConversationByUserIdsRequest): Promise<Conversation>;
  /** getMultipleConversations maps to `flare_sdk_invoke_json`. Operation: `conversation.get_multiple`. */
  getMultipleConversations(request: GetMultipleConversationsRequest): Promise<ListConversationsResponse>;
  /** listConversationsPaginated maps to `flare_sdk_invoke_json`. Operation: `conversation.list_paginated`. */
  listConversationsPaginated(request: ListConversationsPaginatedRequest): Promise<ListConversationsResponse>;
  /** listRawConversations maps to `flare_sdk_invoke_json`. Operation: `conversation.list_raw`. */
  listRawConversations(): Promise<ListConversationsResponse>;
  /** getTotalUnread maps to `flare_sdk_invoke_json`. Operation: `conversation.total_unread`. */
  getTotalUnread(): Promise<ConversationTotalUnreadResponse>;
  /** bootstrapHomeTimeline maps to `flare_sdk_invoke_json`. Operation: `conversation.bootstrap_home`. */
  bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): Promise<HomeTimelineSnapshot>;
  /** openConversationTimeline maps to `flare_sdk_invoke_json`. Operation: `conversation.open_timeline`. */
  openConversationTimeline(request: OpenConversationTimelineRequest): Promise<ConversationTimelineSnapshot>;
  /** markConversationRead maps to `flare_sdk_invoke_json`. Operation: `conversation.mark_read`. */
  markConversationRead(request: MarkConversationReadRequest): Promise<void>;
  /** setConversationPinned maps to `flare_sdk_invoke_json`. Operation: `conversation.set_pinned`. */
  setConversationPinned(request: SetConversationPinnedRequest): Promise<void>;
  /** setConversationMuted maps to `flare_sdk_invoke_json`. Operation: `conversation.set_muted`. */
  setConversationMuted(request: SetConversationMutedRequest): Promise<void>;
  /** setConversationNotifyAll maps to `flare_sdk_invoke_json`. Operation: `conversation.set_notify_all`. */
  setConversationNotifyAll(request: SetConversationNotifyAllRequest): Promise<void>;
  /** setConversationArchived maps to `flare_sdk_invoke_json`. Operation: `conversation.set_archived`. */
  setConversationArchived(request: SetConversationArchivedRequest): Promise<void>;
  /** markConversationUnread maps to `flare_sdk_invoke_json`. Operation: `conversation.mark_unread`. */
  markConversationUnread(request: MarkConversationUnreadRequest): Promise<void>;
  /** deleteConversation maps to `flare_sdk_invoke_json`. Operation: `conversation.delete`. */
  deleteConversation(request: DeleteConversationRequest): Promise<void>;
  /** updateConversationDraft maps to `flare_sdk_invoke_json`. Operation: `conversation.update_draft`. */
  updateConversationDraft(request: UpdateConversationDraftRequest): Promise<void>;
  /** clearLocalChatHistory maps to `flare_sdk_invoke_json`. Operation: `conversation.clear_local_chat_history`. */
  clearLocalChatHistory(request: ClearLocalChatHistoryRequest): Promise<void>;
  /** clearChatHistoryForSelf maps to `flare_sdk_invoke_json`. Operation: `conversation.clear_chat_history_for_self`. */
  clearChatHistoryForSelf(request: ClearLocalChatHistoryRequest): Promise<void>;
}
