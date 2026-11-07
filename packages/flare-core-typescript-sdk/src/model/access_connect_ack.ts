/** GENERATED. Do not edit by hand. */

/** Diagnostics the gateway returned in CONNECT_ACK for the current connection; shown only, nothing acts on them. */
export interface AccessConnectAck {
  /** wire: `gatewayId`. Gateway instance serving the connection. */
  gatewayId?: string;
  /** wire: `accessPointId`. Access point the server reports for the connection, when its gateway is configured with one. */
  accessPointId?: string;
  /** wire: `accessSerial`. Newest access manifest serial the server knows. */
  accessSerial?: number;
  /** wire: `heartbeatIntervalHintSec`. Gateway heartbeat interval in seconds; the heartbeat itself follows the access policy. */
  heartbeatIntervalHintSec?: number;
  /** wire: `accessPointMismatch`. The server reports a different access point than the client chose; logged and counted, the connection stays up. */
  accessPointMismatch: boolean;
}
