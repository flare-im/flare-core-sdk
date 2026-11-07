package com.flare.im.api.conversations

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
/** Conversation query and local conversation state. */
interface ConversationsApi {
    /** listConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list`. */
    suspend fun listConversations(): ListConversationsResponse
    /** listConversationsByQuery maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_by_query`. */
    suspend fun listConversationsByQuery(request: ConversationListQuery): ListConversationsResponse
    /** listConversationsIncludingArchived maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_including_archived`. */
    suspend fun listConversationsIncludingArchived(): ListConversationsResponse
    /** getConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get`. */
    suspend fun getConversation(request: Map<String, Any?>): Conversation
    /** getOneConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_one`. */
    suspend fun getOneConversation(request: Map<String, Any?>): Conversation
    /** getGroupConversationByUserIds maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_group_by_user_ids`. */
    suspend fun getGroupConversationByUserIds(request: Map<String, Any?>): Conversation
    /** getMultipleConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_multiple`. */
    suspend fun getMultipleConversations(request: Map<String, Any?>): ListConversationsResponse
    /** listConversationsPaginated maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_paginated`. */
    suspend fun listConversationsPaginated(request: Map<String, Any?>): ListConversationsResponse
    /** listRawConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_raw`. */
    suspend fun listRawConversations(): ListConversationsResponse
    /** getTotalUnread maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.total_unread`. */
    suspend fun getTotalUnread(): ConversationTotalUnreadResponse
    /** bootstrapHomeTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.bootstrap_home`. */
    suspend fun bootstrapHomeTimeline(request: BootstrapHomeTimelineRequest): HomeTimelineSnapshot
    /** openConversationTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.open_timeline`. */
    suspend fun openConversationTimeline(request: OpenConversationTimelineRequest): ConversationTimelineSnapshot
    /** markConversationRead maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.mark_read`. */
    suspend fun markConversationRead(request: Map<String, Any?>): Unit
    /** setConversationPinned maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_pinned`. */
    suspend fun setConversationPinned(request: Map<String, Any?>): Unit
    /** setConversationMuted maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_muted`. */
    suspend fun setConversationMuted(request: Map<String, Any?>): Unit
    /** setConversationArchived maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_archived`. */
    suspend fun setConversationArchived(request: Map<String, Any?>): Unit
    /** markConversationUnread maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.mark_unread`. */
    suspend fun markConversationUnread(request: Map<String, Any?>): Unit
    /** deleteConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.delete`. */
    suspend fun deleteConversation(request: Map<String, Any?>): Unit
    /** updateConversationDraft maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.update_draft`. */
    suspend fun updateConversationDraft(request: UpdateConversationDraftRequest): Unit
    /** clearLocalChatHistory maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.clear_local_chat_history`. */
    suspend fun clearLocalChatHistory(request: Map<String, Any?>): Unit
    /** clearChatHistoryForSelf maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.clear_chat_history_for_self`. */
    suspend fun clearChatHistoryForSelf(request: Map<String, Any?>): Unit
}
