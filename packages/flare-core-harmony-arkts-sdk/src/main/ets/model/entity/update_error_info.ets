// GENERATED. Do not edit by hand.

/** Why the last update action did not go through. */
export interface UpdateErrorInfo {
  /** wire: `code`. update.* code. */
  code: string;
  /** wire: `retryable`. Retrying can help. */
  retryable: boolean;
  /** wire: `fallbackUrl`. Page to send the user to; absent on the web. */
  fallbackUrl?: string;
}
