// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, BackgroundRefreshRequest, BackgroundRefreshResult, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NotificationBadgeEvent, NotificationClearEvent, NotificationPresentation, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SetBackgroundPresenterRequest, SetNotificationFocusRequest, SetNotificationSnapshotDirectoryRequest, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, UpdateUserNotificationSettingsRequest, UserNotificationSettings, ViewUpdate } from '../../model';

/** Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events. */
export interface NotificationApi {
  setFocus(request: SetNotificationFocusRequest): Promise<void>;
  getSettings(): Promise<UserNotificationSettings>;
  updateSettings(request: UpdateUserNotificationSettingsRequest): Promise<UserNotificationSettings>;
  setBackgroundPresenter(request: SetBackgroundPresenterRequest): Promise<void>;
  setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Promise<void>;
  backgroundRefresh(request: BackgroundRefreshRequest): Promise<BackgroundRefreshResult>;
}
