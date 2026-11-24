// GENERATED. Do not edit by hand.
// Module API: `connection` — Connection status and manual network lifecycle.
import '../../model/model.dart';

/// Connection status and manual network lifecycle.
abstract interface class ConnectionApi {
  /// getStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.get_status`.
  Future<ConnectionStatus> getStatus();
  /// reconnectNow maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.reconnect_now`.
  Future<void> reconnectNow();
  /// replaceEndpoints maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.replace_endpoints`.
  Future<EndpointUpdate> replaceEndpoints(CoreEndpoints request);
  /// setProtocolMode maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.set_protocol_mode`.
  Future<void> setProtocolMode(SetProtocolModeRequest request);
  /// disconnect maps to `flare_sdk_disconnect` via `ffi-symbol`. Operation: `connection.disconnect`.
  Future<void> disconnect();
  /// getServerClock maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.server_clock`.
  Future<ServerClockResponse> getServerClock();
  /// notifyNetworkChange maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `connection.notify_network_change`.
  Future<void> notifyNetworkChange(NetworkChangeRequest request);
}
