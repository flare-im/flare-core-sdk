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
/** Conversation listener callbacks. */
interface ConversationEventListener {
    /** A new conversation was created or discovered. */
    fun onNewConversation(event: ConversationEvent) {}
    /** Important conversation fields changed. */
    fun onConversationChanged(event: ConversationEvent) {}
    /** The total unread message count changed. */
    fun onTotalUnreadMessageCountChanged(event: ConversationEvent) {}
    /** A conversation was deleted. */
    fun onConversationDeleted(event: ConversationEvent) {}
}
