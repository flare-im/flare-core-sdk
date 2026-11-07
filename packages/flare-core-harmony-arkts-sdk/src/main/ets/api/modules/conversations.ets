// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, BootstrapHomeTimelineRequest, ConnectionStatus, Conversation, ConversationEvent, ConversationListQuery, ConversationTimelineSnapshot, ConversationTotalUnreadResponse, HomeTimelineSnapshot, LifecycleEvent, ListConversationsResponse, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, OpenConversationTimelineRequest, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateConversationDraftRequest, UpdateStatus, ViewUpdate } from '../../model';

/** Conversation query and local conversation state. */
export interface ConversationsApi {
  listConversations(): Promise<ListConversationsResponse>;
  listConversationsByQuery(request: ConversationListQuery): Promise<ListConversationsResponse>;
  listConversationsIncludingArchived(): Promise<ListConversationsResponse>;
  getConversation(request: Record<string, Object>): Promise<Conversation>;
  getOneConversation(request: Record<string, Object>): Promise<Conversation>;
  getGroupConversationByUserIds(request: Record<string, Object>): Promise<Conversation>;
  getMultipleConversations(request: Record<string, Object>): Promise<ListConversationsResponse>;
  listConversationsPaginated(request: Record<string, Object>): Promise<ListConversationsResponse>;
  listRawConversations(): Promise<ListConversationsResponse>;
  getTotalUnread(): Promise<ConversationTotalUnreadResponse>;
  bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): Promise<HomeTimelineSnapshot>;
  openConversationTimeline(request: OpenConversationTimelineRequest): Promise<ConversationTimelineSnapshot>;
  markConversationRead(request: Record<string, Object>): Promise<void>;
  setConversationPinned(request: Record<string, Object>): Promise<void>;
  setConversationMuted(request: Record<string, Object>): Promise<void>;
  setConversationArchived(request: Record<string, Object>): Promise<void>;
  markConversationUnread(request: Record<string, Object>): Promise<void>;
  deleteConversation(request: Record<string, Object>): Promise<void>;
  updateConversationDraft(request: UpdateConversationDraftRequest): Promise<void>;
  clearLocalChatHistory(request: Record<string, Object>): Promise<void>;
  clearChatHistoryForSelf(request: Record<string, Object>): Promise<void>;
}
