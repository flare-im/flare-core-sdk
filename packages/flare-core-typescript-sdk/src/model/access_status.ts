/** GENERATED. Do not edit by hand. */
import type { AccessConnectAck } from './access_connect_ack';
import type { AccessPin } from './access_pin';
import type { AccessRecoveringStatus } from './access_recovering_status';
import type { AccessRefreshStatus } from './access_refresh_status';

/** Access directory and current link summary for the diagnostics page. */
export interface AccessStatus {
  /** wire: `loaded`. Whether the directory holds a usable manifest. False means there is no access point to connect to until bootstrap or a recovery link brings one. */
  loaded: boolean;
  /** wire: `serial`. Serial of the loaded access manifest; 0 before loading. */
  serial: number;
  /** wire: `source`. Where the manifest came from: seed, https:<mirror base>, wellKnown:<apId>, recovery, development, or none when the directory is empty. A restart keeps the original source. */
  source?: string;
  /** wire: `stale`. Whether the manifest is past expiresAtMs: it still connects, and refresh retries every 10 minutes. */
  stale: boolean;
  /** wire: `developmentMode`. Endpoints come from development-mode configuration. */
  developmentMode: boolean;
  /** wire: `issuedAtMs`. When the manifest was issued, Unix milliseconds; absent with an empty directory. */
  issuedAtMs?: number;
  /** wire: `expiresAtMs`. When the manifest expires, Unix milliseconds; absent with an empty directory. */
  expiresAtMs?: number;
  /** wire: `fetchedAtMs`. When the manifest reached this device, Unix milliseconds; absent for a seed or development mode. */
  fetchedAtMs?: number;
  /** wire: `regionId`. Home region. */
  regionId?: string;
  /** wire: `cellId`. Home cell. */
  cellId?: string;
  /** wire: `keystateSerial`. Serial of the loaded signing key state. */
  keystateSerial?: number;
  /** wire: `accessPointId`. Access point the IM connection is on. */
  accessPointId?: string;
  /** wire: `protocol`. Transport of the IM connection: quic or ws. */
  protocol?: string;
  /** wire: `pinned`. The manual pin, when one is in force. */
  pinned?: AccessPin;
  /** wire: `connectAck`. CONNECT_ACK diagnostics of the current connection; absent without one. */
  connectAck?: AccessConnectAck;
  /** wire: `refresh`. Manifest refresh progress; absent in development mode. */
  refresh?: AccessRefreshStatus;
  /** wire: `recovering`. Present only while every access point has failed and recovery is running. */
  recovering?: AccessRecoveringStatus;
}
