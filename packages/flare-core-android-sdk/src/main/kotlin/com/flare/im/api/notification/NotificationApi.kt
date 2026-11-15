package com.flare.im.api.notification

import com.flare.im.callback.*
import com.flare.im.listener.*
import com.flare.im.model.catalog.*
import com.flare.im.model.command.*
import com.flare.im.model.command.message.*
import com.flare.im.model.command.message.build.*
import com.flare.im.model.common.enums.*
import com.flare.im.model.common.error.*
import com.flare.im.model.content.*
import com.flare.im.model.entity.*
import com.flare.im.model.event.*
import com.flare.im.model.event.access.*
import com.flare.im.model.event.connection.*
import com.flare.im.model.event.conversation.*
import com.flare.im.model.event.lifecycle.*
import com.flare.im.model.event.message.*
import com.flare.im.model.event.plugin.*
import com.flare.im.model.event.presence.*
import com.flare.im.model.event.progress.*
import com.flare.im.model.event.sync.*
import com.flare.im.model.media.*
import com.flare.im.model.query.*
import com.flare.im.model.response.*

/** GENERATED. Do not edit by hand. */
/** Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events. */
interface NotificationApi {
    /** setFocus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.set_focus`. */
    suspend fun setFocus(request: SetNotificationFocusRequest): Unit
    /** getSettings maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.get_settings`. */
    suspend fun getSettings(): UserNotificationSettings
    /** updateSettings maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.update_settings`. */
    suspend fun updateSettings(request: UpdateUserNotificationSettingsRequest): UserNotificationSettings
    /** setBackgroundPresenter maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.set_background_presenter`. */
    suspend fun setBackgroundPresenter(request: SetBackgroundPresenterRequest): Unit
    /** setSnapshotDirectory maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.set_snapshot_directory`. */
    suspend fun setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Unit
    /** backgroundRefresh maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `notification.background_refresh`. */
    suspend fun backgroundRefresh(request: BackgroundRefreshRequest): BackgroundRefreshResult
}
