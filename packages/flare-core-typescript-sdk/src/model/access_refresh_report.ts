/** GENERATED. Do not edit by hand. */
import type { AccessRefreshAttempt } from './access_refresh_attempt';

/** Result of one refresh round. */
export interface AccessRefreshReport {
  /** wire: `outcome`. adopted (a new manifest was taken), upToDate (a source confirmed there is no update), oldValues (notified mode only got old values; a manual refresh never reports it), failed (no source gave a trusted answer) or skipped (development mode). */
  outcome: string;
  /** wire: `mode`. Round mode: background, notified or recovering. */
  mode: string;
  /** wire: `serial`. Directory serial when the round ended. */
  serial: number;
  /** wire: `source`. Source of the adopted manifest, in the form of AccessStatus.source; absent when nothing was adopted. */
  source?: string;
  /** wire: `keystateSerial`. Serial of the current key state document. */
  keystateSerial?: number;
  /** wire: `attempts`. Every source tried, in order. */
  attempts: AccessRefreshAttempt[];
}
