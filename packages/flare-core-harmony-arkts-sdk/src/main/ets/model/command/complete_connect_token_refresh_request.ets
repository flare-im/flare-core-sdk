// GENERATED. Do not edit by hand.

/** Answer to one connect token refresh request. */
export interface CompleteConnectTokenRefreshRequest {
  /** wire: `requestId`. Request id the core asked with. */
  requestId: number;
  /** wire: `token`. The new connect token; omitted or empty when none could be obtained. */
  token?: string;
}
