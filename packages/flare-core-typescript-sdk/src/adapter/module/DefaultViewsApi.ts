// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { ViewsApi } from '../../api/modules/views';
import { CloseViewRequest, CloseViewResponse, LoadNewerTimelineViewRequest, LoadOlderTimelineViewRequest, OpenConversationListViewRequest, OpenTimelineViewRequest, TimelineViewPageResponse, TimelineViewRequest, ViewOpenResponse } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { closeViewRequestToMap, closeViewResponseFromJson, conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, loadNewerTimelineViewRequestToMap, loadOlderTimelineViewRequestToMap, messageFromJson, openConversationListViewRequestToMap, openTimelineViewRequestToMap, sendAckFromJson, sendMessageRequestToMap, timelineViewPageResponseFromJson, timelineViewRequestToMap, viewOpenResponseFromJson } from '../codec/wireCodec';

export class DefaultViewsApi implements ViewsApi {
  constructor(private readonly bridge: NativeBridge) {}

  async openTimeline(request: OpenTimelineViewRequest): Promise<ViewOpenResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.viewTimelineOpen, openTimelineViewRequestToMap(request));
    return viewOpenResponseFromJson(raw);
  }

  async loadOlderTimeline(request: LoadOlderTimelineViewRequest): Promise<TimelineViewPageResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.viewTimelineLoadOlder, loadOlderTimelineViewRequestToMap(request));
    return timelineViewPageResponseFromJson(raw);
  }

  async loadNewerTimeline(request: LoadNewerTimelineViewRequest): Promise<TimelineViewPageResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.viewTimelineLoadNewer, loadNewerTimelineViewRequestToMap(request));
    return timelineViewPageResponseFromJson(raw);
  }

  async jumpToLatestTimeline(request: TimelineViewRequest): Promise<TimelineViewPageResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.viewTimelineJumpToLatest, timelineViewRequestToMap(request));
    return timelineViewPageResponseFromJson(raw);
  }

  async timelineSnapshot(request: TimelineViewRequest): Promise<ViewOpenResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.viewTimelineSnapshot, timelineViewRequestToMap(request));
    return viewOpenResponseFromJson(raw);
  }

  async openConversationList(request: OpenConversationListViewRequest): Promise<ViewOpenResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.viewConversationListOpen, openConversationListViewRequestToMap(request));
    return viewOpenResponseFromJson(raw);
  }

  async close(request: CloseViewRequest): Promise<CloseViewResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.viewClose, closeViewRequestToMap(request));
    return closeViewResponseFromJson(raw);
  }
}
