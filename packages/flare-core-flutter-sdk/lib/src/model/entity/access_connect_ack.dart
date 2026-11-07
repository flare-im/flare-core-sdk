// GENERATED. Do not edit by hand.

/// Diagnostics the gateway returned in CONNECT_ACK for the current connection; shown only, nothing acts on them.
final class AccessConnectAck {
  /// wire: `gatewayId`. Gateway instance serving the connection.
  final String? gatewayId;
  /// wire: `accessPointId`. Access point the server reports for the connection, when its gateway is configured with one.
  final String? accessPointId;
  /// wire: `accessSerial`. Newest access manifest serial the server knows.
  final int? accessSerial;
  /// wire: `heartbeatIntervalHintSec`. Gateway heartbeat interval in seconds; the heartbeat itself follows the access policy.
  final int? heartbeatIntervalHintSec;
  /// wire: `accessPointMismatch`. The server reports a different access point than the client chose; logged and counted, the connection stays up.
  final bool accessPointMismatch;

  const AccessConnectAck({
    this.gatewayId,
    this.accessPointId,
    this.accessSerial,
    this.heartbeatIntervalHintSec,
    this.accessPointMismatch = false,
  });
}
