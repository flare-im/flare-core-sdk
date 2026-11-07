package com.flare.im.api.views

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
/** Core observable message/conversation views. */
interface ViewsApi {
    /** openTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.open`. */
    suspend fun openTimeline(request: OpenTimelineViewRequest): ViewOpenResponse
    /** loadOlderTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.load_older`. */
    suspend fun loadOlderTimeline(request: LoadOlderTimelineViewRequest): TimelineViewPageResponse
    /** loadNewerTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.load_newer`. */
    suspend fun loadNewerTimeline(request: LoadNewerTimelineViewRequest): TimelineViewPageResponse
    /** jumpToLatestTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.jump_to_latest`. */
    suspend fun jumpToLatestTimeline(request: TimelineViewRequest): TimelineViewPageResponse
    /** timelineSnapshot maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.snapshot`. */
    suspend fun timelineSnapshot(request: TimelineViewRequest): ViewOpenResponse
    /** openConversationList maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.conversation_list.open`. */
    suspend fun openConversationList(request: OpenConversationListViewRequest): ViewOpenResponse
    /** close maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.close`. */
    suspend fun close(request: CloseViewRequest): CloseViewResponse
}
