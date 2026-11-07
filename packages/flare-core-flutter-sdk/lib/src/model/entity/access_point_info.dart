// GENERATED. Do not edit by hand.

/// One access point of the home cell with its health on the current network.
final class AccessPointInfo {
  /// wire: `accessPointId`. Access point id.
  final String accessPointId;
  /// wire: `regionId`. Region the access point is in.
  final String regionId;
  /// wire: `host`. Host name shown on the diagnostics page.
  final String host;
  /// wire: `status`. Manifest status: active, draining, disabled or unknown.
  final String status;
  /// wire: `rttMs`. Smoothed round trip on the current network, when measured.
  final double? rttMs;
  /// wire: `breaker`. Circuit breaker state: closed, open or halfOpen.
  final String breaker;
  /// wire: `protocolWinner`. Protocol that last won the race on this network: quic or ws.
  final String? protocolWinner;
  /// wire: `pinned`. Whether this access point is manually pinned.
  final bool pinned;
  /// wire: `current`. Whether the IM connection is on this access point.
  final bool current;

  const AccessPointInfo({
    this.accessPointId = '',
    this.regionId = '',
    this.host = '',
    this.status = '',
    this.rttMs,
    this.breaker = '',
    this.protocolWinner,
    this.pinned = false,
    this.current = false,
  });
}
