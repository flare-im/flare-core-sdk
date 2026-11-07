package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.access.AccessApi
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
class DefaultAccessApi(
    private val bridge: NativeBridge,
) : AccessApi {

    override suspend fun getStatus(): AccessStatus {
        return accessStatusFromJson(invokeMap(bridge, NativeCallMap.ACCESS_GET_STATUS))
    }

    override suspend fun listAccessPoints(): List<AccessPointInfo> {
        return accessPointInfoListFromJson(bridge.invoke<Any?>(NativeCallMap.ACCESS_LIST_ACCESS_POINTS))
    }

    override suspend fun pin(request: AccessPinRequest): AccessPin {
        return accessPinFromJson(invokeMap(bridge, NativeCallMap.ACCESS_PIN, accessPinRequestToMap(request)))
    }

    override suspend fun unpin(): Unit {
        invokeUnit(bridge, NativeCallMap.ACCESS_UNPIN)
    }

    override suspend fun refresh(): AccessRefreshReport {
        return accessRefreshReportFromJson(invokeMap(bridge, NativeCallMap.ACCESS_REFRESH))
    }

    override suspend fun importRecovery(request: AccessImportRecoveryRequest): AccessRecoveryImport {
        return accessRecoveryImportFromJson(invokeMap(bridge, NativeCallMap.ACCESS_IMPORT_RECOVERY, accessImportRecoveryRequestToMap(request)))
    }

    override suspend fun exportDiagnostics(): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.ACCESS_EXPORT_DIAGNOSTICS)
    }
}
