package com.flare.im.update

import com.flare.im.api.FlareImClient
import com.flare.im.bridge.FlareSdkException
import com.flare.im.model.command.UpdateCheckRequest
import com.flare.im.model.command.UpdateDownloadRequest
import com.flare.im.model.command.UpdateGetResourcesRequest
import com.flare.im.model.command.UpdateGetStateRequest
import com.flare.im.model.command.UpdateMarkPromptedRequest
import com.flare.im.model.command.UpdateReportInstallRequest
import com.flare.im.model.command.UpdateSetLocaleRequest
import com.flare.im.model.command.UpdateSkipRequest
import com.flare.im.model.entity.UpdateInstallPlan
import com.flare.im.model.entity.UpdateResources
import com.flare.im.model.entity.UpdateStatus

/**
 * The update controller's port on a core client. [client] is asked for on every call, so a host that
 * brings a client up on demand, or replaces it, answers with the current one. The host forwards
 * `events.onUpdateState` of whichever client it runs to [receive].
 */
class ClientUpdateEngine(
    private val client: suspend () -> FlareImClient,
) : FlareUpdateEngine {
    @Volatile
    private var listener: ((Map<String, Any?>) -> Unit)? = null

    /** An `update://state` from the client. */
    fun receive(status: UpdateStatus) {
        listener?.invoke(status.toWire())
    }

    override fun subscribeState(onState: (Map<String, Any?>) -> Unit): AutoCloseable {
        listener = onState
        return AutoCloseable { listener = null }
    }

    override suspend fun dispatch(operation: String, params: Map<String, Any?>): Map<String, Any?> = try {
        route(operation, params)
    } catch (failure: FlareSdkException) {
        val code = FlareUpdateErrorCodes.named(failure.reason) ?: FlareUpdateErrorCodes.named(failure.message)
        throw if (code == null) failure else FlareUpdateException(code, failure.message, cause = failure)
    }

    private suspend fun route(operation: String, params: Map<String, Any?>): Map<String, Any?> {
        val update = client().update
        return when (operation) {
            FlareUpdateOperations.GET_STATE ->
                update.getState(UpdateGetStateRequest(foreground = params["foreground"] as? Boolean)).toWire()
            FlareUpdateOperations.CHECK -> update.check(UpdateCheckRequest(manual = params["manual"] == true)).toWire()
            FlareUpdateOperations.DOWNLOAD ->
                update.download(UpdateDownloadRequest(allowMetered = params["allowMetered"] == true)).toWire()
            FlareUpdateOperations.INSTALL -> update.install().toWire()
            FlareUpdateOperations.REPORT_INSTALL -> update.reportInstall(
                UpdateReportInstallRequest(outcome = params["outcome"].toString(), code = params["code"] as? String),
            ).toWire()
            FlareUpdateOperations.DEFER -> update.defer().toWire()
            FlareUpdateOperations.SKIP ->
                update.skip(UpdateSkipRequest(build = (params["build"] as Number).toLong())).toWire()
            FlareUpdateOperations.MARK_PROMPTED -> update.markPrompted(
                UpdateMarkPromptedRequest(build = (params["build"] as? Number)?.toLong(), form = params["form"].toString()),
            ).toWire()
            FlareUpdateOperations.SET_LOCALE ->
                update.setLocale(UpdateSetLocaleRequest(locale = params["locale"].toString())).toWire()
            FlareUpdateOperations.GET_RESOURCES -> update.getResources(UpdateGetResourcesRequest()).toWire()
            else -> throw IllegalArgumentException("not an update route: $operation")
        }
    }
}

/** The status as the port speaks it: the wire's field names. */
internal fun UpdateStatus.toWire(): Map<String, Any?> = mapOf(
    "state" to state,
    "current" to mapOf(
        "version" to current.version,
        "build" to current.build,
        "channel" to current.channel,
        "distribution" to current.distribution,
    ),
    "release" to release?.let {
        mapOf(
            "releaseId" to it.releaseId,
            "version" to it.version,
            "build" to it.build,
            "notes" to it.notes,
            "sizeBytes" to it.sizeBytes,
            "mandatory" to it.mandatory,
            "recommended" to it.recommended,
            "kind" to it.kind,
        )
    },
    "progress" to progress?.let { mapOf("received" to it.received, "total" to it.total) },
    "prompt" to prompt,
    "blockUi" to blockUi,
    "readOnly" to readOnly,
    "blockReason" to blockReason,
    "lastCheckedAt" to lastCheckedAt,
    "error" to error?.let {
        mapOf("code" to it.code, "retryable" to it.retryable, "fallbackUrl" to it.fallbackUrl)
    },
)

/** The packs as the port speaks them: the wire's field names. */
internal fun UpdateResources.toWire(): Map<String, Any?> = mapOf(
    "packs" to packs.map { pack ->
        mapOf(
            "id" to pack.id,
            "kind" to pack.kind,
            "packVersion" to pack.packVersion,
            "contentJson" to pack.contentJson,
        )
    },
)

/** The fields of a plan this platform can carry out; the web and desktop ones never reach it. */
internal fun UpdateInstallPlan.toWire(): Map<String, Any?> = mapOf(
    "kind" to kind,
    "store" to store,
    "url" to url,
    "packageName" to packageName,
    "appId" to appId,
    "immediate" to immediate,
    "path" to path,
    "sha256" to sha256,
    "signingCertSha256" to signingCertSha256,
    "build" to build,
    "sizeBytes" to sizeBytes,
)
