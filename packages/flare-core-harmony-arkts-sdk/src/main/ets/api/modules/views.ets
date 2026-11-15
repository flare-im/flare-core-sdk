// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, CloseViewRequest, CloseViewResponse, ConnectionStatus, ConversationEvent, LifecycleEvent, LoadNewerTimelineViewRequest, LoadOlderTimelineViewRequest, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, OpenConversationListViewRequest, OpenTimelineViewRequest, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TimelineViewPageResponse, TimelineViewRequest, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewOpenResponse, ViewUpdate } from '../../model';

/** Core observable message/conversation views. */
export interface ViewsApi {
  openTimeline(request: OpenTimelineViewRequest): Promise<ViewOpenResponse>;
  loadOlderTimeline(request: LoadOlderTimelineViewRequest): Promise<TimelineViewPageResponse>;
  loadNewerTimeline(request: LoadNewerTimelineViewRequest): Promise<TimelineViewPageResponse>;
  jumpToLatestTimeline(request: TimelineViewRequest): Promise<TimelineViewPageResponse>;
  timelineSnapshot(request: TimelineViewRequest): Promise<ViewOpenResponse>;
  openConversationList(request: OpenConversationListViewRequest): Promise<ViewOpenResponse>;
  close(request: CloseViewRequest): Promise<CloseViewResponse>;
}
