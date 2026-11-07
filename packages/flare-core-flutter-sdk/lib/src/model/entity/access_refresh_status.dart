// GENERATED. Do not edit by hand.

/// Progress of the periodic manifest refresh.
final class AccessRefreshStatus {
  /// wire: `lastAttemptAtMs`. When the last round ran, Unix milliseconds.
  final int? lastAttemptAtMs;
  /// wire: `lastSuccessAtMs`. When a source last gave a trusted answer, Unix milliseconds.
  final int? lastSuccessAtMs;
  /// wire: `lastOutcome`. Outcome of the last round: adopted, upToDate, oldValues or failed; absent before the first round.
  final String? lastOutcome;
  /// wire: `nextAtMs`. When the next round runs, Unix milliseconds; absent while recovering without a network.
  final int? nextAtMs;

  const AccessRefreshStatus({
    this.lastAttemptAtMs,
    this.lastSuccessAtMs,
    this.lastOutcome,
    this.nextAtMs,
  });
}
