// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';
import { EventCallback, EventSubscription, FlareImEventListener, MessageSendCallback } from '../../listener';

/** Typed SDK event stream. */
export interface EventsApi {
  subscribeEvents(request: Record<string, Object>): Promise<Record<string, Object>>;
  subscribeEventsBatch(request: Record<string, Object>): Promise<Record<string, Object>>;
  unsubscribe(request: Record<string, Object>): Promise<void>;
  unsubscribeAll(): Promise<void>;
  addEventListener(listener: FlareImEventListener): EventSubscription;
  removeEventListener(subscription: EventSubscription): void;
  onInitializing(listener: EventCallback<LifecycleEvent>): EventSubscription;
  onInitialized(listener: EventCallback<LifecycleEvent>): EventSubscription;
  onInitFailed(listener: EventCallback<LifecycleEvent>): EventSubscription;
  onLoginSucceeded(listener: EventCallback<LifecycleEvent>): EventSubscription;
  onLoginFailed(listener: EventCallback<LifecycleEvent>): EventSubscription;
  onLoggedOut(listener: EventCallback<LifecycleEvent>): EventSubscription;
  onDisposed(listener: EventCallback<LifecycleEvent>): EventSubscription;
  onConnectionStatusChanged(listener: EventCallback<ConnectionStatus>): EventSubscription;
  onAccessSwitched(listener: EventCallback<AccessSwitchedEvent>): EventSubscription;
  onAccessChanged(listener: EventCallback<AccessChangedEvent>): EventSubscription;
  onUpdateState(listener: EventCallback<UpdateStatus>): EventSubscription;
  onMessageReceived(listener: EventCallback<MessageReceivedEvent>): EventSubscription;
  onMessageReceivedBatch(listener: EventCallback<MessageReceivedBatchEvent>): EventSubscription;
  onMessageSendAck(listener: EventCallback<MessageSendAckEvent>): EventSubscription;
  onMessageSendFailed(listener: EventCallback<MessageSendFailedEvent>): EventSubscription;
  onMessageRecalled(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  onMessageEdited(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  onMessageDeleted(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  onMessageReadReceipt(listener: EventCallback<ReadReceiptEvent>): EventSubscription;
  onMessageReactionChanged(listener: EventCallback<ReactionChangedEvent>): EventSubscription;
  onInputStatusChanged(listener: EventCallback<TypingEvent>): EventSubscription;
  onTypingAggregateChanged(listener: EventCallback<TypingAggregateEvent>): EventSubscription;
  onMessageBurned(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  onMessagePinned(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  onMessageUnpinned(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  onMessagePluginStateChanged(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  onViewUpdated(listener: EventCallback<ViewUpdate>): EventSubscription;
  onNewConversation(listener: EventCallback<ConversationEvent>): EventSubscription;
  onConversationChanged(listener: EventCallback<ConversationEvent>): EventSubscription;
  onTotalUnreadMessageCountChanged(listener: EventCallback<ConversationEvent>): EventSubscription;
  onConversationDeleted(listener: EventCallback<ConversationEvent>): EventSubscription;
  onSyncServerStart(listener: EventCallback<SyncEvent>): EventSubscription;
  onSyncServerFinish(listener: EventCallback<SyncEvent>): EventSubscription;
  onSyncServerFailed(listener: EventCallback<SyncEvent>): EventSubscription;
  onSyncProgress(listener: EventCallback<ProgressEvent>): EventSubscription;
  onUploadProgress(listener: EventCallback<ProgressEvent>): EventSubscription;
  onDownloadProgress(listener: EventCallback<ProgressEvent>): EventSubscription;
  onPluginRealtime(listener: EventCallback<PluginRealtimeEvent>): EventSubscription;
  onPluginCatalogChanged(listener: EventCallback<PluginCatalogChangedEvent>): EventSubscription;
  onNotificationPresent(listener: EventCallback<NotificationPresentation>): EventSubscription;
  onNotificationClear(listener: EventCallback<NotificationClearEvent>): EventSubscription;
  onNotificationBadge(listener: EventCallback<NotificationBadgeEvent>): EventSubscription;
}
