package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** One background refresh the platform granted the app (iOS BGAppRefreshTask). */
data class BackgroundRefreshRequest(
    /** wire: `budgetMs`. Time the platform grants, in milliseconds; the engine uses at most 25000 of it. */
    val budgetMs: Int = 0,
)
