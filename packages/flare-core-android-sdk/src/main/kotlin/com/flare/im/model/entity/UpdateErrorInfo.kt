package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Why the last update action did not go through. */
data class UpdateErrorInfo(
    /** wire: `code`. update.* code. */
    val code: String = "",
    /** wire: `retryable`. Retrying can help. */
    val retryable: Boolean = false,
    /** wire: `fallbackUrl`. Page to send the user to; absent on the web. */
    val fallbackUrl: String? = null,
)
