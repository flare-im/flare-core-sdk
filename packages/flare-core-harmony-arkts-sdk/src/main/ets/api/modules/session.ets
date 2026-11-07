// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ClearPushTokenRequest, ConnectionStatus, ConversationEvent, HeartbeatEffectiveIntervalResponse, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, PushLifecycleStatus, PushTokenInput, ReactionChangedEvent, ReadReceiptEvent, SetHeartbeatNatTimeoutRequest, SetPushPermissionRequest, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';
import { ConnectTokenRefresher } from '../../contract/BridgeContract';

/** SDK lifecycle, authenticated session and process-level utilities. */
export interface SessionApi {
  create(request: Record<string, Object>): Promise<Record<string, Object>>;
  init(request: Record<string, Object>): Promise<void>;
  uninit(): Promise<void>;
  login(request: Record<string, Object>): Promise<void>;
  prepare(request: Record<string, Object>): Promise<void>;
  connect(request: Record<string, Object>): Promise<void>;
  updateAccessToken(request: Record<string, Object>): Promise<void>;
  /** Installs (or, with null, removes) the host-managed connect token refresher: an async function returning the new connect token, or null when none can be obtained. The core calls it once after the gateway rejects a connection on authentication and waits at most 20 seconds. Not needed with SDK-managed tokens (an auth block in the init config, even an empty one). */
  setConnectTokenRefresher(refresher: ConnectTokenRefresher | null): Promise<void>;
  setHeartbeatNatTimeout(request: SetHeartbeatNatTimeoutRequest): Promise<void>;
  heartbeatEffectiveInterval(): Promise<HeartbeatEffectiveIntervalResponse>;
  logout(): Promise<void>;
  dispose(): Promise<void>;
  hardReset(): Promise<void>;
  currentUserId(): Promise<Record<string, Object>>;
  isConnected(): Promise<boolean>;
  sessionActive(): Promise<boolean>;
  updatePushToken(request: PushTokenInput): Promise<PushLifecycleStatus>;
  clearPushToken(request: ClearPushTokenRequest): Promise<PushLifecycleStatus>;
  setPushPermission(request: SetPushPermissionRequest): Promise<PushLifecycleStatus>;
  reconcilePush(): Promise<PushLifecycleStatus>;
  pushStatus(): Promise<PushLifecycleStatus>;
}
