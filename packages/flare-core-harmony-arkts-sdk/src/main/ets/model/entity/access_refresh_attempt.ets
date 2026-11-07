// GENERATED. Do not edit by hand.

/** One source tried during a refresh round. Sources the round never reached are not listed. */
export interface AccessRefreshAttempt {
  /** wire: `source`. The source: https:<base>, wellKnown:<apId> or doh:<resolver>. */
  source: string;
  /** wire: `tier`. Tier: mirror, wellKnown, pointer (a mirror resolved through DoH) or resolver (the DoH resolver itself). */
  tier: string;
  /** wire: `document`. Document fetched: access, keys or pointer. */
  document: string;
  /** wire: `result`. Result: adopted, notModified, sameSerial, olderSerial, rejected, failed or resolved. */
  result: string;
  /** wire: `code`. Stable cross-platform code of a rejection or failure: badSignature, rollback, keyCert.expired, revoked, wrongPayloadType, wrongBootstrapId, tooLarge, malformedEnvelope, invalidPayload, unknownKey, unsupportedSchema, noNetwork, unreachable, tls, timeout, cancelled or http.<status>. */
  code?: string;
  /** wire: `serial`. Serial of the document, when one was read. */
  serial?: number;
}
