// GENERATED. Do not edit by hand.

/// A manual access point pin.
final class AccessPin {
  /// wire: `accessPointId`. The pinned access point.
  final String accessPointId;
  /// wire: `expiresAtMs`. When the pin lapses, Unix milliseconds; an app restart also clears it.
  final int expiresAtMs;

  const AccessPin({
    this.accessPointId = '',
    this.expiresAtMs = 0,
  });
}
