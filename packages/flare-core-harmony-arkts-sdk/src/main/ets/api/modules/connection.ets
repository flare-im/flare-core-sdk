// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NetworkChangeRequest, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, ServerClockResponse, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

/** Connection status and manual network lifecycle. */
export interface ConnectionApi {
  getStatus(): Promise<ConnectionStatus>;
  reconnectNow(): Promise<void>;
  disconnect(): Promise<void>;
  getServerClock(): Promise<ServerClockResponse>;
  notifyNetworkChange(request: NetworkChangeRequest): Promise<void>;
}
