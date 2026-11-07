package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Result of importing a recovery link. */
data class AccessRecoveryImport(
    /** wire: `outcome`. adopted, unchanged (this link was already imported) or rejected. */
    val outcome: String = "",
    /** wire: `code`. Why a link was rejected: a code of AccessRefreshAttempt.code or developmentMode. Commonly rollback (the link is older than this device's manifest) or badSignature. */
    val code: String? = null,
    /** wire: `serial`. Directory serial after the import. */
    val serial: Long = 0L,
)
