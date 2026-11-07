// GENERATED. Do not edit by hand.

/** One access point of the home cell with its health on the current network. */
export interface AccessPointInfo {
  /** wire: `accessPointId`. Access point id. */
  accessPointId: string;
  /** wire: `regionId`. Region the access point is in. */
  regionId: string;
  /** wire: `host`. Host name shown on the diagnostics page. */
  host: string;
  /** wire: `status`. Manifest status: active, draining, disabled or unknown. */
  status: string;
  /** wire: `rttMs`. Smoothed round trip on the current network, when measured. */
  rttMs?: number;
  /** wire: `breaker`. Circuit breaker state: closed, open or halfOpen. */
  breaker: string;
  /** wire: `protocolWinner`. Protocol that last won the race on this network: quic or ws. */
  protocolWinner?: string;
  /** wire: `pinned`. Whether this access point is manually pinned. */
  pinned: boolean;
  /** wire: `current`. Whether the IM connection is on this access point. */
  current: boolean;
}
