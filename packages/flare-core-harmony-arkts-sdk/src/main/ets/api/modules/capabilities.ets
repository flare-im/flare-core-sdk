// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginCommandRequest, PluginRealtimeEvent, PluginUiEvaluationRequest, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

/** Capability discovery and optional plugin dispatch through capability dispatch ops. */
export interface CapabilitiesApi {
  preparePluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>>;
  pendingPluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>>;
  reconcilePluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>>;
  submitPluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>>;
  acknowledgePluginCommand(request: PluginCommandRequest): Promise<Record<string, Object>>;
  invokePluginAction(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  presentPluginMessage(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginUiAction(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  resolvePluginMessage(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginUiCatalog(request: Record<string, Object>): Promise<Record<string, Object>>;
  pluginComposerActions(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginDetail(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginPage(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginFileUpload(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginAccountEntries(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  invalidatePluginCatalog(request: Record<string, Object>): Promise<void>;
  listCapabilities(request: Record<string, Object>): Promise<Record<string, Object>>;
  dispatchCapability(request: Record<string, Object>): Promise<Record<string, Object>>;
}
