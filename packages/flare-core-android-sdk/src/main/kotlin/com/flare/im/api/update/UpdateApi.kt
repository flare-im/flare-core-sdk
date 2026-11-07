package com.flare.im.api.update

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
/** Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors. */
interface UpdateApi {
    /** getState maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.get_state`. */
    suspend fun getState(request: UpdateGetStateRequest): UpdateStatus
    /** check maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.check`. */
    suspend fun check(request: UpdateCheckRequest): UpdateStatus
    /** download maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.download`. */
    suspend fun download(request: UpdateDownloadRequest): UpdateStatus
    /** install maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.install`. */
    suspend fun install(): UpdateInstallPlan
    /** reportInstall maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.report_install`. */
    suspend fun reportInstall(request: UpdateReportInstallRequest): UpdateStatus
    /** defer maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.defer`. */
    suspend fun defer(): UpdateStatus
    /** skip maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.skip`. */
    suspend fun skip(request: UpdateSkipRequest): UpdateStatus
    /** markPrompted maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.mark_prompted`. */
    suspend fun markPrompted(request: UpdateMarkPromptedRequest): UpdateStatus
    /** setLocale maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.set_locale`. */
    suspend fun setLocale(request: UpdateSetLocaleRequest): UpdateStatus
    /** getResources maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.get_resources`. */
    suspend fun getResources(request: UpdateGetResourcesRequest): UpdateResources
}
