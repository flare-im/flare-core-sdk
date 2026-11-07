package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Progress of the periodic manifest refresh. */
data class AccessRefreshStatus(
    /** wire: `lastAttemptAtMs`. When the last round ran, Unix milliseconds. */
    val lastAttemptAtMs: Long? = null,
    /** wire: `lastSuccessAtMs`. When a source last gave a trusted answer, Unix milliseconds. */
    val lastSuccessAtMs: Long? = null,
    /** wire: `lastOutcome`. Outcome of the last round: adopted, upToDate, oldValues or failed; absent before the first round. */
    val lastOutcome: String? = null,
    /** wire: `nextAtMs`. When the next round runs, Unix milliseconds; absent while recovering without a network. */
    val nextAtMs: Long? = null,
)
