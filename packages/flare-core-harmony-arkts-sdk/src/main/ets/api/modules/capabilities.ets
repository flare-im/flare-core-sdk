// GENERATED. Do not edit by hand.
import { ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginBundleEvent, PluginCapabilityCompletion, PluginCapabilityRequestEvent, PluginCatalogChangedEvent, PluginCommandRequest, PluginHostProfile, PluginRealtimeEvent, PluginUiEvaluationRequest, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

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
  pluginCapabilityInvoke(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginCapabilityConsents(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  revokePluginCapabilityConsent(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginBundleOpen(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginBundleBridge(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginBundleHostResult(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginBundleHostEvent(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginBundleClose(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginBundlePrefetch(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  completePluginCapabilityRequest(request: PluginCapabilityCompletion): Promise<void>;
  pluginAccountEntries(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  pluginScanHandlers(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
  invalidatePluginCatalog(request: Record<string, Object>): Promise<void>;
  setPluginHostProfile(request: PluginHostProfile): Promise<void>;
  listCapabilities(request: Record<string, Object>): Promise<Record<string, Object>>;
  dispatchCapability(request: Record<string, Object>): Promise<Record<string, Object>>;
  pluginNativeInvoke(request: PluginUiEvaluationRequest): Promise<Record<string, Object>>;
}
