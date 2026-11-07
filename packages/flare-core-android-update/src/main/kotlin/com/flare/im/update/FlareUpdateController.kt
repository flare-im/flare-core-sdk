package com.flare.im.update

import android.os.Handler
import android.os.Looper
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import java.util.logging.Logger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private val log: Logger = Logger.getLogger("FlareUpdate")

private fun logFailure(failure: Throwable) {
    log.warning("update center: ${failure.javaClass.simpleName}")
}

/**
 * The engine as the controller needs it. It references no SDK, so a host wires in whichever engine
 * it runs: the core client or its own C ABI.
 */
interface FlareUpdateEngine {
    /**
     * Calls an `update.*` route ([FlareUpdateOperations]) and returns its decoded JSON object.
     * A refusal is a [FlareUpdateException] carrying the error code.
     */
    suspend fun dispatch(operation: String, params: Map<String, Any?> = emptyMap()): Map<String, Any?>

    /** Delivers every `update://state` payload, on any thread, until the handle is closed. */
    fun subscribeState(onState: (Map<String, Any?>) -> Unit): AutoCloseable
}

/** Says when the app returns to the foreground, until the handle is closed. */
fun interface FlareUpdateForegroundSource {
    fun start(onForeground: () -> Unit): AutoCloseable
}

/** The foreground from `ProcessLifecycleOwner`. */
class ProcessForegroundSource : FlareUpdateForegroundSource {
    override fun start(onForeground: () -> Unit): AutoCloseable {
        val main = Handler(Looper.getMainLooper())
        val observer = object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) = onForeground()
        }
        main.post { ProcessLifecycleOwner.get().lifecycle.addObserver(observer) }
        return AutoCloseable { main.post { ProcessLifecycleOwner.get().lifecycle.removeObserver(observer) } }
    }
}

/**
 * Binds an app to the update center. The engine decides everything; this runs the steps the platform
 * has to take and keeps [state] current, so an app hands [state] to the Kit and connects the Kit's
 * callbacks to the methods here, with no flow of its own.
 *
 * Events only reach the host while there is a session, so they are not the only source of [state]:
 * the status is read on [install], on returning to the foreground, on [onLoginSucceeded] and on
 * [onLoginFailed], every route's return value is taken as the latest status, and while the state is
 * `checking`, `downloading` or `verifying` a silence of [POLL_INTERVAL_MS] triggers a read. That read is
 * also how a check ends: `update.check` answers at once with `checking` and runs in the background.
 *
 * The engine maintains `prompt` and `readOnly`, so an app binds them directly. [state] only adds what
 * the engine cannot know: a store that has nothing to offer, a store update waiting for a restart.
 * Apart from [refresh], methods report a failure through `state.error` rather than by throwing.
 */
class FlareUpdateController(
    private val engine: FlareUpdateEngine,
    private val installer: FlareUpdateInstaller,
    private val foreground: FlareUpdateForegroundSource = ProcessForegroundSource(),
    /** Called when a background read or report fails; by default the kind of failure goes to the log. */
    private val onError: (Throwable) -> Unit = ::logFailure,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
) {
    /** What the store said for a build; [open] stays false until it has answered. */
    private data class StoreAnswer(val build: Long, val open: Boolean)

    private val lock = Any()
    private val shown = MutableStateFlow<FlareUpdateStatus?>(null)

    /** The latest status for the UI; null until the first read. */
    val state: StateFlow<FlareUpdateStatus?> = shown.asStateFlow()

    private var engineStatus: FlareUpdateStatus? = null
    private var revision = 0L
    private var pollJob: Job? = null
    private var handoffJob: Job? = null
    private var stateSubscription: AutoCloseable? = null
    private var foregroundSubscription: AutoCloseable? = null
    private var installed = false
    private var disposed = false
    private var updating = false

    private var localError: FlareUpdateError? = null
    private var sentToBackground = false
    private var pendingLocale: String? = null
    private var sendingLocale = false
    private var storeAnswer: StoreAnswer? = null

    /** Starts listening and reads the current status. Calling it again does nothing. */
    fun install(): FlareUpdateController {
        synchronized(lock) {
            if (installed || disposed) return this
            installed = true
            handoffJob = scope.launch { installer.handoff.collect { onHandoff(it) } }
        }
        val events = engine.subscribeState(::onEvent)
        val returns = foreground.start(::onForeground)
        synchronized(lock) {
            stateSubscription = events
            foregroundSubscription = returns
        }
        readInBackground()
        return this
    }

    /** Runs [action] past the screen that asked for it: a prompt closing must not cancel the update it started. */
    fun launch(action: suspend FlareUpdateController.() -> Unit) {
        scope.launch { action() }
    }

    /** Stops listening; later statuses are dropped. */
    fun dispose() {
        val subscriptions = synchronized(lock) {
            if (disposed) return
            disposed = true
            pollJob?.cancel()
            handoffJob?.cancel()
            listOfNotNull(stateSubscription, foregroundSubscription)
        }
        subscriptions.forEach { subscription -> runCatching { subscription.close() } }
    }

    /** Reads the status again; events do not arrive before login, so call this when login succeeds. */
    fun onLoginSucceeded() {
        readInBackground()
    }

    /** Reads the status again: a sign-in refused with `UPGRADE_REQUIRED` leaves no session, so no event says so. */
    fun onLoginFailed() {
        readInBackground()
    }

    /** Reads the current status from the engine; a failed read throws. */
    suspend fun refresh(): FlareUpdateStatus = call(FlareUpdateOperations.GET_STATE)

    /**
     * Tells the engine the language the app shows: the release notes and [FlareUpdateStatus.blockReason]
     * follow it at once. Call it when the app reads its language at start and when the person changes it.
     *
     * Before `init` the engine refuses a language and does not keep it, so the value waits here for the first
     * status, which only comes once the engine is up. One the engine refused goes again with the next status. A
     * failure is no step of the update: it goes to [onError], not to `state.error`.
     */
    suspend fun setLocale(locale: String) {
        val engineUp = synchronized(lock) {
            pendingLocale = locale
            engineStatus != null
        }
        if (engineUp) sendLocale()
    }

    /**
     * The resource packs of this run, in `id` order. The engine reads them once when it starts, so what a check
     * brings or withdraws shows on the next start and this answers the same all run. Packs are no step of the
     * update and nothing waits for them: a failure goes to [onError], not to `state.error`, and answers no packs,
     * which leaves the app on its built-in resources.
     */
    suspend fun loadResources(): List<FlareUpdateResourcePack> {
        var packs = emptyList<FlareUpdateResourcePack>()
        quietly { packs = FlareUpdateCodec.resourcePacks(engine.dispatch(FlareUpdateOperations.GET_RESOURCES)) }
        return packs
    }

    /**
     * Starts a check for a release; [manual] is not held back by the check interval. The engine answers at
     * once, with `checking` when a check runs, so the result is not what this returns: it reaches [state] by
     * event or by the poll that state starts.
     */
    suspend fun check(manual: Boolean = true): FlareUpdateStatus? =
        userAction(FlareUpdateErrorCodes.MANIFEST_UNAVAILABLE) {
            call(FlareUpdateOperations.CHECK, mapOf("manual" to manual))
        }

    /**
     * Runs the update: download when the release needs one, then `update.install`, the plan, and
     * `update.report_install`. When the last error asks for confirmation on a metered network, calling
     * this again is that confirmation. A store update waiting for a restart restarts now.
     */
    suspend fun update(): FlareUpdateStatus? {
        val allowMetered = synchronized(lock) {
            sentToBackground = false
            if (updating) return shown.value
            updating = true
            shown.value?.error?.code == FlareUpdateErrorCodes.METERED_CONFIRMATION_REQUIRED
        }
        return try {
            userAction(FlareUpdateErrorCodes.INSTALL_FAILED) { runUpdate(allowMetered) }
        } finally {
            synchronized(lock) { updating = false }
        }
    }

    /**
     * Puts the prompt aside through `update.defer`; what that means is the engine's to decide. A
     * download put aside goes on, and when it ends it waits for the user: an update they walked away
     * from does not open the installer by itself.
     */
    suspend fun later(): FlareUpdateStatus? {
        synchronized(lock) {
            if (engineStatus?.state in DOWNLOAD_STATES) sentToBackground = true
        }
        return userAction { call(FlareUpdateOperations.DEFER) }
    }

    /** Skips the optional release on offer; the engine refuses a forced one. */
    suspend fun skip(): FlareUpdateStatus? {
        val build = synchronized(lock) { engineStatus?.release?.build } ?: return shown.value
        return userAction { call(FlareUpdateOperations.SKIP, mapOf("build" to build)) }
    }

    /** Tells the engine the prompt in [state] is on screen, which is what its frequency rules count. */
    suspend fun markPrompted(): FlareUpdateStatus? {
        val status = shown.value ?: return null
        if (!status.prompt.interrupts) return status
        val params = buildMap {
            // A forced prompt can stand before the manifest arrives, with no release to name.
            status.release?.let { put("build", it.build) }
            put("form", status.prompt.wireValue)
        }
        return userAction { call(FlareUpdateOperations.MARK_PROMPTED, params) }
    }

    /**
     * Puts a forced update aside to browse read only, through `update.defer`: the engine folds the
     * prompt away, sets `readOnly` and asks again on the next start or return to the foreground. Does
     * nothing when [FlareUpdateStatus.canContinueReadOnly] is false.
     */
    suspend fun continueReadOnly(): FlareUpdateStatus? {
        val allowed = synchronized(lock) { engineStatus?.canContinueReadOnly == true }
        return if (allowed) later() else shown.value
    }

    /** Opens the fallback link of the last error; false when there is none or nothing can open it. */
    suspend fun openFallback(): Boolean {
        val url = shown.value?.error?.fallbackUrl ?: return false
        val plan = FlareUpdateInstallPlan.OpenStore(FlareUpdateInstallPlan.OpenStore.WEBSITE, url = url)
        return installer.execute(plan).outcome == FlareUpdateOutcome.COMPLETED
    }

    /** One call at a time, so two quick changes cannot arrive out of order. */
    private suspend fun sendLocale() {
        val locale = synchronized(lock) {
            if (sendingLocale) return
            val waiting = pendingLocale ?: return
            sendingLocale = true
            waiting
        }
        try {
            quietly {
                call(FlareUpdateOperations.SET_LOCALE, mapOf("locale" to locale))
                synchronized(lock) { pendingLocale = pendingLocale.takeUnless { it == locale } }
            }
        } finally {
            synchronized(lock) { sendingLocale = false }
        }
        val newer = synchronized(lock) { pendingLocale?.takeIf { it != locale } }
        if (newer != null) sendLocale()
    }

    private suspend fun runUpdate(allowMetered: Boolean): FlareUpdateStatus? {
        if (installer.handoff.value == FlareUpdateHandoff.RESTART_READY) return report(installer.completeHandoff())
        var status = synchronized(lock) { engineStatus } ?: call(FlareUpdateOperations.GET_STATE)
        // Refused by the server before any manifest arrived: find the release instead of doing nothing. The check
        // runs in the background; the poll of `checking` brings the release to the prompt, which then offers it.
        val release = status.release ?: return if (status.state == FlareUpdateState.REQUIRED) {
            call(FlareUpdateOperations.CHECK, mapOf("manual" to true))
        } else {
            status
        }
        if (release.kind == FlareUpdateKind.PACKAGE && status.state != FlareUpdateState.READY_TO_INSTALL) {
            if (status.state !in DOWNLOAD_STATES) {
                status = call(FlareUpdateOperations.DOWNLOAD, mapOf("allowMetered" to allowMetered))
            }
            status = downloaded(status)
            val putAside = synchronized(lock) { sentToBackground }
            if (status.state != FlareUpdateState.READY_TO_INSTALL || putAside) return status
        }
        val plan = FlareUpdateCodec.plan(engine.dispatch(FlareUpdateOperations.INSTALL))
        // The route returns the plan, not a status; the state moved to `installing`.
        call(FlareUpdateOperations.GET_STATE)
        return report(installer.execute(plan))
    }

    private suspend fun downloaded(status: FlareUpdateStatus): FlareUpdateStatus =
        if (status.state !in DOWNLOAD_STATES) {
            status
        } else {
            shown.filterNotNull().first { it.state !in DOWNLOAD_STATES }
        }

    private suspend fun report(result: FlareUpdateInstallResult): FlareUpdateStatus =
        call(FlareUpdateOperations.REPORT_INSTALL, FlareUpdateCodec.reportParams(result))

    private suspend fun call(operation: String, params: Map<String, Any?> = emptyMap()): FlareUpdateStatus =
        adopt(FlareUpdateCodec.status(engine.dispatch(operation, params)))

    /**
     * A step the user asked for: an earlier failure no longer stands, and a new one reaches `state.error`
     * with the engine's code, or [fallback] when the failure carries none.
     */
    private suspend fun userAction(
        fallback: String? = null,
        action: suspend () -> FlareUpdateStatus?,
    ): FlareUpdateStatus? {
        synchronized(lock) { localError = null }
        return try {
            action()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            onError(failure)
            val refused = failure as? FlareUpdateException
            val code = refused?.code ?: fallback
            if (code != null) {
                synchronized(lock) {
                    localError = FlareUpdateError(code, refused?.retryable ?: true, refused?.fallbackUrl)
                    publish()
                }
            }
            // The engine recorded a refusal with what the exception cannot carry: retry and the fallback link.
            if (refused != null) quietly { refresh() }
            shown.value
        }
    }

    private fun onEvent(payload: Map<String, Any?>) {
        val status = try {
            FlareUpdateCodec.status(payload)
        } catch (malformed: IllegalArgumentException) {
            onError(malformed)
            return
        }
        adopt(status)
    }

    private fun onForeground() {
        synchronized(lock) {
            // The store may have caught up with the release in the meantime.
            storeAnswer = null
        }
        // Says so itself: `lifecycle.set_app_state` may arrive after this read, and what is due on a return would
        // then be missed until the next one.
        scope.launch { quietly { call(FlareUpdateOperations.GET_STATE, mapOf("foreground" to true)) } }
    }

    private suspend fun onHandoff(handoff: FlareUpdateHandoff) {
        synchronized(lock) { publish() }
        val result = when (handoff) {
            FlareUpdateHandoff.FAILED -> FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
            FlareUpdateHandoff.CANCELLED -> FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)
            FlareUpdateHandoff.NONE, FlareUpdateHandoff.RESTART_READY -> return
        }
        quietly { report(result) }
    }

    private fun readInBackground() {
        scope.launch { quietly { refresh() } }
    }

    private suspend fun quietly(action: suspend () -> Unit) {
        try {
            action()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Throwable) {
            onError(failure)
        }
    }

    /** Takes [status] as the latest word from the engine and returns what the UI now shows. */
    private fun adopt(status: FlareUpdateStatus): FlareUpdateStatus {
        var unanswered: FlareUpdateRelease? = null
        var localeWaits = false
        val result = synchronized(lock) {
            if (disposed) return status
            engineStatus = status
            revision += 1
            unanswered = releaseToAskTheStoreAbout(status)
            localeWaits = pendingLocale != null && !sendingLocale
            armPoll(status)
            publish()
            shown.value ?: status
        }
        unanswered?.let(::askTheStore)
        if (localeWaits) scope.launch { sendLocale() }
        return result
    }

    /** Any status restarts the wait, so a poll only runs after a real silence. */
    private fun armPoll(status: FlareUpdateStatus) {
        pollJob?.cancel()
        pollJob = null
        if (status.state !in POLLED_STATES) return
        val seen = revision
        pollJob = scope.launch {
            delay(POLL_INTERVAL_MS)
            quietly {
                val polled = FlareUpdateCodec.status(engine.dispatch(FlareUpdateOperations.GET_STATE))
                // A status that arrived while this read was out is newer than what it brings back.
                val current = synchronized(lock) { revision == seen }
                if (current) adopt(polled)
            }
        }
    }

    private fun releaseToAskTheStoreAbout(status: FlareUpdateStatus): FlareUpdateRelease? {
        val release = status.release ?: return null
        if (!isStoreGated(release) || storeAnswer?.build == release.build) return null
        storeAnswer = StoreAnswer(release.build, open = false)
        return release
    }

    private fun askTheStore(release: FlareUpdateRelease) {
        scope.launch {
            val open = try {
                installer.canPrompt(release)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Throwable) {
                onError(failure)
                false
            }
            synchronized(lock) {
                if (storeAnswer?.build == release.build) storeAnswer = StoreAnswer(release.build, open)
                publish()
            }
        }
    }

    /**
     * A forced release is never gated: the server is already refusing this build, so the prompt is
     * the user's only explanation and the store page their only way forward.
     */
    private fun isStoreGated(release: FlareUpdateRelease): Boolean =
        release.kind == FlareUpdateKind.STORE && !release.mandatory

    /** Call with [lock] held. */
    private fun publish() {
        engineStatus?.let { shown.value = present(it) }
    }

    private fun present(status: FlareUpdateStatus): FlareUpdateStatus {
        var result = status
        if (result.error == null) localError?.let { result = result.copy(error = it) }
        val release = status.release
        if (release != null && installer.handoff.value == FlareUpdateHandoff.RESTART_READY) {
            result = result.copy(state = FlareUpdateState.READY_TO_INSTALL)
        } else if (release != null && isStoreGated(release) && storeAnswer?.open != true) {
            result = result.copy(prompt = FlareUpdatePromptForm.NONE)
        }
        return result
    }

    companion object {
        /** How long a running operation may stay silent before the status is read. */
        const val POLL_INTERVAL_MS: Long = 500L

        private val DOWNLOAD_STATES = setOf(FlareUpdateState.DOWNLOADING, FlareUpdateState.VERIFYING)
        private val POLLED_STATES = DOWNLOAD_STATES + FlareUpdateState.CHECKING
    }
}
