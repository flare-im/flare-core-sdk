// GENERATED. Do not edit by hand.
import { ConnectionStatus, ConversationEvent, CoreEndpoints, EndpointUpdate, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NetworkChangeRequest, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginBundleEvent, PluginCapabilityRequestEvent, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, ServerClockResponse, SetProtocolModeRequest, SyncEvent, TypingAggregateEvent, TypingEvent, ViewUpdate } from '../../model';

/** Connection status and manual network lifecycle. */
export interface ConnectionApi {
  getStatus(): Promise<ConnectionStatus>;
  reconnectNow(): Promise<void>;
  replaceEndpoints(request: CoreEndpoints): Promise<EndpointUpdate>;
  setProtocolMode(request: SetProtocolModeRequest): Promise<void>;
  disconnect(): Promise<void>;
  getServerClock(): Promise<ServerClockResponse>;
  notifyNetworkChange(request: NetworkChangeRequest): Promise<void>;
}
