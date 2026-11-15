package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.notification.NotificationApi
import com.flare.im.callback.*
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallMap
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
class DefaultNotificationApi(
    private val bridge: NativeBridge,
) : NotificationApi {

    override suspend fun setFocus(request: SetNotificationFocusRequest): Unit {
        invokeUnit(bridge, NativeCallMap.NOTIFICATION_SET_FOCUS, setNotificationFocusRequestToMap(request))
    }

    override suspend fun getSettings(): UserNotificationSettings {
        return userNotificationSettingsFromJson(invokeMap(bridge, NativeCallMap.NOTIFICATION_GET_SETTINGS))
    }

    override suspend fun updateSettings(request: UpdateUserNotificationSettingsRequest): UserNotificationSettings {
        return userNotificationSettingsFromJson(invokeMap(bridge, NativeCallMap.NOTIFICATION_UPDATE_SETTINGS, updateUserNotificationSettingsRequestToMap(request)))
    }

    override suspend fun setBackgroundPresenter(request: SetBackgroundPresenterRequest): Unit {
        invokeUnit(bridge, NativeCallMap.NOTIFICATION_SET_BACKGROUND_PRESENTER, setBackgroundPresenterRequestToMap(request))
    }

    override suspend fun setSnapshotDirectory(request: SetNotificationSnapshotDirectoryRequest): Unit {
        invokeUnit(bridge, NativeCallMap.NOTIFICATION_SET_SNAPSHOT_DIRECTORY, setNotificationSnapshotDirectoryRequestToMap(request))
    }

    override suspend fun backgroundRefresh(request: BackgroundRefreshRequest): BackgroundRefreshResult {
        return backgroundRefreshResultFromJson(invokeMap(bridge, NativeCallMap.NOTIFICATION_BACKGROUND_REFRESH, backgroundRefreshRequestToMap(request)))
    }
}
