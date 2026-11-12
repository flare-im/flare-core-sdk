// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

/** Presence and input state. */
export interface PresenceApi {
  getUserPresence(request: Record<string, Object>): Promise<Record<string, Object>>;
  batchGetUserPresence(request: Record<string, Object>): Promise<Record<string, Object>>;
  subscribeUserPresence(request: Record<string, Object>): Promise<void>;
}
