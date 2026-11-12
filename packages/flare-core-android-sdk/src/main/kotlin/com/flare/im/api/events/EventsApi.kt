package com.flare.im.api.events

import com.flare.im.callback.*
import com.flare.im.listener.*
import com.flare.im.model.catalog.*
import com.flare.im.model.command.*
import com.flare.im.model.command.message.*
import com.flare.im.model.command.message.build.*
import com.flare.im.model.common.enums.*
import com.flare.im.model.common.error.*
import com.flare.im.model.content.*
import com.flare.im.model.entity.*
import com.flare.im.model.event.*
import com.flare.im.model.event.access.*
import com.flare.im.model.event.connection.*
import com.flare.im.model.event.conversation.*
import com.flare.im.model.event.lifecycle.*
import com.flare.im.model.event.message.*
import com.flare.im.model.event.plugin.*
import com.flare.im.model.event.presence.*
import com.flare.im.model.event.progress.*
import com.flare.im.model.event.sync.*
import com.flare.im.model.media.*
import com.flare.im.model.query.*
import com.flare.im.model.response.*

/** GENERATED. Do not edit by hand. */
/** Typed SDK event stream. */
interface EventsApi {
    /** subscribeEvents maps to `flare_event_subscribe` via `ffi-symbol`. Operation: `event.subscribe`. */
    suspend fun subscribeEvents(request: Map<String, Any?>): Map<String, Any?>
    /** subscribeEventsBatch maps to `flare_event_subscribe_batch` via `ffi-symbol`. Operation: `event.subscribe_batch`. */
    suspend fun subscribeEventsBatch(request: Map<String, Any?>): Map<String, Any?>
    /** unsubscribe maps to `flare_event_unsubscribe` via `ffi-symbol`. Operation: `event.unsubscribe`. */
    suspend fun unsubscribe(request: Map<String, Any?>): Unit
    /** unsubscribeAll maps to `flare_event_unsubscribe_all` via `ffi-symbol`. Operation: `event.unsubscribe_all`. */
    suspend fun unsubscribeAll(): Unit
    fun addEventListener(listener: FlareImEventListener): EventSubscription
    fun removeEventListener(subscription: EventSubscription)
    fun onInitializing(listener: EventCallback<LifecycleEvent>): EventSubscription
    fun onInitialized(listener: EventCallback<LifecycleEvent>): EventSubscription
    fun onInitFailed(listener: EventCallback<LifecycleEvent>): EventSubscription
    fun onLoginSucceeded(listener: EventCallback<LifecycleEvent>): EventSubscription
    fun onLoginFailed(listener: EventCallback<LifecycleEvent>): EventSubscription
    fun onLoggedOut(listener: EventCallback<LifecycleEvent>): EventSubscription
    fun onDisposed(listener: EventCallback<LifecycleEvent>): EventSubscription
    fun onConnectionStatusChanged(listener: EventCallback<ConnectionStatus>): EventSubscription
    fun onAccessSwitched(listener: EventCallback<AccessSwitchedEvent>): EventSubscription
    fun onAccessChanged(listener: EventCallback<AccessChangedEvent>): EventSubscription
    fun onUpdateState(listener: EventCallback<UpdateStatus>): EventSubscription
    fun onMessageReceived(listener: EventCallback<MessageReceivedEvent>): EventSubscription
    fun onMessageReceivedBatch(listener: EventCallback<MessageReceivedBatchEvent>): EventSubscription
    fun onMessageSendAck(listener: EventCallback<MessageSendAckEvent>): EventSubscription
    fun onMessageSendFailed(listener: EventCallback<MessageSendFailedEvent>): EventSubscription
    fun onMessageRecalled(listener: EventCallback<MessageMutationEvent>): EventSubscription
    fun onMessageEdited(listener: EventCallback<MessageMutationEvent>): EventSubscription
    fun onMessageDeleted(listener: EventCallback<MessageMutationEvent>): EventSubscription
    fun onMessageReadReceipt(listener: EventCallback<ReadReceiptEvent>): EventSubscription
    fun onMessageReactionChanged(listener: EventCallback<ReactionChangedEvent>): EventSubscription
    fun onInputStatusChanged(listener: EventCallback<TypingEvent>): EventSubscription
    fun onTypingAggregateChanged(listener: EventCallback<TypingAggregateEvent>): EventSubscription
    fun onMessageBurned(listener: EventCallback<MessageMutationEvent>): EventSubscription
    fun onMessagePinned(listener: EventCallback<MessageMutationEvent>): EventSubscription
    fun onMessageUnpinned(listener: EventCallback<MessageMutationEvent>): EventSubscription
    fun onMessagePluginStateChanged(listener: EventCallback<MessageMutationEvent>): EventSubscription
    fun onViewUpdated(listener: EventCallback<ViewUpdate>): EventSubscription
    fun onNewConversation(listener: EventCallback<ConversationEvent>): EventSubscription
    fun onConversationChanged(listener: EventCallback<ConversationEvent>): EventSubscription
    fun onTotalUnreadMessageCountChanged(listener: EventCallback<ConversationEvent>): EventSubscription
    fun onConversationDeleted(listener: EventCallback<ConversationEvent>): EventSubscription
    fun onSyncServerStart(listener: EventCallback<SyncEvent>): EventSubscription
    fun onSyncServerFinish(listener: EventCallback<SyncEvent>): EventSubscription
    fun onSyncServerFailed(listener: EventCallback<SyncEvent>): EventSubscription
    fun onSyncProgress(listener: EventCallback<ProgressEvent>): EventSubscription
    fun onUploadProgress(listener: EventCallback<ProgressEvent>): EventSubscription
    fun onDownloadProgress(listener: EventCallback<ProgressEvent>): EventSubscription
    fun onPluginRealtime(listener: EventCallback<PluginRealtimeEvent>): EventSubscription
    fun onPluginCatalogChanged(listener: EventCallback<PluginCatalogChangedEvent>): EventSubscription
    fun onNotificationPresent(listener: EventCallback<NotificationPresentation>): EventSubscription
    fun onNotificationClear(listener: EventCallback<NotificationClearEvent>): EventSubscription
    fun onNotificationBadge(listener: EventCallback<NotificationBadgeEvent>): EventSubscription
}
