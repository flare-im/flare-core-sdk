// GENERATED. Do not edit by hand.
import 'access_connect_ack.dart';
import 'access_pin.dart';
import 'access_recovering_status.dart';
import 'access_refresh_status.dart';

/// Access directory and current link summary for the diagnostics page.
final class AccessStatus {
  /// wire: `loaded`. Whether the directory holds a usable manifest. False means there is no access point to connect to until bootstrap or a recovery link brings one.
  final bool loaded;
  /// wire: `serial`. Serial of the loaded access manifest; 0 before loading.
  final int serial;
  /// wire: `source`. Where the manifest came from: seed, https:<mirror base>, wellKnown:<apId>, recovery, development, or none when the directory is empty. A restart keeps the original source.
  final String? source;
  /// wire: `stale`. Whether the manifest is past expiresAtMs: it still connects, and refresh retries every 10 minutes.
  final bool stale;
  /// wire: `developmentMode`. Endpoints come from development-mode configuration.
  final bool developmentMode;
  /// wire: `issuedAtMs`. When the manifest was issued, Unix milliseconds; absent with an empty directory.
  final int? issuedAtMs;
  /// wire: `expiresAtMs`. When the manifest expires, Unix milliseconds; absent with an empty directory.
  final int? expiresAtMs;
  /// wire: `fetchedAtMs`. When the manifest reached this device, Unix milliseconds; absent for a seed or development mode.
  final int? fetchedAtMs;
  /// wire: `regionId`. Home region.
  final String? regionId;
  /// wire: `cellId`. Home cell.
  final String? cellId;
  /// wire: `keystateSerial`. Serial of the loaded signing key state.
  final int? keystateSerial;
  /// wire: `accessPointId`. Access point the IM connection is on.
  final String? accessPointId;
  /// wire: `protocol`. Transport of the IM connection: quic or ws.
  final String? protocol;
  /// wire: `pinned`. The manual pin, when one is in force.
  final AccessPin? pinned;
  /// wire: `connectAck`. CONNECT_ACK diagnostics of the current connection; absent without one.
  final AccessConnectAck? connectAck;
  /// wire: `refresh`. Manifest refresh progress; absent in development mode.
  final AccessRefreshStatus? refresh;
  /// wire: `recovering`. Present only while every access point has failed and recovery is running.
  final AccessRecoveringStatus? recovering;

  const AccessStatus({
    this.loaded = false,
    this.serial = 0,
    this.source,
    this.stale = false,
    this.developmentMode = false,
    this.issuedAtMs,
    this.expiresAtMs,
    this.fetchedAtMs,
    this.regionId,
    this.cellId,
    this.keystateSerial,
    this.accessPointId,
    this.protocol,
    this.pinned,
    this.connectAck,
    this.refresh,
    this.recovering,
  });
}
