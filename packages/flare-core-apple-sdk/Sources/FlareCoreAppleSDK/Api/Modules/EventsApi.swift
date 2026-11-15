import Foundation

/// GENERATED. Do not edit by hand.
/// Typed SDK event stream.
public protocol EventsApiProtocol: AnyObject {
    func subscribeEvents(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func subscribeEventsBatch(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func unsubscribe(_ request: [String: AnySendable]) async throws -> Void
    func unsubscribeAll() async throws -> Void
    func addEventListener(_ listener: any FlareImEventListener) -> any EventSubscription
    func removeEventListener(_ subscription: any EventSubscription)
    func onInitializing(_ listener: @escaping EventCallback<LifecycleEvent>) -> any EventSubscription
    func onInitialized(_ listener: @escaping EventCallback<LifecycleEvent>) -> any EventSubscription
    func onInitFailed(_ listener: @escaping EventCallback<LifecycleEvent>) -> any EventSubscription
    func onLoginSucceeded(_ listener: @escaping EventCallback<LifecycleEvent>) -> any EventSubscription
    func onLoginFailed(_ listener: @escaping EventCallback<LifecycleEvent>) -> any EventSubscription
    func onLoggedOut(_ listener: @escaping EventCallback<LifecycleEvent>) -> any EventSubscription
    func onDisposed(_ listener: @escaping EventCallback<LifecycleEvent>) -> any EventSubscription
    func onConnectionStatusChanged(_ listener: @escaping EventCallback<ConnectionStatus>) -> any EventSubscription
    func onAccessSwitched(_ listener: @escaping EventCallback<AccessSwitchedEvent>) -> any EventSubscription
    func onAccessChanged(_ listener: @escaping EventCallback<AccessChangedEvent>) -> any EventSubscription
    func onUpdateState(_ listener: @escaping EventCallback<UpdateStatus>) -> any EventSubscription
    func onMessageReceived(_ listener: @escaping EventCallback<MessageReceivedEvent>) -> any EventSubscription
    func onMessageReceivedBatch(_ listener: @escaping EventCallback<MessageReceivedBatchEvent>) -> any EventSubscription
    func onMessageSendAck(_ listener: @escaping EventCallback<MessageSendAckEvent>) -> any EventSubscription
    func onMessageSendFailed(_ listener: @escaping EventCallback<MessageSendFailedEvent>) -> any EventSubscription
    func onMessageRecalled(_ listener: @escaping EventCallback<MessageMutationEvent>) -> any EventSubscription
    func onMessageEdited(_ listener: @escaping EventCallback<MessageMutationEvent>) -> any EventSubscription
    func onMessageDeleted(_ listener: @escaping EventCallback<MessageMutationEvent>) -> any EventSubscription
    func onMessageReadReceipt(_ listener: @escaping EventCallback<ReadReceiptEvent>) -> any EventSubscription
    func onMessageReactionChanged(_ listener: @escaping EventCallback<ReactionChangedEvent>) -> any EventSubscription
    func onInputStatusChanged(_ listener: @escaping EventCallback<TypingEvent>) -> any EventSubscription
    func onTypingAggregateChanged(_ listener: @escaping EventCallback<TypingAggregateEvent>) -> any EventSubscription
    func onMessageBurned(_ listener: @escaping EventCallback<MessageMutationEvent>) -> any EventSubscription
    func onMessagePinned(_ listener: @escaping EventCallback<MessageMutationEvent>) -> any EventSubscription
    func onMessageUnpinned(_ listener: @escaping EventCallback<MessageMutationEvent>) -> any EventSubscription
    func onMessagePluginStateChanged(_ listener: @escaping EventCallback<MessageMutationEvent>) -> any EventSubscription
    func onViewUpdated(_ listener: @escaping EventCallback<ViewUpdate>) -> any EventSubscription
    func onNewConversation(_ listener: @escaping EventCallback<ConversationEvent>) -> any EventSubscription
    func onConversationChanged(_ listener: @escaping EventCallback<ConversationEvent>) -> any EventSubscription
    func onTotalUnreadMessageCountChanged(_ listener: @escaping EventCallback<ConversationEvent>) -> any EventSubscription
    func onConversationDeleted(_ listener: @escaping EventCallback<ConversationEvent>) -> any EventSubscription
    func onSyncServerStart(_ listener: @escaping EventCallback<SyncEvent>) -> any EventSubscription
    func onSyncServerFinish(_ listener: @escaping EventCallback<SyncEvent>) -> any EventSubscription
    func onSyncServerFailed(_ listener: @escaping EventCallback<SyncEvent>) -> any EventSubscription
    func onSyncProgress(_ listener: @escaping EventCallback<ProgressEvent>) -> any EventSubscription
    func onUploadProgress(_ listener: @escaping EventCallback<ProgressEvent>) -> any EventSubscription
    func onDownloadProgress(_ listener: @escaping EventCallback<ProgressEvent>) -> any EventSubscription
    func onPluginRealtime(_ listener: @escaping EventCallback<PluginRealtimeEvent>) -> any EventSubscription
    func onPluginCatalogChanged(_ listener: @escaping EventCallback<PluginCatalogChangedEvent>) -> any EventSubscription
    func onNotificationPresent(_ listener: @escaping EventCallback<NotificationPresentation>) -> any EventSubscription
    func onNotificationClear(_ listener: @escaping EventCallback<NotificationClearEvent>) -> any EventSubscription
    func onNotificationBadge(_ listener: @escaping EventCallback<NotificationBadgeEvent>) -> any EventSubscription
}
