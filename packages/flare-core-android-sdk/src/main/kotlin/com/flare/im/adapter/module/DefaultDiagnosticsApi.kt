package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.diagnostics.DiagnosticsApi
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
class DefaultDiagnosticsApi(
    private val bridge: NativeBridge,
) : DiagnosticsApi {

    override suspend fun getSdkVersion(): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.DIAGNOSTICS_SDK_VERSION)
    }

    override suspend fun getFfiContractVersion(): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.DIAGNOSTICS_FFI_CONTRACT_VERSION)
    }

    override suspend fun getDataRoot(): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.DIAGNOSTICS_DATA_ROOT)
    }

    override suspend fun getRuntimeHealth(): RuntimeHealthResponse {
        return runtimeHealthResponseFromJson(invokeMap(bridge, NativeCallMap.DIAGNOSTICS_RUNTIME_HEALTH))
    }
}
