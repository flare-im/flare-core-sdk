// GENERATED. Do not edit by hand.
// Module API: `events` — Typed SDK event stream.
import '../../model/model.dart';
import '../../listener/listener.dart';

/// Typed SDK event stream.
abstract interface class EventsApi {
  /// subscribeEvents maps to `flare_event_subscribe` via `ffi-symbol`. Operation: `event.subscribe`.
  Future<Map<String, Object?>> subscribeEvents(Map<String, Object?> request);
  /// subscribeEventsBatch maps to `flare_event_subscribe_batch` via `ffi-symbol`. Operation: `event.subscribe_batch`.
  Future<Map<String, Object?>> subscribeEventsBatch(Map<String, Object?> request);
  /// unsubscribe maps to `flare_event_unsubscribe` via `ffi-symbol`. Operation: `event.unsubscribe`.
  Future<void> unsubscribe(Map<String, Object?> request);
  /// unsubscribeAll maps to `flare_event_unsubscribe_all` via `ffi-symbol`. Operation: `event.unsubscribe_all`.
  Future<void> unsubscribeAll();
  /// Registers a listener object for typed SDK runtime notifications.
  EventSubscription addEventListener(FlareImEventListener listener);
  /// Removes one local listener registration.
  void removeEventListener(EventSubscription subscription);
  /// SDK initialization has started.
  EventSubscription onInitializing(EventCallback<LifecycleEvent> listener);
  /// SDK initialization completed successfully.
  EventSubscription onInitialized(EventCallback<LifecycleEvent> listener);
  /// SDK initialization failed.
  EventSubscription onInitFailed(EventCallback<LifecycleEvent> listener);
  /// SDK login completed successfully.
  EventSubscription onLoginSucceeded(EventCallback<LifecycleEvent> listener);
  /// SDK login failed.
  EventSubscription onLoginFailed(EventCallback<LifecycleEvent> listener);
  /// The current SDK session logged out.
  EventSubscription onLoggedOut(EventCallback<LifecycleEvent> listener);
  /// The SDK client has been disposed.
  EventSubscription onDisposed(EventCallback<LifecycleEvent> listener);
  /// The connection status changed (connection://status). Replace the held status whole and hand it to the Kit ConnectionNotice unchanged.
  EventSubscription onConnectionStatusChanged(EventCallback<ConnectionStatus> listener);
  /// The IM connection moved to another access point (access://switched).
  EventSubscription onAccessSwitched(EventCallback<AccessSwitchedEvent> listener);
  /// A new access manifest was accepted (access://changed).
  EventSubscription onAccessChanged(EventCallback<AccessChangedEvent> listener);
  /// The update center state changed (update://state). Delivered with a session; before sign-in read update.getState.
  EventSubscription onUpdateState(EventCallback<UpdateStatus> listener);
  /// A single message was received.
  EventSubscription onMessageReceived(EventCallback<MessageReceivedEvent> listener);
  /// A batch of messages was received.
  EventSubscription onMessageReceivedBatch(EventCallback<MessageReceivedBatchEvent> listener);
  /// A message send operation was acknowledged.
  EventSubscription onMessageSendAck(EventCallback<MessageSendAckEvent> listener);
  /// A message send operation failed.
  EventSubscription onMessageSendFailed(EventCallback<MessageSendFailedEvent> listener);
  /// A message was recalled.
  EventSubscription onMessageRecalled(EventCallback<MessageMutationEvent> listener);
  /// A message was edited.
  EventSubscription onMessageEdited(EventCallback<MessageMutationEvent> listener);
  /// A message was deleted.
  EventSubscription onMessageDeleted(EventCallback<MessageMutationEvent> listener);
  /// A message read receipt changed.
  EventSubscription onMessageReadReceipt(EventCallback<ReadReceiptEvent> listener);
  /// A message reaction changed.
  EventSubscription onMessageReactionChanged(EventCallback<ReactionChangedEvent> listener);
  /// A conversation input or typing status changed.
  EventSubscription onInputStatusChanged(EventCallback<TypingEvent> listener);
  /// Aggregated typing status changed for a large conversation.
  EventSubscription onTypingAggregateChanged(EventCallback<TypingAggregateEvent> listener);
  /// A burn-after-read message was burned.
  EventSubscription onMessageBurned(EventCallback<MessageMutationEvent> listener);
  /// A message was pinned.
  EventSubscription onMessagePinned(EventCallback<MessageMutationEvent> listener);
  /// A message was unpinned.
  EventSubscription onMessageUnpinned(EventCallback<MessageMutationEvent> listener);
  /// Plugin card state on a local message changed: the shared layer Core publishes for the card's entity (events, sync, the caller's own result) or the viewer's local layer. Re-present that message with its messageId; version is the local layer's when that changed, the shared layer's otherwise.
  EventSubscription onMessagePluginStateChanged(EventCallback<MessageMutationEvent> listener);
  /// A core observable view changed: the next revision, as a delta or a snapshot.
  EventSubscription onViewUpdated(EventCallback<ViewUpdate> listener);
  /// A new conversation was created or discovered.
  EventSubscription onNewConversation(EventCallback<ConversationEvent> listener);
  /// Important conversation fields changed.
  EventSubscription onConversationChanged(EventCallback<ConversationEvent> listener);
  /// The total unread message count changed.
  EventSubscription onTotalUnreadMessageCountChanged(EventCallback<ConversationEvent> listener);
  /// A conversation was deleted.
  EventSubscription onConversationDeleted(EventCallback<ConversationEvent> listener);
  /// Server conversation or message sync started.
  EventSubscription onSyncServerStart(EventCallback<SyncEvent> listener);
  /// Server conversation or message sync finished.
  EventSubscription onSyncServerFinish(EventCallback<SyncEvent> listener);
  /// Server conversation or message sync failed.
  EventSubscription onSyncServerFailed(EventCallback<SyncEvent> listener);
  /// Server sync progress changed.
  EventSubscription onSyncProgress(EventCallback<ProgressEvent> listener);
  /// Media upload progress changed.
  EventSubscription onUploadProgress(EventCallback<ProgressEvent> listener);
  /// Media download progress changed.
  EventSubscription onDownloadProgress(EventCallback<ProgressEvent> listener);
  /// A plugin delivered a realtime packet to this user's online connections (im.realtime.deliver): online only, at most once, never stored. Expired packets and payloads that are not JSON objects never arrive. Route by pluginId and packetType.
  EventSubscription onPluginRealtime(EventCallback<PluginRealtimeEvent> listener);
  /// The tenant's plugin catalog changed (a plugin enabled, disabled or reconfigured). The SDK has already invalidated its plugin catalog; read plugin entries and configuration again. Arrives a random 0-3 s after the notice, with the notices of 3 s merged into one.
  EventSubscription onPluginCatalogChanged(EventCallback<PluginCatalogChangedEvent> listener);
  /// Show a notification, or replace the one with the same collapseId: an in-app banner (surface inApp) while the app is in the foreground, a system notification (surface system) while it is in the background and the platform presents alerts itself. Title and body are rendered in the app's language; sound says whether to play one.
  EventSubscription onNotificationPresent(EventCallback<NotificationPresentation> listener);
  /// Remove the notifications with these collapse ids (their conversations were read or deleted), or every notification of the app when all is true (the session ended).
  EventSubscription onNotificationClear(EventCallback<NotificationClearEvent> listener);
  /// Set the app badge to count, the unread total as the conversation list counts it. Reported when the total changes, after login and when the app returns to the foreground.
  EventSubscription onNotificationBadge(EventCallback<NotificationBadgeEvent> listener);
}
