package com.flare.im.adapter.module

/** GENERATED. Do not edit by hand. */

import com.flare.im.adapter.codec.*
import com.flare.im.api.sync.SyncApi
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

class DefaultSyncApi(
    private val bridge: NativeBridge,
) : SyncApi {

    override suspend fun syncConversationSummaries(): Unit {
        invokeUnit(bridge, NativeCallMap.SYNC_CONVERSATION_SUMMARIES)
    }

    override suspend fun syncConversationSummariesWithVersions(request: SyncConversationSummariesRequest): SyncConversationSummariesResponse {
        val raw = invokeMap(bridge, NativeCallMap.SYNC_CONVERSATION_SUMMARIES_WITH_VERSIONS, syncConversationSummariesRequestToMap(request))
        return syncConversationSummariesResponseFromJson(raw)
    }

    override suspend fun bootstrapStartupHome(request: StartupHomeSyncRequest): StartupHomeSyncResponse {
        val raw = invokeMap(bridge, NativeCallMap.SYNC_BOOTSTRAP_STARTUP_HOME, startupHomeSyncRequestToMap(request))
        return startupHomeSyncResponseFromJson(raw)
    }

    override suspend fun backfillConversationHistory(request: ConversationHistoryBackfillRequest): ConversationHistoryBackfillResponse {
        val raw = invokeMap(bridge, NativeCallMap.SYNC_CONVERSATION_HISTORY_BACKFILL, conversationHistoryBackfillRequestToMap(request))
        return conversationHistoryBackfillResponseFromJson(raw)
    }

    override suspend fun syncConversation(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.SYNC_CONVERSATION, request)
    }

    override suspend fun syncMessages(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.SYNC_MESSAGES, request)
    }

}
