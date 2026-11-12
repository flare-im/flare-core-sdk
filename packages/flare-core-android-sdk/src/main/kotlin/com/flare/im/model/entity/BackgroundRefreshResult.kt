package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** How a background refresh ended. */
data class BackgroundRefreshResult(
    /** wire: `completed`. The link came up and the incremental sync finished within the budget. False when the budget ran out or no session could connect. */
    val completed: Boolean = false,
)
