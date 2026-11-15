// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, RuntimeHealthResponse, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

/** SDK version and FFI contract diagnostics. */
export interface DiagnosticsApi {
  getSdkVersion(): Promise<Record<string, Object>>;
  getFfiContractVersion(): Promise<Record<string, Object>>;
  getDataRoot(): Promise<Record<string, Object>>;
  getRuntimeHealth(): Promise<RuntimeHealthResponse>;
}
