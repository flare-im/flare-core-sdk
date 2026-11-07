package com.flare.im.api.sync

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
/** Explicit sync operations. */
interface SyncApi {
    /** syncConversationSummaries maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.conversation_summaries`. */
    suspend fun syncConversationSummaries(): Unit
    /** syncConversationSummariesWithVersions maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.conversation_summaries_with_versions`. */
    suspend fun syncConversationSummariesWithVersions(request: SyncConversationSummariesRequest): SyncConversationSummariesResponse
    /** bootstrapStartupHome maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.bootstrap_startup_home`. */
    suspend fun bootstrapStartupHome(request: StartupHomeSyncRequest): StartupHomeSyncResponse
    /** backfillConversationHistory maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.conversation_history_backfill`. */
    suspend fun backfillConversationHistory(request: ConversationHistoryBackfillRequest): ConversationHistoryBackfillResponse
    /** syncConversation maps to `flare_sdk_sync_conversation` via `ffi-symbol`. Operation: `sync.conversation`. */
    suspend fun syncConversation(request: Map<String, Any?>): Unit
    /** syncMessages maps to `flare_sdk_sync_messages` via `ffi-symbol`. Operation: `sync.messages`. */
    suspend fun syncMessages(request: Map<String, Any?>): Unit
}
