package com.flare.im.api.diagnostics

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
/** SDK version and FFI contract diagnostics. */
interface DiagnosticsApi {
    /** getSdkVersion maps to `flare_sdk_version` via `ffi-symbol`. Operation: `diagnostics.sdk_version`. */
    suspend fun getSdkVersion(): Map<String, Any?>
    /** getFfiContractVersion maps to `flare_sdk_ffi_contract_version` via `ffi-symbol`. Operation: `diagnostics.ffi_contract_version`. */
    suspend fun getFfiContractVersion(): Map<String, Any?>
    /** getDataRoot maps to `flare_sdk_data_root` via `ffi-symbol`. Operation: `diagnostics.data_root`. */
    suspend fun getDataRoot(): Map<String, Any?>
    /** getRuntimeHealth maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `diagnostics.runtime_health`. */
    suspend fun getRuntimeHealth(): RuntimeHealthResponse
}
