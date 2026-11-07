// GENERATED. Do not edit by hand.
import { ConnectionPhase } from './connection_phase';
import { ConnectionQuality } from './connection_quality';

/** Payload of connection://status and the value of connection.getStatus. Every field is present (null without a value): hosts replace their copy whole on every event and hand it to the Kit ConnectionNotice unchanged. */
export interface ConnectionStatus {
  /** wire: `phase`. Where the link supervisor is. */
  phase: ConnectionPhase;
  /** wire: `quality`. Line quality; set only while online. */
  quality?: ConnectionQuality;
  /** wire: `accessPointId`. Current (or connecting) access point. */
  accessPointId?: string;
  /** wire: `cellId`. Cell of the current access point. */
  cellId?: string;
  /** wire: `regionId`. Region of the current access point. */
  regionId?: string;
  /** wire: `protocol`. Transport of the current connection: quic or ws. */
  protocol?: string;
  /** wire: `rttMs`. Latest heartbeat round trip (the handshake time before the first sample). */
  rttMs?: number;
  /** wire: `attempt`. Which round of the current recovery this is; zero once online. */
  attempt: number;
  /** wire: `nextRetryAt`. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay). */
  nextRetryAt?: number;
  /** wire: `reason`. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: failure, drain, failback, manual or manifest. */
  reason?: string;
  /** wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase. */
  developmentMode: boolean;
}
