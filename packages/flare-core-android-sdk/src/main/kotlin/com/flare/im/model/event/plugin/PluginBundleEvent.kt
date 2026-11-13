package com.flare.im.model.event.plugin

/** GENERATED. Do not edit by hand. */
/** Something for an open web bundle page. */
data class PluginBundleEvent(
    /** wire: `sessionId`. The page's session (pluginBundleOpen). */
    val sessionId: String = "",
    /** wire: `envelope`. A bridge event to post to the page as it is: catalog.changed, entity.state, lifecycle.revoked. */
    val envelope: String? = null,
    /** wire: `close`. Close the page: withdrawn, suspended, disabled, replaced, evicted or signedOut. */
    val close: String? = null,
)
