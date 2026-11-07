package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.views.ViewsApi
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
class DefaultViewsApi(
    private val bridge: NativeBridge,
) : ViewsApi {

    override suspend fun openTimeline(request: OpenTimelineViewRequest): ViewOpenResponse {
        return viewOpenResponseFromJson(invokeMap(bridge, NativeCallMap.VIEW_TIMELINE_OPEN, openTimelineViewRequestToMap(request)))
    }

    override suspend fun loadOlderTimeline(request: LoadOlderTimelineViewRequest): TimelineViewPageResponse {
        return timelineViewPageResponseFromJson(invokeMap(bridge, NativeCallMap.VIEW_TIMELINE_LOAD_OLDER, loadOlderTimelineViewRequestToMap(request)))
    }

    override suspend fun loadNewerTimeline(request: LoadNewerTimelineViewRequest): TimelineViewPageResponse {
        return timelineViewPageResponseFromJson(invokeMap(bridge, NativeCallMap.VIEW_TIMELINE_LOAD_NEWER, loadNewerTimelineViewRequestToMap(request)))
    }

    override suspend fun jumpToLatestTimeline(request: TimelineViewRequest): TimelineViewPageResponse {
        return timelineViewPageResponseFromJson(invokeMap(bridge, NativeCallMap.VIEW_TIMELINE_JUMP_TO_LATEST, timelineViewRequestToMap(request)))
    }

    override suspend fun timelineSnapshot(request: TimelineViewRequest): ViewOpenResponse {
        return viewOpenResponseFromJson(invokeMap(bridge, NativeCallMap.VIEW_TIMELINE_SNAPSHOT, timelineViewRequestToMap(request)))
    }

    override suspend fun openConversationList(request: OpenConversationListViewRequest): ViewOpenResponse {
        return viewOpenResponseFromJson(invokeMap(bridge, NativeCallMap.VIEW_CONVERSATION_LIST_OPEN, openConversationListViewRequestToMap(request)))
    }

    override suspend fun close(request: CloseViewRequest): CloseViewResponse {
        return closeViewResponseFromJson(invokeMap(bridge, NativeCallMap.VIEW_CLOSE, closeViewRequestToMap(request)))
    }
}
