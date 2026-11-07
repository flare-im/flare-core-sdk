package com.flare.im.adapter.module

/** GENERATED. Do not edit by hand. */

import com.flare.im.adapter.codec.*
import com.flare.im.api.messages.MessagesApi
import com.flare.im.callback.*
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallMap
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
import com.flare.im.model.event.connection.*
import com.flare.im.model.event.conversation.*
import com.flare.im.model.event.lifecycle.*
import com.flare.im.model.event.message.*
import com.flare.im.model.event.presence.*
import com.flare.im.model.event.progress.*
import com.flare.im.model.event.sync.*
import com.flare.im.model.media.*
import com.flare.im.model.query.*
import com.flare.im.model.response.*

class DefaultMessagesApi(
    private val bridge: NativeBridge,
) : MessagesApi {

    override suspend fun createTextMessage(request: CreateTextMessageRequest): Message {
        return invokeMessage(bridge, NativeCallMap.MESSAGE_CREATE_TEXT, createTextMessageRequestToMap(request))
    }

    override suspend fun dispatchMessage(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MESSAGE_DISPATCH, request)
    }

    override suspend fun sendMessageNoOss(request: SendMessageRequest): SendMessageResponse {
        return invokeSendAck(bridge, NativeCallMap.MESSAGE_SEND_NO_OSS, sendMessageRequestToMap(request))
    }

    override suspend fun sendMessage(request: SendMessageRequest, callback: MessageSendCallback?): SendMessageResponse {
        val wireRequest = sendMessageRequestToMap(request)
        try {
            val ack = invokeSendAck(bridge, NativeCallMap.MESSAGE_SEND, wireRequest)
            callback?.onSuccess(MessageSendAckEvent(ack = ack))
            return ack
        } catch (error: Throwable) {
            val payload = sdkErrorPayloadFromThrowable(error, "message.send")
            callback?.onFailure(
                MessageSendFailedEvent(
                    clientMsgId = request.message.clientMsgId,
                    reason = payload.message,
                    error = payload,
                ),
            )
            throw error
        }
    }

    override suspend fun listMessages(request: ListMessagesRequest): ListMessagesResponse {
        return invokeListMessages(bridge, NativeCallMap.MESSAGE_LIST, listMessagesRequestToMap(request))
    }

    override suspend fun recallMessage(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_RECALL, request)
    }

    override suspend fun editTextByMessageId(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_EDIT_TEXT_BY_MESSAGE_ID, request)
    }

    override suspend fun deleteMessage(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_DELETE, request)
    }

    override suspend fun deleteMessageForSelf(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_DELETE_FOR_SELF, request)
    }

    override suspend fun deleteMessageForEveryone(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_DELETE_FOR_EVERYONE, request)
    }


    override suspend fun markMessageReadAndBurn(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_MARK_READ_AND_BURN, request)
    }

    override suspend fun addReaction(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_ADD_REACTION, request)
    }

    override suspend fun removeReaction(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_REMOVE_REACTION, request)
    }

    override suspend fun pinMessage(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_PIN, request)
    }

    override suspend fun unpinMessage(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_UNPIN, request)
    }

    override suspend fun pinMessageById(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_PIN_BY_MESSAGE_ID, request)
    }

    override suspend fun unpinMessageById(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_UNPIN_BY_MESSAGE_ID, request)
    }

    override suspend fun markMessage(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_MARK, request)
    }

    override suspend fun markMessageWithColor(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_MARK_WITH_COLOR, request)
    }

    override suspend fun unmarkMessage(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_UNMARK, request)
    }

    override suspend fun markMessageById(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_MARK_BY_MESSAGE_ID, request)
    }

    override suspend fun unmarkMessageById(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_UNMARK_BY_MESSAGE_ID, request)
    }

    override suspend fun getMessage(request: Map<String, Any?>): Message {
        return invokeMessage(bridge, NativeCallMap.MESSAGE_GET, request)
    }

    override suspend fun getRawMessage(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MESSAGE_GET_RAW, request)
    }

    override suspend fun searchMessages(request: MessageSearchQuery): ListMessagesResponse {
        return invokeListMessages(bridge, NativeCallMap.MESSAGE_SEARCH, messageSearchQueryToMap(request))
    }

    override suspend fun searchMessagesByQuery(request: MessageSearchQuery): ListMessagesResponse {
        return invokeListMessages(bridge, NativeCallMap.MESSAGE_SEARCH_BY_QUERY, messageSearchQueryToMap(request))
    }

    override suspend fun searchMessagesInConversation(request: MessageSearchQuery): ListMessagesResponse {
        return invokeListMessages(bridge, NativeCallMap.MESSAGE_SEARCH_IN_CONVERSATION, messageSearchQueryToMap(request))
    }

    override suspend fun readReceiptMembers(request: MessageReadReceiptMembersRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MESSAGE_READ_RECEIPT_MEMBERS, messageReadReceiptMembersRequestToMap(request))
    }

    override suspend fun editRichDocByMessageId(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_EDIT_RICH_DOC_BY_MESSAGE_ID, request)
    }

    override suspend fun setTyping(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MESSAGE_TYPING, request)
    }
}
