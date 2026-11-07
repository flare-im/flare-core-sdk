package com.flare.im.api.access

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
/** Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page. */
interface AccessApi {
    /** getStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.get_status`. */
    suspend fun getStatus(): AccessStatus
    /** listAccessPoints maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.list_access_points`. */
    suspend fun listAccessPoints(): List<AccessPointInfo>
    /** pin maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.pin`. */
    suspend fun pin(request: AccessPinRequest): AccessPin
    /** unpin maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.unpin`. */
    suspend fun unpin(): Unit
    /** refresh maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.refresh`. */
    suspend fun refresh(): AccessRefreshReport
    /** importRecovery maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.import_recovery`. */
    suspend fun importRecovery(request: AccessImportRecoveryRequest): AccessRecoveryImport
    /** exportDiagnostics maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `access.export_diagnostics`. */
    suspend fun exportDiagnostics(): Map<String, Any?>
}
