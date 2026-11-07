package com.flare.im.model.command

import com.flare.im.model.entity.AppState

/** GENERATED. Do not edit by hand. */
/** Foreground and background notification from the platform lifecycle. */
data class SetAppStateRequest(
    /** wire: `appState`. Current application state. */
    val appState: AppState,
)
