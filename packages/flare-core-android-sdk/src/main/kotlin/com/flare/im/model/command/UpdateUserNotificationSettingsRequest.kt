package com.flare.im.model.command

import com.flare.im.model.entity.MultiDeviceAlertPolicy
import com.flare.im.model.entity.NotificationPreview
import com.flare.im.model.entity.QuietHours

/** GENERATED. Do not edit by hand. */
/** A partial update of the user's notification settings: items left out keep their value; at least one item must be given. */
data class UpdateUserNotificationSettingsRequest(
    /** wire: `baseSettingsVersion`. The settingsVersion the change is based on; 0 skips the check. When the stored settings changed in the meantime the whole update is rejected: read them again and retry. */
    val baseSettingsVersion: Long = 0L,
    /** wire: `clearQuietHours`. Remove the do-not-disturb hours. Rejected together with quietHours. */
    val clearQuietHours: Boolean = false,
    /** wire: `multiDevice`. New multi-device policy. */
    val multiDevice: MultiDeviceAlertPolicy? = null,
    /** wire: `preview`. New preview mode. */
    val preview: NotificationPreview? = null,
    /** wire: `quietHours`. New do-not-disturb hours, replacing the old ones. */
    val quietHours: QuietHours? = null,
)
