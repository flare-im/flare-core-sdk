/** GENERATED. Do not edit by hand. */
import type { AccessChanges } from './access_changes';

/** Payload of access://changed: a new access manifest was accepted. Sent for every adoption; a periodic re-signature has empty changes. */
export interface AccessChangedEvent {
  /** wire: `serial`. Serial of the accepted manifest. */
  serial: number;
  /** wire: `source`. Where it came from, in the form of AccessStatus.source. */
  source: string;
  /** wire: `stale`. Whether it is past its expiry. */
  stale: boolean;
  /** wire: `developmentMode`. Endpoints come from development-mode configuration. */
  developmentMode: boolean;
  /** wire: `changes`. What changed against the previous manifest. */
  changes: AccessChanges;
}
