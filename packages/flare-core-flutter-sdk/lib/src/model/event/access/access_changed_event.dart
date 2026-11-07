// GENERATED. Do not edit by hand.
import 'access_changes.dart';

/// Payload of access://changed: a new access manifest was accepted. Sent for every adoption; a periodic re-signature has empty changes.
final class AccessChangedEvent {
  /// wire: `serial`. Serial of the accepted manifest.
  final int serial;
  /// wire: `source`. Where it came from, in the form of AccessStatus.source.
  final String source;
  /// wire: `stale`. Whether it is past its expiry.
  final bool stale;
  /// wire: `developmentMode`. Endpoints come from development-mode configuration.
  final bool developmentMode;
  /// wire: `changes`. What changed against the previous manifest.
  final AccessChanges changes;

  const AccessChangedEvent({
    this.serial = 0,
    this.source = '',
    this.stale = false,
    this.developmentMode = false,
    required this.changes,
  });
}
