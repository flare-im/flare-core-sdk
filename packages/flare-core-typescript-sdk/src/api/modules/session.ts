/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `session` — SDK lifecycle, authenticated session and process-level utilities.
 */
import type { ConnectTokenRefresher } from '../../contract';
import type { ClearPushTokenRequest, HeartbeatEffectiveIntervalResponse, PushLifecycleStatus, PushTokenInput, SetHeartbeatNatTimeoutRequest, SetPushPermissionRequest } from '../../model';
import type { CreateClientRequest, CreateClientResponse, CurrentUserIdResponse, LoginRequest, SdkConfig, UpdateAccessTokenRequest } from '../types';

/** SDK lifecycle, authenticated session and process-level utilities. */
export interface SessionApi {
  /** create maps to `flare_sdk_create` via `ffi-symbol`. Operation: `sdk.create`. */
  create(request: CreateClientRequest): Promise<CreateClientResponse>;
  /** init maps to `flare_sdk_init` via `ffi-symbol`. Operation: `sdk.init`. */
  init(request: SdkConfig): Promise<void>;
  /** uninit maps to `flare_sdk_uninit` via `ffi-symbol`. Operation: `sdk.uninit`. */
  uninit(): Promise<void>;
  /** login maps to `flare_sdk_login` via `ffi-symbol`. Operation: `sdk.login`. */
  login(request: LoginRequest): Promise<void>;
  /** prepare maps to `flare_sdk_prepare` via `ffi-symbol`. Operation: `sdk.prepare`. */
  prepare(request: LoginRequest): Promise<void>;
  /** connect maps to `flare_sdk_connect` via `ffi-symbol`. Operation: `sdk.connect`. */
  connect(request: LoginRequest): Promise<void>;
  /** updateAccessToken maps to `flare_sdk_update_access_token` via `ffi-symbol`. Operation: `sdk.update_access_token`. */
  updateAccessToken(request: UpdateAccessTokenRequest): Promise<void>;
  /** setConnectTokenRefresher maps to `flare_sdk_set_connect_token_refresher` via `ffi-symbol`. Operation: `sdk.set_connect_token_refresher`. */
  setConnectTokenRefresher(refresher: ConnectTokenRefresher | null): Promise<void>;
  /** setHeartbeatNatTimeout maps to `flare_sdk_invoke_json`. Operation: `sdk.set_heartbeat_nat_timeout`. */
  setHeartbeatNatTimeout(request: SetHeartbeatNatTimeoutRequest): Promise<void>;
  /** heartbeatEffectiveInterval maps to `flare_sdk_invoke_json`. Operation: `sdk.heartbeat_effective_interval`. */
  heartbeatEffectiveInterval(): Promise<HeartbeatEffectiveIntervalResponse>;
  /** logout maps to `flare_sdk_logout` via `ffi-symbol`. Operation: `sdk.logout`. */
  logout(): Promise<void>;
  /** dispose maps to `flare_sdk_release` via `ffi-symbol`. Operation: `sdk.dispose`. */
  dispose(): Promise<void>;
  /** hardReset maps to `flare_sdk_hard_reset` via `ffi-symbol`. Operation: `sdk.hard_reset`. */
  hardReset(): Promise<void>;
  /** currentUserId maps to `flare_sdk_current_user_id` via `ffi-symbol`. Operation: `sdk.current_user_id`. */
  currentUserId(): Promise<CurrentUserIdResponse>;
  /** isConnected maps to `flare_sdk_is_connected` via `ffi-symbol`. Operation: `sdk.is_connected`. */
  isConnected(): Promise<boolean>;
  /** sessionActive maps to `flare_sdk_session_active` via `ffi-symbol`. Operation: `sdk.session_active`. */
  sessionActive(): Promise<boolean>;
  /** updatePushToken maps to `flare_sdk_invoke_json`. Operation: `sdk.update_push_token`. */
  updatePushToken(request: PushTokenInput): Promise<PushLifecycleStatus>;
  /** clearPushToken maps to `flare_sdk_invoke_json`. Operation: `sdk.clear_push_token`. */
  clearPushToken(request: ClearPushTokenRequest): Promise<PushLifecycleStatus>;
  /** setPushPermission maps to `flare_sdk_invoke_json`. Operation: `sdk.set_push_permission`. */
  setPushPermission(request: SetPushPermissionRequest): Promise<PushLifecycleStatus>;
  /** reconcilePush maps to `flare_sdk_invoke_json`. Operation: `sdk.reconcile_push`. */
  reconcilePush(): Promise<PushLifecycleStatus>;
  /** pushStatus maps to `flare_sdk_invoke_json`. Operation: `sdk.push_status`. */
  pushStatus(): Promise<PushLifecycleStatus>;
}
