package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** One source tried during a refresh round. Sources the round never reached are not listed. */
data class AccessRefreshAttempt(
    /** wire: `source`. The source: https:<base>, wellKnown:<apId> or doh:<resolver>. */
    val source: String = "",
    /** wire: `tier`. Tier: mirror, wellKnown, pointer (a mirror resolved through DoH) or resolver (the DoH resolver itself). */
    val tier: String = "",
    /** wire: `document`. Document fetched: access, keys or pointer. */
    val document: String = "",
    /** wire: `result`. Result: adopted, notModified, sameSerial, olderSerial, rejected, failed or resolved. */
    val result: String = "",
    /** wire: `code`. Stable cross-platform code of a rejection or failure: badSignature, rollback, keyCert.expired, revoked, wrongPayloadType, wrongBootstrapId, tooLarge, malformedEnvelope, invalidPayload, unknownKey, unsupportedSchema, noNetwork, unreachable, tls, timeout, cancelled or http.<status>. */
    val code: String? = null,
    /** wire: `serial`. Serial of the document, when one was read. */
    val serial: Long? = null,
)
