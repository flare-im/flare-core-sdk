package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** Whether the platform presents alerts itself while the app is in the background. */
data class SetBackgroundPresenterRequest(
    /** wire: `attached`. The platform push module posts local notifications for the engine while the app is in the background. */
    val attached: Boolean = false,
)
