package flare_core_harmony_cangjie_sdk.listener

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Optional callback surface for apps that prefer one listener object.
public interface FlareImEventListener {
    // SDK initialization has started.
    func onInitializing(event: LifecycleEvent): Unit
    // SDK initialization completed successfully.
    func onInitialized(event: LifecycleEvent): Unit
    // SDK initialization failed.
    func onInitFailed(event: LifecycleEvent): Unit
    // SDK login completed successfully.
    func onLoginSucceeded(event: LifecycleEvent): Unit
    // SDK login failed.
    func onLoginFailed(event: LifecycleEvent): Unit
    // The current SDK session logged out.
    func onLoggedOut(event: LifecycleEvent): Unit
    // The SDK client has been disposed.
    func onDisposed(event: LifecycleEvent): Unit
    // The connection status changed (connection://status). Replace the held status whole and hand it to the Kit ConnectionNotice unchanged.
    func onConnectionStatusChanged(event: ConnectionStatus): Unit
    // The IM connection moved to another access point (access://switched).
    func onAccessSwitched(event: AccessSwitchedEvent): Unit
    // A new access manifest was accepted (access://changed).
    func onAccessChanged(event: AccessChangedEvent): Unit
    // The update center state changed (update://state). Delivered with a session; before sign-in read update.getState.
    func onUpdateState(event: UpdateStatus): Unit
    // A single message was received.
    func onMessageReceived(event: MessageReceivedEvent): Unit
    // A batch of messages was received.
    func onMessageReceivedBatch(event: MessageReceivedBatchEvent): Unit
    // A message send operation was acknowledged.
    func onMessageSendAck(event: MessageSendAckEvent): Unit
    // A message send operation failed.
    func onMessageSendFailed(event: MessageSendFailedEvent): Unit
    // A message was recalled.
    func onMessageRecalled(event: MessageMutationEvent): Unit
    // A message was edited.
    func onMessageEdited(event: MessageMutationEvent): Unit
    // A message was deleted.
    func onMessageDeleted(event: MessageMutationEvent): Unit
    // A message read receipt changed.
    func onMessageReadReceipt(event: ReadReceiptEvent): Unit
    // A message reaction changed.
    func onMessageReactionChanged(event: ReactionChangedEvent): Unit
    // A conversation input or typing status changed.
    func onInputStatusChanged(event: TypingEvent): Unit
    // Aggregated typing status changed for a large conversation.
    func onTypingAggregateChanged(event: TypingAggregateEvent): Unit
    // A burn-after-read message was burned.
    func onMessageBurned(event: MessageMutationEvent): Unit
    // A message was pinned.
    func onMessagePinned(event: MessageMutationEvent): Unit
    // A message was unpinned.
    func onMessageUnpinned(event: MessageMutationEvent): Unit
    // Plugin card state on a local message changed: the shared layer Core publishes for the card's entity (events, sync, the caller's own result) or the viewer's local layer. Re-present that message with its messageId; version is the local layer's when that changed, the shared layer's otherwise.
    func onMessagePluginStateChanged(event: MessageMutationEvent): Unit
    // A core observable view changed: the next revision, as a delta or a snapshot.
    func onViewUpdated(event: ViewUpdate): Unit
    // A new conversation was created or discovered.
    func onNewConversation(event: ConversationEvent): Unit
    // Important conversation fields changed.
    func onConversationChanged(event: ConversationEvent): Unit
    // The total unread message count changed.
    func onTotalUnreadMessageCountChanged(event: ConversationEvent): Unit
    // A conversation was deleted.
    func onConversationDeleted(event: ConversationEvent): Unit
    // Server conversation or message sync started.
    func onSyncServerStart(event: SyncEvent): Unit
    // Server conversation or message sync finished.
    func onSyncServerFinish(event: SyncEvent): Unit
    // Server conversation or message sync failed.
    func onSyncServerFailed(event: SyncEvent): Unit
    // Server sync progress changed.
    func onSyncProgress(event: ProgressEvent): Unit
    // Media upload progress changed.
    func onUploadProgress(event: ProgressEvent): Unit
    // Media download progress changed.
    func onDownloadProgress(event: ProgressEvent): Unit
    // A plugin delivered a realtime packet to this user's online connections (im.realtime.deliver): online only, at most once, never stored. Expired packets and payloads that are not JSON objects never arrive. Route by pluginId and packetType.
    func onPluginRealtime(event: PluginRealtimeEvent): Unit
    // The tenant's plugin catalog changed (a plugin enabled, disabled or reconfigured). The SDK has already invalidated its plugin catalog; read plugin entries and configuration again. Arrives a random 0-3 s after the notice, with the notices of 3 s merged into one.
    func onPluginCatalogChanged(event: PluginCatalogChangedEvent): Unit
    // Show a notification, or replace the one with the same collapseId: an in-app banner (surface inApp) while the app is in the foreground, a system notification (surface system) while it is in the background and the platform presents alerts itself. Title and body are rendered in the app's language; sound says whether to play one.
    func onNotificationPresent(event: NotificationPresentation): Unit
    // Remove the notifications with these collapse ids (their conversations were read or deleted), or every notification of the app when all is true (the session ended).
    func onNotificationClear(event: NotificationClearEvent): Unit
    // Set the app badge to count, the unread total as the conversation list counts it. Reported when the total changes, after login and when the app returns to the foreground.
    func onNotificationBadge(event: NotificationBadgeEvent): Unit
}
