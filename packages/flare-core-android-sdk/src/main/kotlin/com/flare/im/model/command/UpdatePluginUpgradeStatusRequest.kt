package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** A plugin's minimum build to reach. */
data class UpdatePluginUpgradeStatusRequest(
    /** wire: `minBuild`. The placeholder's minBuild; absent asks for any build newer than this one. */
    val minBuild: Long? = null,
)
