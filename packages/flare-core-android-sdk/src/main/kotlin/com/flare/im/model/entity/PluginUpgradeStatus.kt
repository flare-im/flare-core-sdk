package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Whether an update reaching a plugin's minimum build is offered to this device. */
data class PluginUpgradeStatus(
    /** wire: `available`. A release at or above the floor is offered. */
    val available: Boolean = false,
    /** wire: `build`. That release's build, when available. */
    val build: Long? = null,
)
