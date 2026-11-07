// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessImportRecoveryRequest, AccessPin, AccessPinRequest, AccessPointInfo, AccessRecoveryImport, AccessRefreshReport, AccessStatus, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

/** Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page. */
export interface AccessApi {
  getStatus(): Promise<AccessStatus>;
  listAccessPoints(): Promise<Array<AccessPointInfo>>;
  pin(request: AccessPinRequest): Promise<AccessPin>;
  unpin(): Promise<void>;
  refresh(): Promise<AccessRefreshReport>;
  importRecovery(request: AccessImportRecoveryRequest): Promise<AccessRecoveryImport>;
  exportDiagnostics(): Promise<Record<string, Object>>;
}
