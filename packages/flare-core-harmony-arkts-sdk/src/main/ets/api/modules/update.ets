// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateCheckRequest, UpdateDownloadRequest, UpdateGetResourcesRequest, UpdateGetStateRequest, UpdateInstallPlan, UpdateMarkPromptedRequest, UpdateReportInstallRequest, UpdateResources, UpdateSetLocaleRequest, UpdateSkipRequest, UpdateStatus, ViewUpdate } from '../../model';

/** Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors. */
export interface UpdateApi {
  getState(request: UpdateGetStateRequest): Promise<UpdateStatus>;
  check(request: UpdateCheckRequest): Promise<UpdateStatus>;
  download(request: UpdateDownloadRequest): Promise<UpdateStatus>;
  install(): Promise<UpdateInstallPlan>;
  reportInstall(request: UpdateReportInstallRequest): Promise<UpdateStatus>;
  defer(): Promise<UpdateStatus>;
  skip(request: UpdateSkipRequest): Promise<UpdateStatus>;
  markPrompted(request: UpdateMarkPromptedRequest): Promise<UpdateStatus>;
  setLocale(request: UpdateSetLocaleRequest): Promise<UpdateStatus>;
  getResources(request: UpdateGetResourcesRequest): Promise<UpdateResources>;
}
