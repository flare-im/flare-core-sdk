/** GENERATED. Do not edit by hand. */
import type { ConnectionPhase } from './connection_phase';
import type { ConnectionQuality } from './connection_quality';

/** Payload of connection://status and the value of connection.getStatus. Hosts replace their copy whole on every event. endpointRevision is present for host-selected endpoints. */
export interface ConnectionStatus {
  /** wire: `phase`. Where the link supervisor is. */
  phase: ConnectionPhase;
  /** wire: `quality`. Line quality; set only while online. */
  quality?: ConnectionQuality;
  /** wire: `protocol`. Transport of the current connection: quic or ws. */
  protocol?: string;
  /** wire: `endpointRevision`. Generation of the accepted host-selected address group. */
  endpointRevision?: number;
  /** wire: `rttMs`. Latest heartbeat round trip (the handshake time before the first sample). */
  rttMs?: number;
  /** wire: `attempt`. Which round of the current recovery this is; zero once online. */
  attempt: number;
  /** wire: `nextRetryAt`. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay). */
  nextRetryAt?: number;
  /** wire: `reason`. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: drain or manual. Transport failure: transportUnavailable. */
  reason?: string;
  /** wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase. */
  developmentMode: boolean;
}
