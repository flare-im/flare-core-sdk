// GENERATED. Do not edit by hand.
// Module API: `session` — SDK lifecycle, authenticated session and process-level utilities.
import '../../model/model.dart';
import '../../contract/bridge_contract.dart' show ConnectTokenRefresher;

/// SDK lifecycle, authenticated session and process-level utilities.
abstract interface class SessionApi {
  /// create maps to `flare_sdk_create` via `ffi-symbol`. Operation: `sdk.create`.
  Future<Map<String, Object?>> create(Map<String, Object?> request);
  /// init maps to `flare_sdk_init` via `ffi-symbol`. Operation: `sdk.init`.
  Future<void> init(Map<String, Object?> request);
  /// uninit maps to `flare_sdk_uninit` via `ffi-symbol`. Operation: `sdk.uninit`.
  Future<void> uninit();
  /// login maps to `flare_sdk_login` via `ffi-symbol`. Operation: `sdk.login`.
  Future<void> login(Map<String, Object?> request);
  /// prepare maps to `flare_sdk_prepare` via `ffi-symbol`. Operation: `sdk.prepare`.
  Future<void> prepare(Map<String, Object?> request);
  /// connect maps to `flare_sdk_connect` via `ffi-symbol`. Operation: `sdk.connect`.
  Future<void> connect(Map<String, Object?> request);
  /// updateAccessToken maps to `flare_sdk_update_access_token` via `ffi-symbol`. Operation: `sdk.update_access_token`.
  Future<void> updateAccessToken(Map<String, Object?> request);
  /// Installs (or, with null, removes) the host-managed connect token refresher: an async function returning the new connect token, or null when none can be obtained. The core calls it once after the gateway rejects a connection on authentication and waits at most 20 seconds. Not needed with SDK-managed tokens (an auth block in the init config, even an empty one).
  Future<void> setConnectTokenRefresher(ConnectTokenRefresher? refresher);
  /// setHeartbeatNatTimeout maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.set_heartbeat_nat_timeout`.
  Future<void> setHeartbeatNatTimeout(SetHeartbeatNatTimeoutRequest request);
  /// heartbeatEffectiveInterval maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.heartbeat_effective_interval`.
  Future<HeartbeatEffectiveIntervalResponse> heartbeatEffectiveInterval();
  /// logout maps to `flare_sdk_logout` via `ffi-symbol`. Operation: `sdk.logout`.
  Future<void> logout();
  /// dispose maps to `flare_sdk_release` via `ffi-symbol`. Operation: `sdk.dispose`.
  Future<void> dispose();
  /// hardReset maps to `flare_sdk_hard_reset` via `ffi-symbol`. Operation: `sdk.hard_reset`.
  Future<void> hardReset();
  /// currentUserId maps to `flare_sdk_current_user_id` via `ffi-symbol`. Operation: `sdk.current_user_id`.
  Future<Map<String, Object?>> currentUserId();
  /// isConnected maps to `flare_sdk_is_connected` via `ffi-symbol`. Operation: `sdk.is_connected`.
  Future<bool> isConnected();
  /// sessionActive maps to `flare_sdk_session_active` via `ffi-symbol`. Operation: `sdk.session_active`.
  Future<bool> sessionActive();
  /// updatePushToken maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.update_push_token`.
  Future<PushLifecycleStatus> updatePushToken(PushTokenInput request);
  /// clearPushToken maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.clear_push_token`.
  Future<PushLifecycleStatus> clearPushToken(ClearPushTokenRequest request);
  /// setPushPermission maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.set_push_permission`.
  Future<PushLifecycleStatus> setPushPermission(SetPushPermissionRequest request);
  /// reconcilePush maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.reconcile_push`.
  Future<PushLifecycleStatus> reconcilePush();
  /// pushStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.push_status`.
  Future<PushLifecycleStatus> pushStatus();
}
