// GENERATED. Do not edit by hand.
import 'access_refresh_attempt.dart';

/// Result of one refresh round.
final class AccessRefreshReport {
  /// wire: `outcome`. adopted (a new manifest was taken), upToDate (a source confirmed there is no update), oldValues (notified mode only got old values; a manual refresh never reports it), failed (no source gave a trusted answer) or skipped (development mode).
  final String outcome;
  /// wire: `mode`. Round mode: background, notified or recovering.
  final String mode;
  /// wire: `serial`. Directory serial when the round ended.
  final int serial;
  /// wire: `source`. Source of the adopted manifest, in the form of AccessStatus.source; absent when nothing was adopted.
  final String? source;
  /// wire: `keystateSerial`. Serial of the current key state document.
  final int? keystateSerial;
  /// wire: `attempts`. Every source tried, in order.
  final List<AccessRefreshAttempt> attempts;

  const AccessRefreshReport({
    this.outcome = '',
    this.mode = '',
    this.serial = 0,
    this.source,
    this.keystateSerial,
    this.attempts = const [],
  });
}
