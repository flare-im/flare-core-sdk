// GENERATED. Do not edit by hand.

/** Progress of the periodic manifest refresh. */
export interface AccessRefreshStatus {
  /** wire: `lastAttemptAtMs`. When the last round ran, Unix milliseconds. */
  lastAttemptAtMs?: number;
  /** wire: `lastSuccessAtMs`. When a source last gave a trusted answer, Unix milliseconds. */
  lastSuccessAtMs?: number;
  /** wire: `lastOutcome`. Outcome of the last round: adopted, upToDate, oldValues or failed; absent before the first round. */
  lastOutcome?: string;
  /** wire: `nextAtMs`. When the next round runs, Unix milliseconds; absent while recovering without a network. */
  nextAtMs?: number;
}
