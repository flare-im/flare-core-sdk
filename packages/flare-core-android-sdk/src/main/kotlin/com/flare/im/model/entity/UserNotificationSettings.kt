package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** The user's notification settings, shared by all of the user's devices. */
data class UserNotificationSettings(
    /** wire: `multiDevice`. What a phone does while another device of the user is in use. */
    val multiDevice: MultiDeviceAlertPolicy,
    /** wire: `preview`. How much a notification shows. */
    val preview: NotificationPreview,
    /** wire: `quietHours`. Do-not-disturb hours; absent when the user has none. */
    val quietHours: QuietHours? = null,
    /** wire: `settingsVersion`. Version of the settings; 0 when the user never changed them. Pass it back as baseSettingsVersion so a concurrent change elsewhere is not overwritten. */
    val settingsVersion: Long = 0L,
)
