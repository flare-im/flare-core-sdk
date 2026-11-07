package com.flare.im.update.play

import android.app.Activity
import android.content.Context
import com.flare.im.update.FlareUpdateErrorCodes
import com.flare.im.update.FlareUpdateHandoff
import com.flare.im.update.FlareUpdateInstallPlan
import com.flare.im.update.FlareUpdateInstallResult
import com.flare.im.update.FlareUpdateInstaller
import com.flare.im.update.FlareUpdateOutcome
import com.flare.im.update.FlareUpdateRelease
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** What Play says about this app's update. */
internal data class PlayUpdateSnapshot(
    /** An update is on offer, or an immediate flow started earlier is still running. */
    val available: Boolean,
    /** A flexible update finished downloading and waits for a restart. */
    val downloaded: Boolean,
    val immediateAllowed: Boolean,
    val flexibleAllowed: Boolean,
)

/** How the Play dialog ended. */
internal enum class PlayFlowResult { ACCEPTED, CANCELED, FAILED, NO_ACTIVITY }

/** The end of a flexible download. */
internal enum class PlayDownloadEnd { DOWNLOADED, FAILED, CANCELED }

/** The Play calls this installer makes; a test double replaces the real manager. */
internal interface PlayUpdateClient {
    suspend fun query(): PlayUpdateSnapshot

    /** Runs the immediate or flexible flow on a fresh update info: Play accepts each info once. */
    suspend fun start(immediate: Boolean): PlayFlowResult

    /** Installs a downloaded flexible update; the app restarts. */
    suspend fun completeUpdate()

    /** Reports how flexible downloads end, until the handle is closed. */
    fun listen(onEnd: (PlayDownloadEnd) -> Unit): AutoCloseable
}

/**
 * Updates through Play In-App Updates: a plan with `immediate` runs the immediate flow, any other
 * Play plan the flexible one. Plans for anything but Play, and Play plans Play cannot serve here
 * (no update it knows of, no activity on screen), go to [fallback], whose store intent opens the
 * Play page instead.
 *
 * A flexible download ends in [FlareUpdateHandoff.RESTART_READY]: the restart is the user's to start,
 * through the controller.
 */
class FlarePlayUpdateInstaller internal constructor(
    private val play: PlayUpdateClient,
    private val fallback: FlareUpdateInstaller,
) : FlareUpdateInstaller {
    /** [activity] gives the activity on screen, the one that hosts the Play dialog. */
    constructor(
        context: Context,
        activity: () -> Activity?,
        fallback: FlareUpdateInstaller = FlareUpdateInstaller.system(context),
    ) : this(AppUpdateManagerClient(context, activity), fallback)

    private val progress = MutableStateFlow(FlareUpdateHandoff.NONE)
    private val lock = Any()
    private var listening: AutoCloseable? = null

    override val handoff: StateFlow<FlareUpdateHandoff> = progress.asStateFlow()

    /**
     * Play decides what it can deliver to this device, so an update it does not report is not
     * mentioned to the user. Nor is one when Play cannot be asked (a device without it). A finished
     * download found here, left by an earlier run, asks for its restart.
     */
    override suspend fun canPrompt(release: FlareUpdateRelease): Boolean {
        val snapshot = snapshot() ?: return false
        if (snapshot.downloaded) progress.value = FlareUpdateHandoff.RESTART_READY
        return snapshot.available || snapshot.downloaded
    }

    override suspend fun execute(plan: FlareUpdateInstallPlan): FlareUpdateInstallResult {
        if (plan !is FlareUpdateInstallPlan.OpenStore || plan.store != PLAY_STORE) return fallback.execute(plan)
        val snapshot = snapshot() ?: return fallback.execute(plan)
        if (snapshot.downloaded) {
            progress.value = FlareUpdateHandoff.RESTART_READY
            return FlareUpdateInstallResult(FlareUpdateOutcome.STARTED)
        }
        val allowed = if (plan.immediate) snapshot.immediateAllowed else snapshot.flexibleAllowed
        if (!snapshot.available || !allowed) return fallback.execute(plan)

        progress.value = FlareUpdateHandoff.NONE
        if (!plan.immediate) listen()
        // Play can fail the flow instead of answering it. That is an install that failed: the engine stays in
        // `installing` until it hears so.
        val flow = try {
            play.start(plan.immediate)
        } catch (cancelled: CancellationException) {
            stopListening()
            throw cancelled
        } catch (_: Exception) {
            PlayFlowResult.FAILED
        }
        if (flow != PlayFlowResult.ACCEPTED) stopListening()
        return when (flow) {
            // The immediate flow is Play's to the end; a flexible download ends through the handoff.
            PlayFlowResult.ACCEPTED -> FlareUpdateInstallResult(
                if (plan.immediate) FlareUpdateOutcome.COMPLETED else FlareUpdateOutcome.STARTED,
            )
            PlayFlowResult.CANCELED -> FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)
            PlayFlowResult.FAILED -> FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
            PlayFlowResult.NO_ACTIVITY -> fallback.execute(plan)
        }
    }

    override suspend fun completeHandoff(): FlareUpdateInstallResult {
        if (progress.value != FlareUpdateHandoff.RESTART_READY) {
            return FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)
        }
        return try {
            play.completeUpdate()
            FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
        }
    }

    private suspend fun snapshot(): PlayUpdateSnapshot? = try {
        play.query()
    } catch (cancelled: CancellationException) {
        throw cancelled
    } catch (_: Exception) {
        null
    }

    private fun listen() {
        synchronized(lock) {
            if (listening != null) return
            listening = play.listen(::onDownloadEnd)
        }
    }

    private fun stopListening() {
        synchronized(lock) {
            listening?.close()
            listening = null
        }
    }

    private fun onDownloadEnd(end: PlayDownloadEnd) {
        stopListening()
        progress.value = when (end) {
            PlayDownloadEnd.DOWNLOADED -> FlareUpdateHandoff.RESTART_READY
            PlayDownloadEnd.FAILED -> FlareUpdateHandoff.FAILED
            PlayDownloadEnd.CANCELED -> FlareUpdateHandoff.CANCELLED
        }
    }

    private companion object {
        const val PLAY_STORE = "play"
    }
}
