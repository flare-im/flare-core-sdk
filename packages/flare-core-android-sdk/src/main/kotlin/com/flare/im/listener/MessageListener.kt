package com.flare.im.listener

import com.flare.im.model.catalog.*
import com.flare.im.model.command.*
import com.flare.im.model.command.message.*
import com.flare.im.model.command.message.build.*
import com.flare.im.model.common.enums.*
import com.flare.im.model.common.error.*
import com.flare.im.model.content.*
import com.flare.im.model.entity.*
import com.flare.im.model.event.*
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
/** Message listener callbacks. */
interface MessageEventListener {
    /** A single message was received. */
    fun onMessageReceived(event: MessageReceivedEvent) {}
    /** A batch of messages was received. */
    fun onMessageReceivedBatch(event: MessageReceivedBatchEvent) {}
    /** A message send operation was acknowledged. */
    fun onMessageSendAck(event: MessageSendAckEvent) {}
    /** A message send operation failed. */
    fun onMessageSendFailed(event: MessageSendFailedEvent) {}
    /** A message was recalled. */
    fun onMessageRecalled(event: MessageMutationEvent) {}
    /** A message was edited. */
    fun onMessageEdited(event: MessageMutationEvent) {}
    /** A message was deleted. */
    fun onMessageDeleted(event: MessageMutationEvent) {}
    /** A message read receipt changed. */
    fun onMessageReadReceipt(event: ReadReceiptEvent) {}
    /** A message reaction changed. */
    fun onMessageReactionChanged(event: ReactionChangedEvent) {}
    /** A conversation input or typing status changed. */
    fun onInputStatusChanged(event: TypingEvent) {}
    /** Aggregated typing status changed for a large conversation. */
    fun onTypingAggregateChanged(event: TypingAggregateEvent) {}
    /** A burn-after-read message was burned. */
    fun onMessageBurned(event: MessageMutationEvent) {}
    /** A message was pinned. */
    fun onMessagePinned(event: MessageMutationEvent) {}
    /** A message was unpinned. */
    fun onMessageUnpinned(event: MessageMutationEvent) {}
    /** Plugin card state on a local message changed: the shared layer Core publishes for the card's entity (events, sync, the caller's own result) or the viewer's local layer. Re-present that message with its messageId; version is the local layer's when that changed, the shared layer's otherwise. */
    fun onMessagePluginStateChanged(event: MessageMutationEvent) {}
}
