package com.flare.im.update

import android.content.Context
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

/** How an update ends that a store took over when [FlareUpdateInstaller.execute] returned `started`. */
enum class FlareUpdateHandoff(val wireValue: String) {
    NONE("none"),

    /** The update is downloaded and waits for a restart only the user may start. */
    RESTART_READY("restartReady"),
    FAILED("failed"),
    CANCELLED("cancelled"),
}

/**
 * Carries out an install plan. Platform capability only: the engine decides what to install and
 * whether it is trustworthy.
 */
interface FlareUpdateInstaller {
    /**
     * Runs [plan] to its end and says how it went. A store page that opened is `completed`; `started`
     * is for work that goes on in the background, whose end comes through [handoff]. An install that
     * replaces the running process never returns.
     */
    suspend fun execute(plan: FlareUpdateInstallPlan): FlareUpdateInstallResult

    /** False when the store says it has nothing for [release], so the user should not hear of it. */
    suspend fun canPrompt(release: FlareUpdateRelease): Boolean = true

    /** The progress of an update a store took over; stays `NONE` for installers without one. */
    val handoff: StateFlow<FlareUpdateHandoff> get() = noHandoff

    /** Finishes a `RESTART_READY` handoff. The user asked for it; the app restarts. */
    suspend fun completeHandoff(): FlareUpdateInstallResult = FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)

    companion object {
        /**
         * The installer for this device: stores through their detail page, packages through a
         * [android.content.pm.PackageInstaller] session. A build whose manifest does not declare
         * `REQUEST_INSTALL_PACKAGES`, as a store build must not, refuses package plans.
         */
        fun system(context: Context): FlareUpdateInstaller {
            val app = context.applicationContext ?: context
            return PlatformUpdateInstaller(
                verifier = FlareApkVerifier(PackageManagerApkInspector(app)),
                sessions = SystemPackageSessions(app),
                store = SystemStoreLauncher(app),
            )
        }
    }
}

private val noHandoff: StateFlow<FlareUpdateHandoff> = MutableStateFlow(FlareUpdateHandoff.NONE).asStateFlow()

/** Installs a package through a session; a test double replaces the system's. */
internal interface FlarePackageSessions {
    /** Whether this build may install packages at all. */
    val installAllowed: Boolean

    /** Hands the package to the system and waits for the end of the session. */
    suspend fun install(plan: FlareUpdateInstallPlan.InstallPackage): FlareUpdateInstallResult
}

/** Opens a store; false when nothing on the device can show it. */
internal fun interface FlareStoreLauncher {
    fun open(plan: FlareUpdateInstallPlan.OpenStore): Boolean
}

internal class PlatformUpdateInstaller(
    private val verifier: FlareApkVerifier,
    private val sessions: FlarePackageSessions,
    private val store: FlareStoreLauncher,
    private val io: CoroutineDispatcher = Dispatchers.IO,
) : FlareUpdateInstaller {
    override suspend fun execute(plan: FlareUpdateInstallPlan): FlareUpdateInstallResult = when (plan) {
        is FlareUpdateInstallPlan.OpenStore -> if (store.open(plan)) {
            FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED)
        } else {
            FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
        }
        is FlareUpdateInstallPlan.InstallPackage -> installPackage(plan)
        is FlareUpdateInstallPlan.Unsupported -> FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
    }

    private suspend fun installPackage(plan: FlareUpdateInstallPlan.InstallPackage): FlareUpdateInstallResult {
        if (!sessions.installAllowed) return FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
        val refused = withContext(io) { verifier.verify(plan) }
        if (refused != null) return FlareUpdateInstallResult.failed(refused)
        return sessions.install(plan)
    }
}
