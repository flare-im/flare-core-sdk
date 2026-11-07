/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `connection` — Connection status and manual network lifecycle.
 */
import type { ConnectionStatus, NetworkChangeRequest, ServerClockResponse } from '../../model';

/** Connection status and manual network lifecycle. */
export interface ConnectionApi {
  /** getStatus maps to `flare_sdk_invoke_json`. Operation: `connection.get_status`. */
  getStatus(): Promise<ConnectionStatus>;
  /** reconnectNow maps to `flare_sdk_invoke_json`. Operation: `connection.reconnect_now`. */
  reconnectNow(): Promise<void>;
  /** disconnect maps to `flare_sdk_disconnect` via `ffi-symbol`. Operation: `connection.disconnect`. */
  disconnect(): Promise<void>;
  /** getServerClock maps to `flare_sdk_invoke_json`. Operation: `connection.server_clock`. */
  getServerClock(): Promise<ServerClockResponse>;
  /** notifyNetworkChange maps to `flare_sdk_invoke_json`. Operation: `connection.notify_network_change`. */
  notifyNetworkChange(request: NetworkChangeRequest): Promise<void>;
}
