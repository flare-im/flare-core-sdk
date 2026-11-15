// GENERATED. Do not edit by hand.
// Module API: `conversations` — Conversation query and local conversation state.
import '../../model/model.dart';

/// Conversation query and local conversation state.
abstract interface class ConversationsApi {
  /// listConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list`.
  Future<ListConversationsResponse> listConversations();
  /// listConversationsByQuery maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_by_query`.
  Future<ListConversationsResponse> listConversationsByQuery(ConversationListQuery request);
  /// listConversationsIncludingArchived maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_including_archived`.
  Future<ListConversationsResponse> listConversationsIncludingArchived();
  /// getConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get`.
  Future<Conversation> getConversation(Map<String, Object?> request);
  /// getOneConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_one`.
  Future<Conversation> getOneConversation(Map<String, Object?> request);
  /// getGroupConversationByUserIds maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_group_by_user_ids`.
  Future<Conversation> getGroupConversationByUserIds(Map<String, Object?> request);
  /// getMultipleConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_multiple`.
  Future<ListConversationsResponse> getMultipleConversations(Map<String, Object?> request);
  /// listConversationsPaginated maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_paginated`.
  Future<ListConversationsResponse> listConversationsPaginated(Map<String, Object?> request);
  /// listRawConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_raw`.
  Future<ListConversationsResponse> listRawConversations();
  /// getTotalUnread maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.total_unread`.
  Future<ConversationTotalUnreadResponse> getTotalUnread();
  /// bootstrapHomeTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.bootstrap_home`.
  Future<HomeTimelineSnapshot> bootstrapHomeTimeline(BootstrapHomeTimelineRequest request);
  /// openConversationTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.open_timeline`.
  Future<ConversationTimelineSnapshot> openConversationTimeline(OpenConversationTimelineRequest request);
  /// markConversationRead maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.mark_read`.
  Future<void> markConversationRead(Map<String, Object?> request);
  /// setConversationPinned maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_pinned`.
  Future<void> setConversationPinned(Map<String, Object?> request);
  /// setConversationMuted maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_muted`.
  Future<void> setConversationMuted(Map<String, Object?> request);
  /// setConversationNotifyAll maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_notify_all`.
  Future<void> setConversationNotifyAll(Map<String, Object?> request);
  /// setConversationArchived maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_archived`.
  Future<void> setConversationArchived(Map<String, Object?> request);
  /// markConversationUnread maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.mark_unread`.
  Future<void> markConversationUnread(Map<String, Object?> request);
  /// deleteConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.delete`.
  Future<void> deleteConversation(Map<String, Object?> request);
  /// updateConversationDraft maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.update_draft`.
  Future<void> updateConversationDraft(UpdateConversationDraftRequest request);
  /// clearLocalChatHistory maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.clear_local_chat_history`.
  Future<void> clearLocalChatHistory(Map<String, Object?> request);
  /// clearChatHistoryForSelf maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.clear_chat_history_for_self`.
  Future<void> clearChatHistoryForSelf(Map<String, Object?> request);
}
