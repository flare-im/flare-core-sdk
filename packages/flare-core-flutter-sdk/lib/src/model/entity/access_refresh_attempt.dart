// GENERATED. Do not edit by hand.

/// One source tried during a refresh round. Sources the round never reached are not listed.
final class AccessRefreshAttempt {
  /// wire: `source`. The source: https:<base>, wellKnown:<apId> or doh:<resolver>.
  final String source;
  /// wire: `tier`. Tier: mirror, wellKnown, pointer (a mirror resolved through DoH) or resolver (the DoH resolver itself).
  final String tier;
  /// wire: `document`. Document fetched: access, keys or pointer.
  final String document;
  /// wire: `result`. Result: adopted, notModified, sameSerial, olderSerial, rejected, failed or resolved.
  final String result;
  /// wire: `code`. Stable cross-platform code of a rejection or failure: badSignature, rollback, keyCert.expired, revoked, wrongPayloadType, wrongBootstrapId, tooLarge, malformedEnvelope, invalidPayload, unknownKey, unsupportedSchema, noNetwork, unreachable, tls, timeout, cancelled or http.<status>.
  final String? code;
  /// wire: `serial`. Serial of the document, when one was read.
  final int? serial;

  const AccessRefreshAttempt({
    this.source = '',
    this.tier = '',
    this.document = '',
    this.result = '',
    this.code,
    this.serial,
  });
}
