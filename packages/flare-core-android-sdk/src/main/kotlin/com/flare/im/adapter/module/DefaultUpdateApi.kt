package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.update.UpdateApi
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
class DefaultUpdateApi(
    private val bridge: NativeBridge,
) : UpdateApi {

    override suspend fun getState(request: UpdateGetStateRequest): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_GET_STATE, updateGetStateRequestToMap(request)))
    }

    override suspend fun check(request: UpdateCheckRequest): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_CHECK, updateCheckRequestToMap(request)))
    }

    override suspend fun download(request: UpdateDownloadRequest): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_DOWNLOAD, updateDownloadRequestToMap(request)))
    }

    override suspend fun install(): UpdateInstallPlan {
        return updateInstallPlanFromJson(invokeMap(bridge, NativeCallMap.UPDATE_INSTALL))
    }

    override suspend fun reportInstall(request: UpdateReportInstallRequest): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_REPORT_INSTALL, updateReportInstallRequestToMap(request)))
    }

    override suspend fun defer(): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_DEFER))
    }

    override suspend fun skip(request: UpdateSkipRequest): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_SKIP, updateSkipRequestToMap(request)))
    }

    override suspend fun markPrompted(request: UpdateMarkPromptedRequest): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_MARK_PROMPTED, updateMarkPromptedRequestToMap(request)))
    }

    override suspend fun setLocale(request: UpdateSetLocaleRequest): UpdateStatus {
        return updateStatusFromJson(invokeMap(bridge, NativeCallMap.UPDATE_SET_LOCALE, updateSetLocaleRequestToMap(request)))
    }

    override suspend fun getResources(request: UpdateGetResourcesRequest): UpdateResources {
        return updateResourcesFromJson(invokeMap(bridge, NativeCallMap.UPDATE_GET_RESOURCES, updateGetResourcesRequestToMap(request)))
    }
}
