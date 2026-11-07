package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultViewsApi <: ViewsApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func openTimeline(request: OpenTimelineViewRequest): ViewOpenResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.viewTimelineOpen, requestJson: wireEncodeRequest(openTimelineViewRequestToJson(request)))
        return viewOpenResponseFromJson(raw)
    }

    public func loadOlderTimeline(request: LoadOlderTimelineViewRequest): TimelineViewPageResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.viewTimelineLoadOlder, requestJson: wireEncodeRequest(loadOlderTimelineViewRequestToJson(request)))
        return timelineViewPageResponseFromJson(raw)
    }

    public func loadNewerTimeline(request: LoadNewerTimelineViewRequest): TimelineViewPageResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.viewTimelineLoadNewer, requestJson: wireEncodeRequest(loadNewerTimelineViewRequestToJson(request)))
        return timelineViewPageResponseFromJson(raw)
    }

    public func jumpToLatestTimeline(request: TimelineViewRequest): TimelineViewPageResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.viewTimelineJumpToLatest, requestJson: wireEncodeRequest(timelineViewRequestToJson(request)))
        return timelineViewPageResponseFromJson(raw)
    }

    public func timelineSnapshot(request: TimelineViewRequest): ViewOpenResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.viewTimelineSnapshot, requestJson: wireEncodeRequest(timelineViewRequestToJson(request)))
        return viewOpenResponseFromJson(raw)
    }

    public func openConversationList(request: OpenConversationListViewRequest): ViewOpenResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.viewConversationListOpen, requestJson: wireEncodeRequest(openConversationListViewRequestToJson(request)))
        return viewOpenResponseFromJson(raw)
    }

    public func close(request: CloseViewRequest): CloseViewResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.viewClose, requestJson: wireEncodeRequest(closeViewRequestToJson(request)))
        return closeViewResponseFromJson(raw)
    }
}
