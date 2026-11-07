package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** Checks for an update. */
data class UpdateCheckRequest(
    /** wire: `manual`. The user asked: no frequency limit, and a failure lands in UpdateStatus.error. */
    val manual: Boolean = false,
)
