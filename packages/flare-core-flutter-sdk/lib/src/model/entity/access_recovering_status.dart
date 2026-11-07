// GENERATED. Do not edit by hand.

/// Recovery state while every access point has failed.
final class AccessRecoveringStatus {
  /// wire: `sinceMs`. When recovery began, Unix milliseconds.
  final int sinceMs;
  /// wire: `rounds`. Bootstrap rounds run so far.
  final int rounds;
  /// wire: `nextRoundAtMs`. When the next round runs, Unix milliseconds; absent while the device has no network.
  final int? nextRoundAtMs;

  const AccessRecoveringStatus({
    this.sinceMs = 0,
    this.rounds = 0,
    this.nextRoundAtMs,
  });
}
