// GENERATED. Do not edit by hand.
// Native bridge descriptors generated from sdk-spec modules.

/// Describes how one SDK operation reaches the native layer.
final class NativeCallDescriptor {
  const NativeCallDescriptor({
    required this.module,
    required this.method,
    required this.operation,
    required this.transport,
    required this.cApi,
    required this.requestEncoding,
    required this.responseEncoding,
    required this.returnMode,
    required this.handlePolicy,
    this.dispatchOp,
    this.callback,
  });

  final String module;
  final String method;
  final String operation;
  final String transport;
  final String cApi;
  final String requestEncoding;
  final String responseEncoding;
  final String returnMode;
  final String handlePolicy;
  final String? dispatchOp;
  final String? callback;
}

/// Platform runtimes implement this bridge using FFI, JNI, N-API, WASM or host IPC.
/// Host-managed connect token refresh: resolves the new connect token, or null when none
/// can be obtained. Called on a background isolate task; the core waits at most 20 seconds.
typedef ConnectTokenRefresher = Future<String?> Function();

abstract interface class NativeBridge {
  Future<T> invoke<T>(NativeCallDescriptor descriptor, [Object? request]);
}

/// Implemented by bridges that can call back for a connect token (the FFI bridge); the client
/// reports capabilityUnavailable for a bridge without it.
abstract interface class ConnectTokenRefresherBridge {
  /// Installs (or, with null, removes) the connect token refresher: registers the native
  /// trampoline with flare_sdk_set_connect_token_refresher and answers every request with
  /// flare_sdk_complete_connect_token_refresh.
  Future<void> setConnectTokenRefresher(ConnectTokenRefresher? refresher);
}

abstract final class NativeCallMap {
  const NativeCallMap._();

  /// create maps to `flare_sdk_create` via `ffi-symbol`. Operation: `sdk.create`.
  static const sdkCreate = NativeCallDescriptor(
      module: "session",
      method: "create",
      operation: "sdk.create",
      transport: "ffi-symbol",
      cApi: "flare_sdk_create",
      requestEncoding: "none",
      responseEncoding: "handle",
      returnMode: "sync",
      handlePolicy: "create-handle");

  /// init maps to `flare_sdk_init` via `ffi-symbol`. Operation: `sdk.init`.
  static const sdkInit = NativeCallDescriptor(
      module: "session",
      method: "init",
      operation: "sdk.init",
      transport: "ffi-symbol",
      cApi: "flare_sdk_init",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// uninit maps to `flare_sdk_uninit` via `ffi-symbol`. Operation: `sdk.uninit`.
  static const sdkUninit = NativeCallDescriptor(
      module: "session",
      method: "uninit",
      operation: "sdk.uninit",
      transport: "ffi-symbol",
      cApi: "flare_sdk_uninit",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// login maps to `flare_sdk_login` via `ffi-symbol`. Operation: `sdk.login`.
  static const sdkLogin = NativeCallDescriptor(
      module: "session",
      method: "login",
      operation: "sdk.login",
      transport: "ffi-symbol",
      cApi: "flare_sdk_login",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// prepare maps to `flare_sdk_prepare` via `ffi-symbol`. Operation: `sdk.prepare`.
  static const sdkPrepare = NativeCallDescriptor(
      module: "session",
      method: "prepare",
      operation: "sdk.prepare",
      transport: "ffi-symbol",
      cApi: "flare_sdk_prepare",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// connect maps to `flare_sdk_connect` via `ffi-symbol`. Operation: `sdk.connect`.
  static const sdkConnect = NativeCallDescriptor(
      module: "session",
      method: "connect",
      operation: "sdk.connect",
      transport: "ffi-symbol",
      cApi: "flare_sdk_connect",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// updateAccessToken maps to `flare_sdk_update_access_token` via `ffi-symbol`. Operation: `sdk.update_access_token`.
  static const sdkUpdateAccessToken = NativeCallDescriptor(
      module: "session",
      method: "updateAccessToken",
      operation: "sdk.update_access_token",
      transport: "ffi-symbol",
      cApi: "flare_sdk_update_access_token",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// setConnectTokenRefresher maps to `flare_sdk_set_connect_token_refresher` via `ffi-symbol`. Operation: `sdk.set_connect_token_refresher`.
  static const sdkSetConnectTokenRefresher = NativeCallDescriptor(
      module: "session",
      method: "setConnectTokenRefresher",
      operation: "sdk.set_connect_token_refresher",
      transport: "ffi-symbol",
      cApi: "flare_sdk_set_connect_token_refresher",
      requestEncoding: "host-callback",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareTokenRefreshCallback");

  /// completeConnectTokenRefresh maps to `flare_sdk_complete_connect_token_refresh` via `ffi-symbol`. Operation: `sdk.complete_connect_token_refresh`.
  static const sdkCompleteConnectTokenRefresh = NativeCallDescriptor(
      module: "session",
      method: "completeConnectTokenRefresh",
      operation: "sdk.complete_connect_token_refresh",
      transport: "ffi-symbol",
      cApi: "flare_sdk_complete_connect_token_refresh",
      requestEncoding: "typed-ffi",
      responseEncoding: "boolean",
      returnMode: "sync",
      handlePolicy: "client-handle");

  /// setHeartbeatNatTimeout maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.set_heartbeat_nat_timeout`.
  static const sdkSetHeartbeatNatTimeout = NativeCallDescriptor(
      module: "session",
      method: "setHeartbeatNatTimeout",
      operation: "sdk.set_heartbeat_nat_timeout",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// heartbeatEffectiveInterval maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.heartbeat_effective_interval`.
  static const sdkHeartbeatEffectiveInterval = NativeCallDescriptor(
      module: "session",
      method: "heartbeatEffectiveInterval",
      operation: "sdk.heartbeat_effective_interval",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// logout maps to `flare_sdk_logout` via `ffi-symbol`. Operation: `sdk.logout`.
  static const sdkLogout = NativeCallDescriptor(
      module: "session",
      method: "logout",
      operation: "sdk.logout",
      transport: "ffi-symbol",
      cApi: "flare_sdk_logout",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// dispose maps to `flare_sdk_release` via `ffi-symbol`. Operation: `sdk.dispose`.
  static const sdkDispose = NativeCallDescriptor(
      module: "session",
      method: "dispose",
      operation: "sdk.dispose",
      transport: "ffi-symbol",
      cApi: "flare_sdk_release",
      requestEncoding: "handle",
      responseEncoding: "unit",
      returnMode: "sync",
      handlePolicy: "release-handle");

  /// hardReset maps to `flare_sdk_hard_reset` via `ffi-symbol`. Operation: `sdk.hard_reset`.
  static const sdkHardReset = NativeCallDescriptor(
      module: "session",
      method: "hardReset",
      operation: "sdk.hard_reset",
      transport: "ffi-symbol",
      cApi: "flare_sdk_hard_reset",
      requestEncoding: "none",
      responseEncoding: "unit",
      returnMode: "sync",
      handlePolicy: "reset-process");

  /// currentUserId maps to `flare_sdk_current_user_id` via `ffi-symbol`. Operation: `sdk.current_user_id`.
  static const sdkCurrentUserId = NativeCallDescriptor(
      module: "session",
      method: "currentUserId",
      operation: "sdk.current_user_id",
      transport: "ffi-symbol",
      cApi: "flare_sdk_current_user_id",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// isConnected maps to `flare_sdk_is_connected` via `ffi-symbol`. Operation: `sdk.is_connected`.
  static const sdkIsConnected = NativeCallDescriptor(
      module: "session",
      method: "isConnected",
      operation: "sdk.is_connected",
      transport: "ffi-symbol",
      cApi: "flare_sdk_is_connected",
      requestEncoding: "typed-ffi",
      responseEncoding: "boolean",
      returnMode: "sync",
      handlePolicy: "client-handle");

  /// sessionActive maps to `flare_sdk_session_active` via `ffi-symbol`. Operation: `sdk.session_active`.
  static const sdkSessionActive = NativeCallDescriptor(
      module: "session",
      method: "sessionActive",
      operation: "sdk.session_active",
      transport: "ffi-symbol",
      cApi: "flare_sdk_session_active",
      requestEncoding: "typed-ffi",
      responseEncoding: "boolean",
      returnMode: "sync",
      handlePolicy: "client-handle");

  /// updatePushToken maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.update_push_token`.
  static const sdkUpdatePushToken = NativeCallDescriptor(
      module: "session",
      method: "updatePushToken",
      operation: "sdk.update_push_token",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// clearPushToken maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.clear_push_token`.
  static const sdkClearPushToken = NativeCallDescriptor(
      module: "session",
      method: "clearPushToken",
      operation: "sdk.clear_push_token",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// setPushPermission maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.set_push_permission`.
  static const sdkSetPushPermission = NativeCallDescriptor(
      module: "session",
      method: "setPushPermission",
      operation: "sdk.set_push_permission",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// reconcilePush maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.reconcile_push`.
  static const sdkReconcilePush = NativeCallDescriptor(
      module: "session",
      method: "reconcilePush",
      operation: "sdk.reconcile_push",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// pushStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.push_status`.
  static const sdkPushStatus = NativeCallDescriptor(
      module: "session",
      method: "pushStatus",
      operation: "sdk.push_status",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.get_status`.
  static const connectionGetStatus = NativeCallDescriptor(
      module: "connection",
      method: "getStatus",
      operation: "connection.get_status",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// reconnectNow maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.reconnect_now`.
  static const connectionReconnectNow = NativeCallDescriptor(
      module: "connection",
      method: "reconnectNow",
      operation: "connection.reconnect_now",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// disconnect maps to `flare_sdk_disconnect` via `ffi-symbol`. Operation: `connection.disconnect`.
  static const connectionDisconnect = NativeCallDescriptor(
      module: "connection",
      method: "disconnect",
      operation: "connection.disconnect",
      transport: "ffi-symbol",
      cApi: "flare_sdk_disconnect",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getServerClock maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.server_clock`.
  static const connectionServerClock = NativeCallDescriptor(
      module: "connection",
      method: "getServerClock",
      operation: "connection.server_clock",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// notifyNetworkChange maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.notify_network_change`.
  static const connectionNotifyNetworkChange = NativeCallDescriptor(
      module: "connection",
      method: "notifyNetworkChange",
      operation: "connection.notify_network_change",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.get_status`.
  static const accessGetStatus = NativeCallDescriptor(
      module: "access",
      method: "getStatus",
      operation: "access.get_status",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// listAccessPoints maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.list_access_points`.
  static const accessListAccessPoints = NativeCallDescriptor(
      module: "access",
      method: "listAccessPoints",
      operation: "access.list_access_points",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// pin maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.pin`.
  static const accessPin = NativeCallDescriptor(
      module: "access",
      method: "pin",
      operation: "access.pin",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// unpin maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.unpin`.
  static const accessUnpin = NativeCallDescriptor(
      module: "access",
      method: "unpin",
      operation: "access.unpin",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// refresh maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.refresh`.
  static const accessRefresh = NativeCallDescriptor(
      module: "access",
      method: "refresh",
      operation: "access.refresh",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// importRecovery maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.import_recovery`.
  static const accessImportRecovery = NativeCallDescriptor(
      module: "access",
      method: "importRecovery",
      operation: "access.import_recovery",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// exportDiagnostics maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.export_diagnostics`.
  static const accessExportDiagnostics = NativeCallDescriptor(
      module: "access",
      method: "exportDiagnostics",
      operation: "access.export_diagnostics",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// setAppState maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `lifecycle.set_app_state`.
  static const lifecycleSetAppState = NativeCallDescriptor(
      module: "lifecycle",
      method: "setAppState",
      operation: "lifecycle.set_app_state",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getState maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.get_state`.
  static const updateGetState = NativeCallDescriptor(
      module: "update",
      method: "getState",
      operation: "update.get_state",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// check maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.check`.
  static const updateCheck = NativeCallDescriptor(
      module: "update",
      method: "check",
      operation: "update.check",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// download maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.download`.
  static const updateDownload = NativeCallDescriptor(
      module: "update",
      method: "download",
      operation: "update.download",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// install maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.install`.
  static const updateInstall = NativeCallDescriptor(
      module: "update",
      method: "install",
      operation: "update.install",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// reportInstall maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.report_install`.
  static const updateReportInstall = NativeCallDescriptor(
      module: "update",
      method: "reportInstall",
      operation: "update.report_install",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// defer maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.defer`.
  static const updateDefer = NativeCallDescriptor(
      module: "update",
      method: "defer",
      operation: "update.defer",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// skip maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.skip`.
  static const updateSkip = NativeCallDescriptor(
      module: "update",
      method: "skip",
      operation: "update.skip",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// markPrompted maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.mark_prompted`.
  static const updateMarkPrompted = NativeCallDescriptor(
      module: "update",
      method: "markPrompted",
      operation: "update.mark_prompted",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// setLocale maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.set_locale`.
  static const updateSetLocale = NativeCallDescriptor(
      module: "update",
      method: "setLocale",
      operation: "update.set_locale",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getResources maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.get_resources`.
  static const updateGetResources = NativeCallDescriptor(
      module: "update",
      method: "getResources",
      operation: "update.get_resources",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// listConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list`.
  static const conversationList = NativeCallDescriptor(
      module: "conversations",
      method: "listConversations",
      operation: "conversation.list",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// listConversationsByQuery maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_by_query`.
  static const conversationListByQuery = NativeCallDescriptor(
      module: "conversations",
      method: "listConversationsByQuery",
      operation: "conversation.list_by_query",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// listConversationsIncludingArchived maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_including_archived`.
  static const conversationListIncludingArchived = NativeCallDescriptor(
      module: "conversations",
      method: "listConversationsIncludingArchived",
      operation: "conversation.list_including_archived",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get`.
  static const conversationGet = NativeCallDescriptor(
      module: "conversations",
      method: "getConversation",
      operation: "conversation.get",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getOneConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_one`.
  static const conversationGetOne = NativeCallDescriptor(
      module: "conversations",
      method: "getOneConversation",
      operation: "conversation.get_one",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getGroupConversationByUserIds maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_group_by_user_ids`.
  static const conversationGetGroupByUserIds = NativeCallDescriptor(
      module: "conversations",
      method: "getGroupConversationByUserIds",
      operation: "conversation.get_group_by_user_ids",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getMultipleConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.get_multiple`.
  static const conversationGetMultiple = NativeCallDescriptor(
      module: "conversations",
      method: "getMultipleConversations",
      operation: "conversation.get_multiple",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// listConversationsPaginated maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_paginated`.
  static const conversationListPaginated = NativeCallDescriptor(
      module: "conversations",
      method: "listConversationsPaginated",
      operation: "conversation.list_paginated",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// listRawConversations maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.list_raw`.
  static const conversationListRaw = NativeCallDescriptor(
      module: "conversations",
      method: "listRawConversations",
      operation: "conversation.list_raw",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getTotalUnread maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.total_unread`.
  static const conversationTotalUnread = NativeCallDescriptor(
      module: "conversations",
      method: "getTotalUnread",
      operation: "conversation.total_unread",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// bootstrapHomeTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.bootstrap_home`.
  static const conversationBootstrapHome = NativeCallDescriptor(
      module: "conversations",
      method: "bootstrapHomeTimeline",
      operation: "conversation.bootstrap_home",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// openConversationTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.open_timeline`.
  static const conversationOpenTimeline = NativeCallDescriptor(
      module: "conversations",
      method: "openConversationTimeline",
      operation: "conversation.open_timeline",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// markConversationRead maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.mark_read`.
  static const conversationMarkRead = NativeCallDescriptor(
      module: "conversations",
      method: "markConversationRead",
      operation: "conversation.mark_read",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// setConversationPinned maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_pinned`.
  static const conversationSetPinned = NativeCallDescriptor(
      module: "conversations",
      method: "setConversationPinned",
      operation: "conversation.set_pinned",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// setConversationMuted maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_muted`.
  static const conversationSetMuted = NativeCallDescriptor(
      module: "conversations",
      method: "setConversationMuted",
      operation: "conversation.set_muted",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// setConversationArchived maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.set_archived`.
  static const conversationSetArchived = NativeCallDescriptor(
      module: "conversations",
      method: "setConversationArchived",
      operation: "conversation.set_archived",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// markConversationUnread maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.mark_unread`.
  static const conversationMarkUnread = NativeCallDescriptor(
      module: "conversations",
      method: "markConversationUnread",
      operation: "conversation.mark_unread",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// deleteConversation maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.delete`.
  static const conversationDelete = NativeCallDescriptor(
      module: "conversations",
      method: "deleteConversation",
      operation: "conversation.delete",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// updateConversationDraft maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.update_draft`.
  static const conversationUpdateDraft = NativeCallDescriptor(
      module: "conversations",
      method: "updateConversationDraft",
      operation: "conversation.update_draft",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// clearLocalChatHistory maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.clear_local_chat_history`.
  static const conversationClearLocalChatHistory = NativeCallDescriptor(
      module: "conversations",
      method: "clearLocalChatHistory",
      operation: "conversation.clear_local_chat_history",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// clearChatHistoryForSelf maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `conversation.clear_chat_history_for_self`.
  static const conversationClearChatHistoryForSelf = NativeCallDescriptor(
      module: "conversations",
      method: "clearChatHistoryForSelf",
      operation: "conversation.clear_chat_history_for_self",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// listSupportedBuildOperations maps to `flare_message_build_json` via `catalog-static`. Operation: `message_builder.list_catalog`.
  static const messageBuilderListCatalog = NativeCallDescriptor(
      module: "message_builder",
      method: "listSupportedBuildOperations",
      operation: "message_builder.list_catalog",
      transport: "catalog-static",
      cApi: "flare_message_build_json",
      requestEncoding: "local-static",
      responseEncoding: "json-object",
      returnMode: "local",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// normalizeRichDocFromMarkdown maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `rich_doc_v2.normalize_from_markdown`.
  static const richDocV2NormalizeFromMarkdown = NativeCallDescriptor(
      module: "message_builder",
      method: "normalizeRichDocFromMarkdown",
      operation: "rich_doc_v2.normalize_from_markdown",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// normalizeRichDocFromHtml maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `rich_doc_v2.normalize_from_html`.
  static const richDocV2NormalizeFromHtml = NativeCallDescriptor(
      module: "message_builder",
      method: "normalizeRichDocFromHtml",
      operation: "rich_doc_v2.normalize_from_html",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// normalizeRichDocFromDocJson maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `rich_doc_v2.normalize_from_doc_json`.
  static const richDocV2NormalizeFromDocJson = NativeCallDescriptor(
      module: "message_builder",
      method: "normalizeRichDocFromDocJson",
      operation: "rich_doc_v2.normalize_from_doc_json",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// buildAnnouncement maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_announcement`. Operation: `message_builder.create_announcement`.
  static const messageBuilderCreateAnnouncement = NativeCallDescriptor(
      module: "message_builder",
      method: "buildAnnouncement",
      operation: "message_builder.create_announcement",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_announcement",
      callback: "FlareResultCallback");

  /// buildAudio maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_audio`. Operation: `message_builder.create_audio`.
  static const messageBuilderCreateAudio = NativeCallDescriptor(
      module: "message_builder",
      method: "buildAudio",
      operation: "message_builder.create_audio",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_audio",
      callback: "FlareResultCallback");

  /// buildCard maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_card`. Operation: `message_builder.create_card`.
  static const messageBuilderCreateCard = NativeCallDescriptor(
      module: "message_builder",
      method: "buildCard",
      operation: "message_builder.create_card",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_card",
      callback: "FlareResultCallback");

  /// buildCustom maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_custom`. Operation: `message_builder.create_custom`.
  static const messageBuilderCreateCustom = NativeCallDescriptor(
      module: "message_builder",
      method: "buildCustom",
      operation: "message_builder.create_custom",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_custom",
      callback: "FlareResultCallback");

  /// buildEmoji maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_emoji`. Operation: `message_builder.create_emoji`.
  static const messageBuilderCreateEmoji = NativeCallDescriptor(
      module: "message_builder",
      method: "buildEmoji",
      operation: "message_builder.create_emoji",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_emoji",
      callback: "FlareResultCallback");

  /// buildFile maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_file`. Operation: `message_builder.create_file`.
  static const messageBuilderCreateFile = NativeCallDescriptor(
      module: "message_builder",
      method: "buildFile",
      operation: "message_builder.create_file",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_file",
      callback: "FlareResultCallback");

  /// buildForward maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_forward`. Operation: `message_builder.create_forward`.
  static const messageBuilderCreateForward = NativeCallDescriptor(
      module: "message_builder",
      method: "buildForward",
      operation: "message_builder.create_forward",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_forward",
      callback: "FlareResultCallback");

  /// buildImage maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_image`. Operation: `message_builder.create_image`.
  static const messageBuilderCreateImage = NativeCallDescriptor(
      module: "message_builder",
      method: "buildImage",
      operation: "message_builder.create_image",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_image",
      callback: "FlareResultCallback");

  /// buildImageGroup maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_image_group`. Operation: `message_builder.create_image_group`.
  static const messageBuilderCreateImageGroup = NativeCallDescriptor(
      module: "message_builder",
      method: "buildImageGroup",
      operation: "message_builder.create_image_group",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_image_group",
      callback: "FlareResultCallback");

  /// buildLinkCard maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_link_card`. Operation: `message_builder.create_link_card`.
  static const messageBuilderCreateLinkCard = NativeCallDescriptor(
      module: "message_builder",
      method: "buildLinkCard",
      operation: "message_builder.create_link_card",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_link_card",
      callback: "FlareResultCallback");

  /// buildLocation maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_location`. Operation: `message_builder.create_location`.
  static const messageBuilderCreateLocation = NativeCallDescriptor(
      module: "message_builder",
      method: "buildLocation",
      operation: "message_builder.create_location",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_location",
      callback: "FlareResultCallback");

  /// buildMiniProgram maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_mini_program`. Operation: `message_builder.create_mini_program`.
  static const messageBuilderCreateMiniProgram = NativeCallDescriptor(
      module: "message_builder",
      method: "buildMiniProgram",
      operation: "message_builder.create_mini_program",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_mini_program",
      callback: "FlareResultCallback");

  /// buildNotification maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_notification`. Operation: `message_builder.create_notification`.
  static const messageBuilderCreateNotification = NativeCallDescriptor(
      module: "message_builder",
      method: "buildNotification",
      operation: "message_builder.create_notification",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_notification",
      callback: "FlareResultCallback");

  /// buildPlaceholder maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_placeholder`. Operation: `message_builder.create_placeholder`.
  static const messageBuilderCreatePlaceholder = NativeCallDescriptor(
      module: "message_builder",
      method: "buildPlaceholder",
      operation: "message_builder.create_placeholder",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_placeholder",
      callback: "FlareResultCallback");

  /// buildQuote maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_quote`. Operation: `message_builder.create_quote`.
  static const messageBuilderCreateQuote = NativeCallDescriptor(
      module: "message_builder",
      method: "buildQuote",
      operation: "message_builder.create_quote",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_quote",
      callback: "FlareResultCallback");

  /// buildRichDoc maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_rich_doc`. Operation: `message_builder.create_rich_doc`.
  static const messageBuilderCreateRichDoc = NativeCallDescriptor(
      module: "message_builder",
      method: "buildRichDoc",
      operation: "message_builder.create_rich_doc",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_rich_doc",
      callback: "FlareResultCallback");

  /// buildSchedule maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_schedule`. Operation: `message_builder.create_schedule`.
  static const messageBuilderCreateSchedule = NativeCallDescriptor(
      module: "message_builder",
      method: "buildSchedule",
      operation: "message_builder.create_schedule",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_schedule",
      callback: "FlareResultCallback");

  /// buildSticker maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_sticker`. Operation: `message_builder.create_sticker`.
  static const messageBuilderCreateSticker = NativeCallDescriptor(
      module: "message_builder",
      method: "buildSticker",
      operation: "message_builder.create_sticker",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_sticker",
      callback: "FlareResultCallback");

  /// buildSystem maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_system`. Operation: `message_builder.create_system`.
  static const messageBuilderCreateSystem = NativeCallDescriptor(
      module: "message_builder",
      method: "buildSystem",
      operation: "message_builder.create_system",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_system",
      callback: "FlareResultCallback");

  /// buildTask maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_task`. Operation: `message_builder.create_task`.
  static const messageBuilderCreateTask = NativeCallDescriptor(
      module: "message_builder",
      method: "buildTask",
      operation: "message_builder.create_task",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_task",
      callback: "FlareResultCallback");

  /// buildText maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_text`. Operation: `message_builder.create_text`.
  static const messageBuilderCreateText = NativeCallDescriptor(
      module: "message_builder",
      method: "buildText",
      operation: "message_builder.create_text",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_text",
      callback: "FlareResultCallback");

  /// buildThreadReply maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_thread_reply`. Operation: `message_builder.create_thread_reply`.
  static const messageBuilderCreateThreadReply = NativeCallDescriptor(
      module: "message_builder",
      method: "buildThreadReply",
      operation: "message_builder.create_thread_reply",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_thread_reply",
      callback: "FlareResultCallback");

  /// buildVideo maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_video`. Operation: `message_builder.create_video`.
  static const messageBuilderCreateVideo = NativeCallDescriptor(
      module: "message_builder",
      method: "buildVideo",
      operation: "message_builder.create_video",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_video",
      callback: "FlareResultCallback");

  /// buildVote maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_vote`. Operation: `message_builder.create_vote`.
  static const messageBuilderCreateVote = NativeCallDescriptor(
      module: "message_builder",
      method: "buildVote",
      operation: "message_builder.create_vote",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_vote",
      callback: "FlareResultCallback");

  /// buildWithContent maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_with_content`. Operation: `message_builder.create_with_content`.
  static const messageBuilderCreateWithContent = NativeCallDescriptor(
      module: "message_builder",
      method: "buildWithContent",
      operation: "message_builder.create_with_content",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "create_with_content",
      callback: "FlareResultCallback");

  /// createTextMessage maps to `flare_message_create_text` via `ffi-symbol`. Operation: `message.create_text`.
  static const messageCreateText = NativeCallDescriptor(
      module: "messages",
      method: "createTextMessage",
      operation: "message.create_text",
      transport: "ffi-symbol",
      cApi: "flare_message_create_text",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// dispatchMessage maps to `flare_message_dispatch_json` via `dispatch-json`. Operation: `message.dispatch`.
  static const messageDispatch = NativeCallDescriptor(
      module: "messages",
      method: "dispatchMessage",
      operation: "message.dispatch",
      transport: "dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// sendMessageNoOss maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `send_no_oss`. Operation: `message.send_no_oss`.
  static const messageSendNoOss = NativeCallDescriptor(
      module: "messages",
      method: "sendMessageNoOss",
      operation: "message.send_no_oss",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "send_no_oss",
      callback: "FlareResultCallback");

  /// sendMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `send`. Operation: `message.send`.
  static const messageSend = NativeCallDescriptor(
      module: "messages",
      method: "sendMessage",
      operation: "message.send",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "send",
      callback: "FlareResultCallback");

  /// listMessages maps to `flare_message_list` via `ffi-symbol`. Operation: `message.list`.
  static const messageList = NativeCallDescriptor(
      module: "messages",
      method: "listMessages",
      operation: "message.list",
      transport: "ffi-symbol",
      cApi: "flare_message_list",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// recallMessage maps to `flare_message_recall` via `ffi-symbol`. Operation: `message.recall`.
  static const messageRecall = NativeCallDescriptor(
      module: "messages",
      method: "recallMessage",
      operation: "message.recall",
      transport: "ffi-symbol",
      cApi: "flare_message_recall",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// editTextByMessageId maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `edit_text_by_message_id`. Operation: `message.edit_text_by_message_id`.
  static const messageEditTextByMessageId = NativeCallDescriptor(
      module: "messages",
      method: "editTextByMessageId",
      operation: "message.edit_text_by_message_id",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "edit_text_by_message_id",
      callback: "FlareResultCallback");

  /// deleteMessage maps to `flare_message_delete` via `ffi-symbol`. Operation: `message.delete`.
  static const messageDelete = NativeCallDescriptor(
      module: "messages",
      method: "deleteMessage",
      operation: "message.delete",
      transport: "ffi-symbol",
      cApi: "flare_message_delete",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// deleteMessageForSelf maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `delete_for_self`. Operation: `message.delete_for_self`.
  static const messageDeleteForSelf = NativeCallDescriptor(
      module: "messages",
      method: "deleteMessageForSelf",
      operation: "message.delete_for_self",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "delete_for_self",
      callback: "FlareResultCallback");

  /// deleteMessageForEveryone maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `delete_for_everyone`. Operation: `message.delete_for_everyone`.
  static const messageDeleteForEveryone = NativeCallDescriptor(
      module: "messages",
      method: "deleteMessageForEveryone",
      operation: "message.delete_for_everyone",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "delete_for_everyone",
      callback: "FlareResultCallback");

  /// markMessageReadAndBurn maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_read_and_burn`. Operation: `message.mark_read_and_burn`.
  static const messageMarkReadAndBurn = NativeCallDescriptor(
      module: "messages",
      method: "markMessageReadAndBurn",
      operation: "message.mark_read_and_burn",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "mark_read_and_burn",
      callback: "FlareResultCallback");

  /// addReaction maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `add_reaction`. Operation: `message.add_reaction`.
  static const messageAddReaction = NativeCallDescriptor(
      module: "messages",
      method: "addReaction",
      operation: "message.add_reaction",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "add_reaction",
      callback: "FlareResultCallback");

  /// removeReaction maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `remove_reaction`. Operation: `message.remove_reaction`.
  static const messageRemoveReaction = NativeCallDescriptor(
      module: "messages",
      method: "removeReaction",
      operation: "message.remove_reaction",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "remove_reaction",
      callback: "FlareResultCallback");

  /// pinMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `pin`. Operation: `message.pin`.
  static const messagePin = NativeCallDescriptor(
      module: "messages",
      method: "pinMessage",
      operation: "message.pin",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "pin",
      callback: "FlareResultCallback");

  /// unpinMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unpin`. Operation: `message.unpin`.
  static const messageUnpin = NativeCallDescriptor(
      module: "messages",
      method: "unpinMessage",
      operation: "message.unpin",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "unpin",
      callback: "FlareResultCallback");

  /// pinMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `pin_by_message_id`. Operation: `message.pin_by_message_id`.
  static const messagePinByMessageId = NativeCallDescriptor(
      module: "messages",
      method: "pinMessageById",
      operation: "message.pin_by_message_id",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "pin_by_message_id",
      callback: "FlareResultCallback");

  /// unpinMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unpin_by_message_id`. Operation: `message.unpin_by_message_id`.
  static const messageUnpinByMessageId = NativeCallDescriptor(
      module: "messages",
      method: "unpinMessageById",
      operation: "message.unpin_by_message_id",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "unpin_by_message_id",
      callback: "FlareResultCallback");

  /// markMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark`. Operation: `message.mark`.
  static const messageMark = NativeCallDescriptor(
      module: "messages",
      method: "markMessage",
      operation: "message.mark",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "mark",
      callback: "FlareResultCallback");

  /// markMessageWithColor maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_with_color`. Operation: `message.mark_with_color`.
  static const messageMarkWithColor = NativeCallDescriptor(
      module: "messages",
      method: "markMessageWithColor",
      operation: "message.mark_with_color",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "mark_with_color",
      callback: "FlareResultCallback");

  /// unmarkMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unmark`. Operation: `message.unmark`.
  static const messageUnmark = NativeCallDescriptor(
      module: "messages",
      method: "unmarkMessage",
      operation: "message.unmark",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "unmark",
      callback: "FlareResultCallback");

  /// markMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `mark_by_message_id`. Operation: `message.mark_by_message_id`.
  static const messageMarkByMessageId = NativeCallDescriptor(
      module: "messages",
      method: "markMessageById",
      operation: "message.mark_by_message_id",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "mark_by_message_id",
      callback: "FlareResultCallback");

  /// unmarkMessageById maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `unmark_by_message_id`. Operation: `message.unmark_by_message_id`.
  static const messageUnmarkByMessageId = NativeCallDescriptor(
      module: "messages",
      method: "unmarkMessageById",
      operation: "message.unmark_by_message_id",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "unmark_by_message_id",
      callback: "FlareResultCallback");

  /// getMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `get`. Operation: `message.get`.
  static const messageGet = NativeCallDescriptor(
      module: "messages",
      method: "getMessage",
      operation: "message.get",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "get",
      callback: "FlareResultCallback");

  /// getRawMessage maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `get_raw`. Operation: `message.get_raw`.
  static const messageGetRaw = NativeCallDescriptor(
      module: "messages",
      method: "getRawMessage",
      operation: "message.get_raw",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "get_raw",
      callback: "FlareResultCallback");

  /// searchMessages maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search`. Operation: `message.search`.
  static const messageSearch = NativeCallDescriptor(
      module: "messages",
      method: "searchMessages",
      operation: "message.search",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "search",
      callback: "FlareResultCallback");

  /// searchMessagesByQuery maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search_by_query`. Operation: `message.search_by_query`.
  static const messageSearchByQuery = NativeCallDescriptor(
      module: "messages",
      method: "searchMessagesByQuery",
      operation: "message.search_by_query",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "search_by_query",
      callback: "FlareResultCallback");

  /// searchMessagesInConversation maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `search_in_conversation`. Operation: `message.search_in_conversation`.
  static const messageSearchInConversation = NativeCallDescriptor(
      module: "messages",
      method: "searchMessagesInConversation",
      operation: "message.search_in_conversation",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "search_in_conversation",
      callback: "FlareResultCallback");

  /// readReceiptMembers maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `read_receipt_members`. Operation: `message.read_receipt_members`.
  static const messageReadReceiptMembers = NativeCallDescriptor(
      module: "messages",
      method: "readReceiptMembers",
      operation: "message.read_receipt_members",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "read_receipt_members",
      callback: "FlareResultCallback");

  /// editRichDocByMessageId maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `edit_rich_doc_by_message_id`. Operation: `message.edit_rich_doc_by_message_id`.
  static const messageEditRichDocByMessageId = NativeCallDescriptor(
      module: "messages",
      method: "editRichDocByMessageId",
      operation: "message.edit_rich_doc_by_message_id",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "edit_rich_doc_by_message_id",
      callback: "FlareResultCallback");

  /// setTyping maps to `flare_message_dispatch_json` via `message-dispatch-json`, dispatch op `typing`. Operation: `message.typing`.
  static const messageTyping = NativeCallDescriptor(
      module: "messages",
      method: "setTyping",
      operation: "message.typing",
      transport: "message-dispatch-json",
      cApi: "flare_message_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "typing",
      callback: "FlareResultCallback");

  /// syncConversationSummaries maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.conversation_summaries`.
  static const syncConversationSummaries = NativeCallDescriptor(
      module: "sync",
      method: "syncConversationSummaries",
      operation: "sync.conversation_summaries",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// syncConversationSummariesWithVersions maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.conversation_summaries_with_versions`.
  static const syncConversationSummariesWithVersions = NativeCallDescriptor(
      module: "sync",
      method: "syncConversationSummariesWithVersions",
      operation: "sync.conversation_summaries_with_versions",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// bootstrapStartupHome maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.bootstrap_startup_home`.
  static const syncBootstrapStartupHome = NativeCallDescriptor(
      module: "sync",
      method: "bootstrapStartupHome",
      operation: "sync.bootstrap_startup_home",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// backfillConversationHistory maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sync.conversation_history_backfill`.
  static const syncConversationHistoryBackfill = NativeCallDescriptor(
      module: "sync",
      method: "backfillConversationHistory",
      operation: "sync.conversation_history_backfill",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// syncConversation maps to `flare_sdk_sync_conversation` via `ffi-symbol`. Operation: `sync.conversation`.
  static const syncConversation = NativeCallDescriptor(
      module: "sync",
      method: "syncConversation",
      operation: "sync.conversation",
      transport: "ffi-symbol",
      cApi: "flare_sdk_sync_conversation",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// syncMessages maps to `flare_sdk_sync_messages` via `ffi-symbol`. Operation: `sync.messages`.
  static const syncMessages = NativeCallDescriptor(
      module: "sync",
      method: "syncMessages",
      operation: "sync.messages",
      transport: "ffi-symbol",
      cApi: "flare_sdk_sync_messages",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// upsertUserProfiles maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `user.upsert_profiles`.
  static const userUpsertProfiles = NativeCallDescriptor(
      module: "user",
      method: "upsertUserProfiles",
      operation: "user.upsert_profiles",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getUserPresence maps to `flare_sdk_get_user_presence` via `ffi-symbol`. Operation: `presence.get`.
  static const presenceGet = NativeCallDescriptor(
      module: "presence",
      method: "getUserPresence",
      operation: "presence.get",
      transport: "ffi-symbol",
      cApi: "flare_sdk_get_user_presence",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// batchGetUserPresence maps to `flare_sdk_batch_get_user_presence` via `ffi-symbol`. Operation: `presence.batch_get`.
  static const presenceBatchGet = NativeCallDescriptor(
      module: "presence",
      method: "batchGetUserPresence",
      operation: "presence.batch_get",
      transport: "ffi-symbol",
      cApi: "flare_sdk_batch_get_user_presence",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// subscribeUserPresence maps to `flare_sdk_subscribe_user_presence` via `ffi-symbol`. Operation: `presence.subscribe`.
  static const presenceSubscribe = NativeCallDescriptor(
      module: "presence",
      method: "subscribeUserPresence",
      operation: "presence.subscribe",
      transport: "ffi-symbol",
      cApi: "flare_sdk_subscribe_user_presence",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// uploadFile maps to `flare_media_upload_file` via `ffi-symbol`. Operation: `media.upload_file`.
  static const mediaUploadFile = NativeCallDescriptor(
      module: "media",
      method: "uploadFile",
      operation: "media.upload_file",
      transport: "ffi-symbol",
      cApi: "flare_media_upload_file",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// uploadImage maps to `flare_media_upload_image` via `ffi-symbol`. Operation: `media.upload_image`.
  static const mediaUploadImage = NativeCallDescriptor(
      module: "media",
      method: "uploadImage",
      operation: "media.upload_image",
      transport: "ffi-symbol",
      cApi: "flare_media_upload_image",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// uploadVideo maps to `flare_media_upload_video` via `ffi-symbol`. Operation: `media.upload_video`.
  static const mediaUploadVideo = NativeCallDescriptor(
      module: "media",
      method: "uploadVideo",
      operation: "media.upload_video",
      transport: "ffi-symbol",
      cApi: "flare_media_upload_video",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// uploadBytes maps to `flare_media_upload_bytes` via `ffi-symbol`. Operation: `media.upload_bytes`.
  static const mediaUploadBytes = NativeCallDescriptor(
      module: "media",
      method: "uploadBytes",
      operation: "media.upload_bytes",
      transport: "ffi-symbol",
      cApi: "flare_media_upload_bytes",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// deleteFile maps to `flare_media_delete_file` via `ffi-symbol`. Operation: `media.delete_file`.
  static const mediaDeleteFile = NativeCallDescriptor(
      module: "media",
      method: "deleteFile",
      operation: "media.delete_file",
      transport: "ffi-symbol",
      cApi: "flare_media_delete_file",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getMediaUrl maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `get_url`. Operation: `media.get_url`.
  static const mediaGetUrl = NativeCallDescriptor(
      module: "media",
      method: "getMediaUrl",
      operation: "media.get_url",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "get_url",
      callback: "FlareResultCallback");

  /// getTempDownloadUrl maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `temp_download_url`. Operation: `media.temp_download_url`.
  static const mediaTempDownloadUrl = NativeCallDescriptor(
      module: "media",
      method: "getTempDownloadUrl",
      operation: "media.temp_download_url",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "temp_download_url",
      callback: "FlareResultCallback");

  /// resolveMediaAccess maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `resolve_access`. Operation: `media.resolve_access`.
  static const mediaResolveAccess = NativeCallDescriptor(
      module: "media",
      method: "resolveMediaAccess",
      operation: "media.resolve_access",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "resolve_access",
      callback: "FlareResultCallback");

  /// cacheRemoteMedia maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cache_remote`. Operation: `media.cache_remote`.
  static const mediaCacheRemote = NativeCallDescriptor(
      module: "media",
      method: "cacheRemoteMedia",
      operation: "media.cache_remote",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "cache_remote",
      callback: "FlareResultCallback");

  /// getMediaCacheStats maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cache_stats`. Operation: `media.cache_stats`.
  static const mediaCacheStats = NativeCallDescriptor(
      module: "media",
      method: "getMediaCacheStats",
      operation: "media.cache_stats",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "cache_stats",
      callback: "FlareResultCallback");

  /// setMediaCacheMaxBytes maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `set_cache_max_bytes`. Operation: `media.set_cache_max_bytes`.
  static const mediaSetCacheMaxBytes = NativeCallDescriptor(
      module: "media",
      method: "setMediaCacheMaxBytes",
      operation: "media.set_cache_max_bytes",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "set_cache_max_bytes",
      callback: "FlareResultCallback");

  /// setMediaCacheRoot maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `set_cache_root`. Operation: `media.set_cache_root`.
  static const mediaSetCacheRoot = NativeCallDescriptor(
      module: "media",
      method: "setMediaCacheRoot",
      operation: "media.set_cache_root",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "set_cache_root",
      callback: "FlareResultCallback");

  /// clearMediaCache maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `clear_cache`. Operation: `media.clear_cache`.
  static const mediaClearCache = NativeCallDescriptor(
      module: "media",
      method: "clearMediaCache",
      operation: "media.clear_cache",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "clear_cache",
      callback: "FlareResultCallback");

  /// getUserDownloadSubfolder maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_subfolder`. Operation: `media.user_download_get_subfolder`.
  static const mediaUserDownloadGetSubfolder = NativeCallDescriptor(
      module: "media",
      method: "getUserDownloadSubfolder",
      operation: "media.user_download_get_subfolder",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "user_download_get_subfolder",
      callback: "FlareResultCallback");

  /// setUserDownloadSubfolder maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_set_subfolder`. Operation: `media.user_download_set_subfolder`.
  static const mediaUserDownloadSetSubfolder = NativeCallDescriptor(
      module: "media",
      method: "setUserDownloadSubfolder",
      operation: "media.user_download_set_subfolder",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "user_download_set_subfolder",
      callback: "FlareResultCallback");

  /// getUserDownloadSavedPath maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_saved_path`. Operation: `media.user_download_get_saved_path`.
  static const mediaUserDownloadGetSavedPath = NativeCallDescriptor(
      module: "media",
      method: "getUserDownloadSavedPath",
      operation: "media.user_download_get_saved_path",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "user_download_get_saved_path",
      callback: "FlareResultCallback");

  /// deleteUserDownloadRecord maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_delete_record`. Operation: `media.user_download_delete_record`.
  static const mediaUserDownloadDeleteRecord = NativeCallDescriptor(
      module: "media",
      method: "deleteUserDownloadRecord",
      operation: "media.user_download_delete_record",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "user_download_delete_record",
      callback: "FlareResultCallback");

  /// getUserDownloadDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_directory`. Operation: `media.user_download_get_directory`.
  static const mediaUserDownloadGetDirectory = NativeCallDescriptor(
      module: "media",
      method: "getUserDownloadDirectory",
      operation: "media.user_download_get_directory",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "user_download_get_directory",
      callback: "FlareResultCallback");

  /// setUserDownloadDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_set_directory`. Operation: `media.user_download_set_directory`.
  static const mediaUserDownloadSetDirectory = NativeCallDescriptor(
      module: "media",
      method: "setUserDownloadDirectory",
      operation: "media.user_download_set_directory",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "user_download_set_directory",
      callback: "FlareResultCallback");

  /// downloadToUserDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `download_to_user_directory`. Operation: `media.download_to_user_directory`.
  static const mediaDownloadToUserDirectory = NativeCallDescriptor(
      module: "media",
      method: "downloadToUserDirectory",
      operation: "media.download_to_user_directory",
      transport: "media-dispatch-json",
      cApi: "flare_media_dispatch_json",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "download_to_user_directory",
      callback: "FlareResultCallback");

  /// cancelUserFileDownload maps to `flare_media_cancel_user_file_download` via `ffi-symbol`. Operation: `media.cancel_user_file_download`.
  static const mediaCancelUserFileDownload = NativeCallDescriptor(
      module: "media",
      method: "cancelUserFileDownload",
      operation: "media.cancel_user_file_download",
      transport: "ffi-symbol",
      cApi: "flare_media_cancel_user_file_download",
      requestEncoding: "typed-ffi",
      responseEncoding: "boolean",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// downloadFileToDownloads maps to `flare_media_download_file_to_downloads` via `ffi-symbol`. Operation: `media.download_file_to_downloads`.
  static const mediaDownloadFileToDownloads = NativeCallDescriptor(
      module: "media",
      method: "downloadFileToDownloads",
      operation: "media.download_file_to_downloads",
      transport: "ffi-symbol",
      cApi: "flare_media_download_file_to_downloads",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// preparePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `prepare_plugin_command`. Operation: `capability.prepare_plugin_command`.
  static const capabilityPreparePluginCommand = NativeCallDescriptor(
      module: "capabilities",
      method: "preparePluginCommand",
      operation: "capability.prepare_plugin_command",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "prepare_plugin_command",
      callback: "FlareResultCallback");

  /// pendingPluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `pending_plugin_command`. Operation: `capability.pending_plugin_command`.
  static const capabilityPendingPluginCommand = NativeCallDescriptor(
      module: "capabilities",
      method: "pendingPluginCommand",
      operation: "capability.pending_plugin_command",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "pending_plugin_command",
      callback: "FlareResultCallback");

  /// reconcilePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `reconcile_plugin_command`. Operation: `capability.reconcile_plugin_command`.
  static const capabilityReconcilePluginCommand = NativeCallDescriptor(
      module: "capabilities",
      method: "reconcilePluginCommand",
      operation: "capability.reconcile_plugin_command",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "reconcile_plugin_command",
      callback: "FlareResultCallback");

  /// submitPluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `submit_plugin_command`. Operation: `capability.submit_plugin_command`.
  static const capabilitySubmitPluginCommand = NativeCallDescriptor(
      module: "capabilities",
      method: "submitPluginCommand",
      operation: "capability.submit_plugin_command",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "submit_plugin_command",
      callback: "FlareResultCallback");

  /// acknowledgePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `acknowledge_plugin_command`. Operation: `capability.acknowledge_plugin_command`.
  static const capabilityAcknowledgePluginCommand = NativeCallDescriptor(
      module: "capabilities",
      method: "acknowledgePluginCommand",
      operation: "capability.acknowledge_plugin_command",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "acknowledge_plugin_command",
      callback: "FlareResultCallback");

  /// invokePluginAction maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_invoke`. Operation: `capability.plugin_ui_invoke`.
  static const capabilityPluginUiInvoke = NativeCallDescriptor(
      module: "capabilities",
      method: "invokePluginAction",
      operation: "capability.plugin_ui_invoke",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_ui_invoke",
      callback: "FlareResultCallback");

  /// presentPluginMessage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_present`. Operation: `capability.plugin_ui_present`.
  static const capabilityPluginUiPresent = NativeCallDescriptor(
      module: "capabilities",
      method: "presentPluginMessage",
      operation: "capability.plugin_ui_present",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_ui_present",
      callback: "FlareResultCallback");

  /// pluginUiAction maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_action`. Operation: `capability.plugin_ui_action`.
  static const capabilityPluginUiAction = NativeCallDescriptor(
      module: "capabilities",
      method: "pluginUiAction",
      operation: "capability.plugin_ui_action",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_ui_action",
      callback: "FlareResultCallback");

  /// resolvePluginMessage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_resolve`. Operation: `capability.plugin_ui_resolve`.
  static const capabilityPluginUiResolve = NativeCallDescriptor(
      module: "capabilities",
      method: "resolvePluginMessage",
      operation: "capability.plugin_ui_resolve",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_ui_resolve",
      callback: "FlareResultCallback");

  /// pluginUiCatalog maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_catalog`. Operation: `capability.plugin_ui_catalog`.
  static const capabilityPluginUiCatalog = NativeCallDescriptor(
      module: "capabilities",
      method: "pluginUiCatalog",
      operation: "capability.plugin_ui_catalog",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_ui_catalog",
      callback: "FlareResultCallback");

  /// pluginComposerActions maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_composer_actions`. Operation: `capability.plugin_composer_actions`.
  static const capabilityPluginComposerActions = NativeCallDescriptor(
      module: "capabilities",
      method: "pluginComposerActions",
      operation: "capability.plugin_composer_actions",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_composer_actions",
      callback: "FlareResultCallback");

  /// pluginDetail maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_detail`. Operation: `capability.plugin_detail`.
  static const capabilityPluginDetail = NativeCallDescriptor(
      module: "capabilities",
      method: "pluginDetail",
      operation: "capability.plugin_detail",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_detail",
      callback: "FlareResultCallback");

  /// pluginPage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_page`. Operation: `capability.plugin_page`.
  static const capabilityPluginPage = NativeCallDescriptor(
      module: "capabilities",
      method: "pluginPage",
      operation: "capability.plugin_page",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_page",
      callback: "FlareResultCallback");

  /// pluginFileUpload maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_file_upload`. Operation: `capability.plugin_file_upload`.
  static const capabilityPluginFileUpload = NativeCallDescriptor(
      module: "capabilities",
      method: "pluginFileUpload",
      operation: "capability.plugin_file_upload",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_file_upload",
      callback: "FlareResultCallback");

  /// pluginAccountEntries maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_account_entries`. Operation: `capability.plugin_account_entries`.
  static const capabilityPluginAccountEntries = NativeCallDescriptor(
      module: "capabilities",
      method: "pluginAccountEntries",
      operation: "capability.plugin_account_entries",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_account_entries",
      callback: "FlareResultCallback");

  /// invalidatePluginCatalog maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_catalog_invalidate`. Operation: `capability.plugin_catalog_invalidate`.
  static const capabilityPluginCatalogInvalidate = NativeCallDescriptor(
      module: "capabilities",
      method: "invalidatePluginCatalog",
      operation: "capability.plugin_catalog_invalidate",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "unit",
      returnMode: "callback-unit",
      handlePolicy: "client-handle",
      dispatchOp: "plugin_catalog_invalidate",
      callback: "FlareResultCallback");

  /// listCapabilities maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_list`. Operation: `capability.list`.
  static const capabilityList = NativeCallDescriptor(
      module: "capabilities",
      method: "listCapabilities",
      operation: "capability.list",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "capability_list",
      callback: "FlareResultCallback");

  /// dispatchCapability maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_dispatch`. Operation: `capability.dispatch`.
  static const capabilityDispatch = NativeCallDescriptor(
      module: "capabilities",
      method: "dispatchCapability",
      operation: "capability.dispatch",
      transport: "capability-dispatch-json",
      cApi: "flare_capability_dispatch_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      dispatchOp: "capability_dispatch",
      callback: "FlareResultCallback");

  /// openTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.open`.
  static const viewTimelineOpen = NativeCallDescriptor(
      module: "views",
      method: "openTimeline",
      operation: "view.timeline.open",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// loadOlderTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.load_older`.
  static const viewTimelineLoadOlder = NativeCallDescriptor(
      module: "views",
      method: "loadOlderTimeline",
      operation: "view.timeline.load_older",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// loadNewerTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.load_newer`.
  static const viewTimelineLoadNewer = NativeCallDescriptor(
      module: "views",
      method: "loadNewerTimeline",
      operation: "view.timeline.load_newer",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// jumpToLatestTimeline maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.jump_to_latest`.
  static const viewTimelineJumpToLatest = NativeCallDescriptor(
      module: "views",
      method: "jumpToLatestTimeline",
      operation: "view.timeline.jump_to_latest",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// timelineSnapshot maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.timeline.snapshot`.
  static const viewTimelineSnapshot = NativeCallDescriptor(
      module: "views",
      method: "timelineSnapshot",
      operation: "view.timeline.snapshot",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// openConversationList maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.conversation_list.open`.
  static const viewConversationListOpen = NativeCallDescriptor(
      module: "views",
      method: "openConversationList",
      operation: "view.conversation_list.open",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// close maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `view.close`.
  static const viewClose = NativeCallDescriptor(
      module: "views",
      method: "close",
      operation: "view.close",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// subscribeEvents maps to `flare_event_subscribe` via `ffi-symbol`. Operation: `event.subscribe`.
  static const eventSubscribe = NativeCallDescriptor(
      module: "events",
      method: "subscribeEvents",
      operation: "event.subscribe",
      transport: "ffi-symbol",
      cApi: "flare_event_subscribe",
      requestEncoding: "typed-ffi",
      responseEncoding: "subscription",
      returnMode: "event-stream",
      handlePolicy: "client-handle",
      callback: "FlareEventCallback");

  /// subscribeEventsBatch maps to `flare_event_subscribe_batch` via `ffi-symbol`. Operation: `event.subscribe_batch`.
  static const eventSubscribeBatch = NativeCallDescriptor(
      module: "events",
      method: "subscribeEventsBatch",
      operation: "event.subscribe_batch",
      transport: "ffi-symbol",
      cApi: "flare_event_subscribe_batch",
      requestEncoding: "typed-ffi",
      responseEncoding: "subscription",
      returnMode: "event-stream",
      handlePolicy: "client-handle",
      callback: "FlareEventBatchCallback");

  /// unsubscribe maps to `flare_event_unsubscribe` via `ffi-symbol`. Operation: `event.unsubscribe`.
  static const eventUnsubscribe = NativeCallDescriptor(
      module: "events",
      method: "unsubscribe",
      operation: "event.unsubscribe",
      transport: "ffi-symbol",
      cApi: "flare_event_unsubscribe",
      requestEncoding: "typed-ffi",
      responseEncoding: "unit",
      returnMode: "sync",
      handlePolicy: "subscription-handle");

  /// unsubscribeAll maps to `flare_event_unsubscribe_all` via `ffi-symbol`. Operation: `event.unsubscribe_all`.
  static const eventUnsubscribeAll = NativeCallDescriptor(
      module: "events",
      method: "unsubscribeAll",
      operation: "event.unsubscribe_all",
      transport: "ffi-symbol",
      cApi: "flare_event_unsubscribe_all",
      requestEncoding: "none",
      responseEncoding: "unit",
      returnMode: "sync",
      handlePolicy: "process");

  /// getSdkVersion maps to `flare_sdk_version` via `ffi-symbol`. Operation: `diagnostics.sdk_version`.
  static const diagnosticsSdkVersion = NativeCallDescriptor(
      module: "diagnostics",
      method: "getSdkVersion",
      operation: "diagnostics.sdk_version",
      transport: "ffi-symbol",
      cApi: "flare_sdk_version",
      requestEncoding: "none",
      responseEncoding: "json-object",
      returnMode: "sync-string",
      handlePolicy: "process");

  /// getFfiContractVersion maps to `flare_sdk_ffi_contract_version` via `ffi-symbol`. Operation: `diagnostics.ffi_contract_version`.
  static const diagnosticsFfiContractVersion = NativeCallDescriptor(
      module: "diagnostics",
      method: "getFfiContractVersion",
      operation: "diagnostics.ffi_contract_version",
      transport: "ffi-symbol",
      cApi: "flare_sdk_ffi_contract_version",
      requestEncoding: "none",
      responseEncoding: "json-object",
      returnMode: "sync-string",
      handlePolicy: "process");

  /// getDataRoot maps to `flare_sdk_data_root` via `ffi-symbol`. Operation: `diagnostics.data_root`.
  static const diagnosticsDataRoot = NativeCallDescriptor(
      module: "diagnostics",
      method: "getDataRoot",
      operation: "diagnostics.data_root",
      transport: "ffi-symbol",
      cApi: "flare_sdk_data_root",
      requestEncoding: "typed-ffi",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// getRuntimeHealth maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `diagnostics.runtime_health`.
  static const diagnosticsRuntimeHealth = NativeCallDescriptor(
      module: "diagnostics",
      method: "getRuntimeHealth",
      operation: "diagnostics.runtime_health",
      transport: "contract-invoke-json",
      cApi: "flare_sdk_invoke_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");

  /// Internal typed message builder dispatch over `flare_message_build_json`.
  static const messageBuilderDispatch = NativeCallDescriptor(
      module: "message_builder",
      method: "dispatchTypedBuild",
      operation: "message_builder.dispatch",
      transport: "dispatch-json",
      cApi: "flare_message_build_json",
      requestEncoding: "json",
      responseEncoding: "json-object",
      returnMode: "callback",
      handlePolicy: "client-handle",
      callback: "FlareResultCallback");
}
