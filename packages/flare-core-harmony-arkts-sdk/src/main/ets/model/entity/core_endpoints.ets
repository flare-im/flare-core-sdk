// GENERATED. Do not edit by hand.

/** CoreEndpoints */
export interface CoreEndpoints {
  /** wire: `baseUrl`. Core API base URL, including any deployment path prefix. */
  baseUrl: string;
  /** wire: `mediaBaseUrl`. Optional media API base. Defaults to the Core API base. */
  mediaBaseUrl?: string;
  /** wire: `quicUrl`. Optional native QUIC gateway; WebSocket remains available. */
  quicUrl?: string;
  /** wire: `websocketUrl`. Fully qualified WebSocket gateway URL. */
  websocketUrl: string;
}
