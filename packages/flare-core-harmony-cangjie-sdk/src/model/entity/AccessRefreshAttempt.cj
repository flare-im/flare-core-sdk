package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One source tried during a refresh round. Sources the round never reached are not listed.
public class AccessRefreshAttempt {
    // wire: `source`. The source: https:<base>, wellKnown:<apId> or doh:<resolver>.
    public let source: String
    // wire: `tier`. Tier: mirror, wellKnown, pointer (a mirror resolved through DoH) or resolver (the DoH resolver itself).
    public let tier: String
    // wire: `document`. Document fetched: access, keys or pointer.
    public let document: String
    // wire: `result`. Result: adopted, notModified, sameSerial, olderSerial, rejected, failed or resolved.
    public let result: String
    // wire: `code`. Optional. Stable cross-platform code of a rejection or failure: badSignature, rollback, keyCert.expired, revoked, wrongPayloadType, wrongBootstrapId, tooLarge, malformedEnvelope, invalidPayload, unknownKey, unsupportedSchema, noNetwork, unreachable, tls, timeout, cancelled or http.<status>.
    public let code: ?String
    // wire: `serial`. Optional. Serial of the document, when one was read.
    public let serial: ?UInt64

    public init(source!: String, tier!: String, document!: String, result!: String, code!: ?String, serial!: ?UInt64) {
        this.source = source
        this.tier = tier
        this.document = document
        this.result = result
        this.code = code
        this.serial = serial
    }
}
