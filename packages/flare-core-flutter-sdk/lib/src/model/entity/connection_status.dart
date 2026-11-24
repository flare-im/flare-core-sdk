// GENERATED. Do not edit by hand.
import 'connection_phase.dart';
import 'connection_quality.dart';

/// Payload of connection://status and the value of connection.getStatus. Hosts replace their copy whole on every event. endpointRevision is present for host-selected endpoints.
final class ConnectionStatus {
  /// wire: `phase`. Where the link supervisor is.
  final ConnectionPhase phase;
  /// wire: `quality`. Line quality; set only while online.
  final ConnectionQuality? quality;
  /// wire: `protocol`. Transport of the current connection: quic or ws.
  final String? protocol;
  /// wire: `endpointRevision`. Generation of the accepted host-selected address group.
  final int? endpointRevision;
  /// wire: `rttMs`. Latest heartbeat round trip (the handshake time before the first sample).
  final int? rttMs;
  /// wire: `attempt`. Which round of the current recovery this is; zero once online.
  final int attempt;
  /// wire: `nextRetryAt`. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay).
  final int? nextRetryAt;
  /// wire: `reason`. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: drain or manual. Transport failure: transportUnavailable.
  final String? reason;
  /// wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase.
  final bool developmentMode;

  const ConnectionStatus({
    required this.phase,
    this.quality,
    this.protocol,
    this.endpointRevision,
    this.rttMs,
    this.attempt = 0,
    this.nextRetryAt,
    this.reason,
    this.developmentMode = false,
  });
}
