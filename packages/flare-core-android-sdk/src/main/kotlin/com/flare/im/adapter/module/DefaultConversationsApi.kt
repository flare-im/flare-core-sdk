package com.flare.im.adapter.module

/** GENERATED. Do not edit by hand. */

import com.flare.im.adapter.codec.*
import com.flare.im.api.conversations.ConversationsApi
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

class DefaultConversationsApi(
    private val bridge: NativeBridge,
) : ConversationsApi {

    override suspend fun listConversations(): ListConversationsResponse {
        return invokeListConversations(bridge, NativeCallMap.CONVERSATION_LIST)
    }

    override suspend fun listConversationsByQuery(request: ConversationListQuery): ListConversationsResponse {
        return invokeListConversations(bridge, NativeCallMap.CONVERSATION_LIST_BY_QUERY, conversationListQueryToMap(request))
    }

    override suspend fun listConversationsIncludingArchived(): ListConversationsResponse {
        return invokeListConversations(bridge, NativeCallMap.CONVERSATION_LIST_INCLUDING_ARCHIVED)
    }

    override suspend fun getConversation(request: Map<String, Any?>): Conversation {
        return invokeConversation(bridge, NativeCallMap.CONVERSATION_GET, request)
    }

    override suspend fun getOneConversation(request: Map<String, Any?>): Conversation {
        return invokeConversation(bridge, NativeCallMap.CONVERSATION_GET_ONE, request)
    }

    override suspend fun getGroupConversationByUserIds(request: Map<String, Any?>): Conversation {
        return invokeConversation(bridge, NativeCallMap.CONVERSATION_GET_GROUP_BY_USER_IDS, request)
    }

    override suspend fun getMultipleConversations(request: Map<String, Any?>): ListConversationsResponse {
        return invokeListConversations(bridge, NativeCallMap.CONVERSATION_GET_MULTIPLE, request)
    }

    override suspend fun listConversationsPaginated(request: Map<String, Any?>): ListConversationsResponse {
        return invokeListConversations(bridge, NativeCallMap.CONVERSATION_LIST_PAGINATED, request)
    }

    override suspend fun listRawConversations(): ListConversationsResponse {
        return invokeListConversations(bridge, NativeCallMap.CONVERSATION_LIST_RAW)
    }

    override suspend fun getTotalUnread(): ConversationTotalUnreadResponse {
        val raw = invokeMap(bridge, NativeCallMap.CONVERSATION_TOTAL_UNREAD)
        return ConversationTotalUnreadResponse(totalUnread = intValue(raw["totalUnread"]))
    }

    override suspend fun bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): HomeTimelineSnapshot {
        return homeTimelineSnapshotFromJson(invokeMap(bridge, NativeCallMap.CONVERSATION_BOOTSTRAP_HOME, bootstrapHomeTimelineRequestToMap(request)))
    }

    override suspend fun openConversationTimeline(request: OpenConversationTimelineRequest): ConversationTimelineSnapshot {
        return conversationTimelineSnapshotFromJson(invokeMap(bridge, NativeCallMap.CONVERSATION_OPEN_TIMELINE, openConversationTimelineRequestToMap(request)))
    }

    override suspend fun markConversationRead(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_MARK_READ, request)
    }

    override suspend fun setConversationPinned(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_SET_PINNED, request)
    }

    override suspend fun setConversationMuted(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_SET_MUTED, request)
    }

    override suspend fun setConversationArchived(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_SET_ARCHIVED, request)
    }

    override suspend fun markConversationUnread(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_MARK_UNREAD, request)
    }

    override suspend fun deleteConversation(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_DELETE, request)
    }

    override suspend fun updateConversationDraft(request: UpdateConversationDraftRequest): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_UPDATE_DRAFT, updateConversationDraftRequestToMap(request))
    }

    override suspend fun clearLocalChatHistory(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_CLEAR_LOCAL_CHAT_HISTORY, request)
    }

    override suspend fun clearChatHistoryForSelf(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CONVERSATION_CLEAR_CHAT_HISTORY_FOR_SELF, request)
    }
}
