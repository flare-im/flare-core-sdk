/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `events` — Typed SDK event stream.
 */
import type { EventCallback, EventSubscription, FlareImEventListener } from '../../listener';
import type { ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginBundleEvent, PluginCapabilityRequestEvent, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, ViewUpdate } from '../../model';
import type { SubscribeEventsRequest, Subscription, UnsubscribeRequest } from '../types';

/** Typed SDK event stream. */
export interface EventsApi {
  /** subscribeEvents maps to `flare_event_subscribe` via `ffi-symbol`. Operation: `event.subscribe`. */
  subscribeEvents(request: SubscribeEventsRequest): Promise<Subscription>;
  /** subscribeEventsBatch maps to `flare_event_subscribe_batch` via `ffi-symbol`. Operation: `event.subscribe_batch`. */
  subscribeEventsBatch(request: SubscribeEventsRequest): Promise<Subscription>;
  /** unsubscribe maps to `flare_event_unsubscribe` via `ffi-symbol`. Operation: `event.unsubscribe`. */
  unsubscribe(request: UnsubscribeRequest): Promise<void>;
  /** unsubscribeAll maps to `flare_event_unsubscribe_all` via `ffi-symbol`. Operation: `event.unsubscribe_all`. */
  unsubscribeAll(): Promise<void>;
  /** Registers a listener object for typed SDK runtime notifications. */
  addEventListener(listener: FlareImEventListener): EventSubscription;
  /** Removes one local listener registration. */
  removeEventListener(subscription: EventSubscription): void;
  /** SDK initialization has started. */
  onInitializing(listener: EventCallback<LifecycleEvent>): EventSubscription;
  /** SDK initialization completed successfully. */
  onInitialized(listener: EventCallback<LifecycleEvent>): EventSubscription;
  /** SDK initialization failed. */
  onInitFailed(listener: EventCallback<LifecycleEvent>): EventSubscription;
  /** SDK login completed successfully. */
  onLoginSucceeded(listener: EventCallback<LifecycleEvent>): EventSubscription;
  /** SDK login failed. */
  onLoginFailed(listener: EventCallback<LifecycleEvent>): EventSubscription;
  /** The current SDK session logged out. */
  onLoggedOut(listener: EventCallback<LifecycleEvent>): EventSubscription;
  /** The SDK client has been disposed. */
  onDisposed(listener: EventCallback<LifecycleEvent>): EventSubscription;
  /** The connection status changed (connection://status). Replace the held status whole and hand it to the Kit ConnectionNotice unchanged. */
  onConnectionStatusChanged(listener: EventCallback<ConnectionStatus>): EventSubscription;
  /** A single message was received. */
  onMessageReceived(listener: EventCallback<MessageReceivedEvent>): EventSubscription;
  /** A batch of messages was received. */
  onMessageReceivedBatch(listener: EventCallback<MessageReceivedBatchEvent>): EventSubscription;
  /** A message send operation was acknowledged. */
  onMessageSendAck(listener: EventCallback<MessageSendAckEvent>): EventSubscription;
  /** A message send operation failed. */
  onMessageSendFailed(listener: EventCallback<MessageSendFailedEvent>): EventSubscription;
  /** A message was recalled. */
  onMessageRecalled(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  /** A message was edited. */
  onMessageEdited(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  /** A message was deleted. */
  onMessageDeleted(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  /** A message read receipt changed. */
  onMessageReadReceipt(listener: EventCallback<ReadReceiptEvent>): EventSubscription;
  /** A message reaction changed. */
  onMessageReactionChanged(listener: EventCallback<ReactionChangedEvent>): EventSubscription;
  /** A conversation input or typing status changed. */
  onInputStatusChanged(listener: EventCallback<TypingEvent>): EventSubscription;
  /** Aggregated typing status changed for a large conversation. */
  onTypingAggregateChanged(listener: EventCallback<TypingAggregateEvent>): EventSubscription;
  /** A burn-after-read message was burned. */
  onMessageBurned(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  /** A message was pinned. */
  onMessagePinned(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  /** A message was unpinned. */
  onMessageUnpinned(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  /** Plugin card state on a local message changed: the shared layer Core publishes for the card's entity (events, sync, the caller's own result) or the viewer's local layer. Re-present that message with its messageId; version is the local layer's when that changed, the shared layer's otherwise. */
  onMessagePluginStateChanged(listener: EventCallback<MessageMutationEvent>): EventSubscription;
  /** A core observable view changed: the next revision, as a delta or a snapshot. */
  onViewUpdated(listener: EventCallback<ViewUpdate>): EventSubscription;
  /** A new conversation was created or discovered. */
  onNewConversation(listener: EventCallback<ConversationEvent>): EventSubscription;
  /** Important conversation fields changed. */
  onConversationChanged(listener: EventCallback<ConversationEvent>): EventSubscription;
  /** The total unread message count changed. */
  onTotalUnreadMessageCountChanged(listener: EventCallback<ConversationEvent>): EventSubscription;
  /** A conversation was deleted. */
  onConversationDeleted(listener: EventCallback<ConversationEvent>): EventSubscription;
  /** Server conversation or message sync started. */
  onSyncServerStart(listener: EventCallback<SyncEvent>): EventSubscription;
  /** Server conversation or message sync finished. */
  onSyncServerFinish(listener: EventCallback<SyncEvent>): EventSubscription;
  /** Server conversation or message sync failed. */
  onSyncServerFailed(listener: EventCallback<SyncEvent>): EventSubscription;
  /** Server sync progress changed. */
  onSyncProgress(listener: EventCallback<ProgressEvent>): EventSubscription;
  /** Media upload progress changed. */
  onUploadProgress(listener: EventCallback<ProgressEvent>): EventSubscription;
  /** Media download progress changed. */
  onDownloadProgress(listener: EventCallback<ProgressEvent>): EventSubscription;
  /** A plugin delivered a realtime packet to this user's online connections (im.realtime.deliver): online only, at most once, never stored. Expired packets and payloads that are not JSON objects never arrive. Route by pluginId and packetType. */
  onPluginRealtime(listener: EventCallback<PluginRealtimeEvent>): EventSubscription;
  /** The tenant's plugin catalog changed (a plugin enabled, disabled or reconfigured). The SDK has already invalidated its plugin catalog; read plugin entries and configuration again. Arrives a random 0-3 s after the notice, with the notices of 3 s merged into one. */
  onPluginCatalogChanged(listener: EventCallback<PluginCatalogChangedEvent>): EventSubscription;
  /** The engine asks the host to handle consent, captureDocument, pickFile, scanCode, confirmPayment or locateOnce. Answer with completePluginCapabilityRequest({requestId, result}) within 10 minutes. paymentSettled is a notification and does not require a response. */
  onPluginCapabilityRequest(listener: EventCallback<PluginCapabilityRequestEvent>): EventSubscription;
  /** Something for an open web bundle page: post envelope (a bridge event) to the page as it is; close the page when close is set (withdrawn, suspended, disabled, replaced, evicted or signedOut). */
  onPluginBundleEvent(listener: EventCallback<PluginBundleEvent>): EventSubscription;
  /** Show a notification, or replace the one with the same collapseId: an in-app banner (surface inApp) while the app is in the foreground, a system notification (surface system) while it is in the background and the platform presents alerts itself. Title and body are rendered in the app's language; sound says whether to play one. */
  onNotificationPresent(listener: EventCallback<NotificationPresentation>): EventSubscription;
  /** Remove the notifications with these collapse ids (their conversations were read or deleted), or every notification of the app when all is true (the session ended). */
  onNotificationClear(listener: EventCallback<NotificationClearEvent>): EventSubscription;
  /** Set the app badge to count, the unread total as the conversation list counts it. Reported when the total changes, after login and when the app returns to the foreground. */
  onNotificationBadge(listener: EventCallback<NotificationBadgeEvent>): EventSubscription;
}
