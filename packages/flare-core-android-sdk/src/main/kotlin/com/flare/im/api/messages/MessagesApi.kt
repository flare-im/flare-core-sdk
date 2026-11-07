package com.flare.im.api.messages

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
/** Message build, send, query and mutation. */
interface MessagesApi {
    /** createTextMessage maps to `flare_message_create_text` via `ffi-symbol`. Operation: `message.create_text`. */
    suspend fun createTextMessage(request: CreateTextMessageRequest): Message
    /** dispatchMessage maps to `flare_message_dispatch_json` via `dispatch-json`. Operation: `message.dispatch`. */
    suspend fun dispatchMessage(request: Map<String, Any?>): Map<String, Any?>
    /** sendMessageNoOss maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `send_no_oss`. Operation: `message.send_no_oss`. */
    suspend fun sendMessageNoOss(request: SendMessageRequest): SendMessageResponse
    /** sendMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `send`. Operation: `message.send`. */
    suspend fun sendMessage(request: SendMessageRequest, callback: MessageSendCallback? = null): SendMessageResponse
    /** listMessages maps to `flare_message_list` via `ffi-symbol`. Operation: `message.list`. */
    suspend fun listMessages(request: ListMessagesRequest): ListMessagesResponse
    /** recallMessage maps to `flare_message_recall` via `ffi-symbol`. Operation: `message.recall`. */
    suspend fun recallMessage(request: Map<String, Any?>): Unit
    /** editTextByMessageId maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `edit_text_by_message_id`. Operation: `message.edit_text_by_message_id`. */
    suspend fun editTextByMessageId(request: Map<String, Any?>): Unit
    /** deleteMessage maps to `flare_message_delete` via `ffi-symbol`. Operation: `message.delete`. */
    suspend fun deleteMessage(request: Map<String, Any?>): Unit
    /** deleteMessageForSelf maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `delete_for_self`. Operation: `message.delete_for_self`. */
    suspend fun deleteMessageForSelf(request: Map<String, Any?>): Unit
    /** deleteMessageForEveryone maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `delete_for_everyone`. Operation: `message.delete_for_everyone`. */
    suspend fun deleteMessageForEveryone(request: Map<String, Any?>): Unit
    /** markMessageReadAndBurn maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_read_and_burn`. Operation: `message.mark_read_and_burn`. */
    suspend fun markMessageReadAndBurn(request: Map<String, Any?>): Unit
    /** addReaction maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `add_reaction`. Operation: `message.add_reaction`. */
    suspend fun addReaction(request: Map<String, Any?>): Unit
    /** removeReaction maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `remove_reaction`. Operation: `message.remove_reaction`. */
    suspend fun removeReaction(request: Map<String, Any?>): Unit
    /** pinMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `pin`. Operation: `message.pin`. */
    suspend fun pinMessage(request: Map<String, Any?>): Unit
    /** unpinMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unpin`. Operation: `message.unpin`. */
    suspend fun unpinMessage(request: Map<String, Any?>): Unit
    /** pinMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `pin_by_message_id`. Operation: `message.pin_by_message_id`. */
    suspend fun pinMessageById(request: Map<String, Any?>): Unit
    /** unpinMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unpin_by_message_id`. Operation: `message.unpin_by_message_id`. */
    suspend fun unpinMessageById(request: Map<String, Any?>): Unit
    /** markMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark`. Operation: `message.mark`. */
    suspend fun markMessage(request: Map<String, Any?>): Unit
    /** markMessageWithColor maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_with_color`. Operation: `message.mark_with_color`. */
    suspend fun markMessageWithColor(request: Map<String, Any?>): Unit
    /** unmarkMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unmark`. Operation: `message.unmark`. */
    suspend fun unmarkMessage(request: Map<String, Any?>): Unit
    /** markMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_by_message_id`. Operation: `message.mark_by_message_id`. */
    suspend fun markMessageById(request: Map<String, Any?>): Unit
    /** unmarkMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unmark_by_message_id`. Operation: `message.unmark_by_message_id`. */
    suspend fun unmarkMessageById(request: Map<String, Any?>): Unit
    /** getMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `get`. Operation: `message.get`. */
    suspend fun getMessage(request: Map<String, Any?>): Message
    /** getRawMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `get_raw`. Operation: `message.get_raw`. */
    suspend fun getRawMessage(request: Map<String, Any?>): Map<String, Any?>
    /** searchMessages maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search`. Operation: `message.search`. */
    suspend fun searchMessages(request: MessageSearchQuery): ListMessagesResponse
    /** searchMessagesByQuery maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search_by_query`. Operation: `message.search_by_query`. */
    suspend fun searchMessagesByQuery(request: MessageSearchQuery): ListMessagesResponse
    /** searchMessagesInConversation maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search_in_conversation`. Operation: `message.search_in_conversation`. */
    suspend fun searchMessagesInConversation(request: MessageSearchQuery): ListMessagesResponse
    /** readReceiptMembers maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `read_receipt_members`. Operation: `message.read_receipt_members`. */
    suspend fun readReceiptMembers(request: MessageReadReceiptMembersRequest): Map<String, Any?>
    /** editRichDocByMessageId maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `edit_rich_doc_by_message_id`. Operation: `message.edit_rich_doc_by_message_id`. */
    suspend fun editRichDocByMessageId(request: Map<String, Any?>): Unit
    /** setTyping maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `typing`. Operation: `message.typing`. */
    suspend fun setTyping(request: Map<String, Any?>): Unit
}
