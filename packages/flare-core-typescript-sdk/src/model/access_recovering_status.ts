/** GENERATED. Do not edit by hand. */

/** Recovery state while every access point has failed. */
export interface AccessRecoveringStatus {
  /** wire: `sinceMs`. When recovery began, Unix milliseconds. */
  sinceMs: number;
  /** wire: `rounds`. Bootstrap rounds run so far. */
  rounds: number;
  /** wire: `nextRoundAtMs`. When the next round runs, Unix milliseconds; absent while the device has no network. */
  nextRoundAtMs?: number;
}
