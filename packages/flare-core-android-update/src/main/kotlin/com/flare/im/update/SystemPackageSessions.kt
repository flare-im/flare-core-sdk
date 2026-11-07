package com.flare.im.update

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.selects.select
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Why a package could not be staged. The system refuses a session for want of room with a plain [IOException], so the
 * room is measured: "try again" would only lead back to the same refusal.
 */
internal fun stagingFailure(packageBytes: Long, allocatableBytes: Long?): String =
    if (allocatableBytes != null && allocatableBytes < packageBytes) {
        FlareUpdateErrorCodes.INSUFFICIENT_SPACE
    } else {
        FlareUpdateErrorCodes.INSTALL_FAILED
    }

/** What a [PackageInstaller] status means for the update. */
internal fun installResult(status: Int): FlareUpdateInstallResult = when (status) {
    PackageInstaller.STATUS_SUCCESS -> FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED)
    PackageInstaller.STATUS_FAILURE_ABORTED -> FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)
    PackageInstaller.STATUS_FAILURE_STORAGE -> FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSUFFICIENT_SPACE)
    else -> FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
}

/**
 * Sessions waiting for their end, by session id, with the page that asks the user to confirm each.
 *
 * Android does not let an app in the background start an activity, and it says nothing when it stops one: the
 * page stays closed and the session never ends. So a page the app cannot show waits here for the app to return.
 */
internal object FlarePendingInstalls {
    private class Waiting(val onEnd: (FlareUpdateInstallResult) -> Unit) {
        /** The page while it waits to open; opening it takes it away, so it opens once. */
        var page: (() -> Boolean)? = null
        var opened = false
    }

    private val waiting = ConcurrentHashMap<Int, Waiting>()

    fun await(sessionId: Int, onEnd: (FlareUpdateInstallResult) -> Unit) {
        waiting[sessionId] = Waiting(onEnd)
    }

    fun forget(sessionId: Int) {
        waiting.remove(sessionId)
    }

    fun complete(sessionId: Int, result: FlareUpdateInstallResult) {
        waiting.remove(sessionId)?.onEnd?.invoke(result)
    }

    /**
     * The system asks the user to confirm [sessionId] through [page], which says whether it could start. It opens
     * at once while the app is [onScreen] and otherwise on the next return. With nobody waiting, because the
     * process restarted meanwhile, opening it is all there is to do.
     */
    fun confirmation(sessionId: Int, onScreen: Boolean, page: () -> Boolean) {
        val install = waiting[sessionId]
        if (install == null) {
            page()
            return
        }
        synchronized(install) { install.page = page }
        if (onScreen) open(sessionId, install)
    }

    /**
     * The app is back on screen, so no page covers it. Opens the page that waited, and says whether one had already
     * opened: the user then left it unanswered, or answered it and the install is under way. Those two cannot be
     * told apart, so a page that opened never opens again: asking twice for an install already running is worse.
     */
    fun returned(sessionId: Int): Boolean {
        val install = waiting[sessionId] ?: return false
        val left = synchronized(install) { install.opened }
        open(sessionId, install)
        return left
    }

    /** Whether the user ever saw the page of [sessionId]. */
    fun pageOpened(sessionId: Int): Boolean =
        waiting[sessionId]?.let { install -> synchronized(install) { install.opened } } ?: false

    private fun open(sessionId: Int, install: Waiting) {
        val page = synchronized(install) {
            install.page.also { page ->
                install.page = null
                if (page != null) install.opened = true
            }
        } ?: return
        if (!page()) complete(sessionId, FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED))
    }
}

/** How long a committed session may go without an end before the update stops waiting for it. */
internal const val INSTALL_ANSWER_LIMIT_MS: Long = 5 * 60 * 1000L

/** How long the end may take once the user is back in the app with a page they already saw behind them. */
internal const val INSTALL_LEFT_LIMIT_MS: Long = 30 * 1000L

/**
 * Runs [commit] and waits for [sessionId] to end, or null when it does not end in time. The system reports no
 * end for a page nobody answers, and `update()` cannot end without one: the Kit shows `installing` with no way
 * out, and the controller takes a further tap for the update already running.
 */
internal suspend fun awaitInstallEnd(
    sessionId: Int,
    ended: Deferred<FlareUpdateInstallResult>,
    returns: FlareUpdateForegroundSource,
    answerLimitMs: Long = INSTALL_ANSWER_LIMIT_MS,
    leftLimitMs: Long = INSTALL_LEFT_LIMIT_MS,
    commit: () -> Unit,
): FlareUpdateInstallResult? {
    val back = Channel<Unit>(Channel.CONFLATED)
    val watching = returns.start { back.trySend(Unit) }
    try {
        commit()
        return withTimeoutOrNull(answerLimitMs) { endOrLeft(sessionId, ended, back, leftLimitMs) }
    } finally {
        runCatching { watching.close() }
    }
}

private suspend fun endOrLeft(
    sessionId: Int,
    ended: Deferred<FlareUpdateInstallResult>,
    back: Channel<Unit>,
    leftLimitMs: Long,
): FlareUpdateInstallResult? {
    while (true) {
        val result = select<FlareUpdateInstallResult?> {
            ended.onAwait { it }
            back.onReceive { null }
        }
        if (result != null) return result
        if (FlarePendingInstalls.returned(sessionId)) return withTimeoutOrNull(leftLimitMs) { ended.await() }
    }
}

/**
 * Says when the process resumes, which no system page in front of it allows: a resume means the app is what the
 * user sees. It starts from the next resume, not from the one a new observer is told about.
 */
internal class ProcessResumeSource : FlareUpdateForegroundSource {
    override fun start(onForeground: () -> Unit): AutoCloseable {
        val main = Handler(Looper.getMainLooper())
        var catchingUp = true
        val observer = object : DefaultLifecycleObserver {
            override fun onResume(owner: LifecycleOwner) {
                if (!catchingUp) onForeground()
            }
        }
        main.post {
            ProcessLifecycleOwner.get().lifecycle.addObserver(observer)
            catchingUp = false
        }
        return AutoCloseable { main.post { ProcessLifecycleOwner.get().lifecycle.removeObserver(observer) } }
    }
}

/**
 * Receives the status of a session. Declared in the manifest, not exported, and reached only
 * through this app's explicit PendingIntent, so no other app can feed it an intent to launch.
 * A status for a session nobody waits for (the process restarted meanwhile) still shows the
 * confirmation page and is otherwise dropped. The page of a session that is waited for goes through
 * [FlarePendingInstalls], which holds it while the app is in the background.
 */
class FlareUpdateInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val sessionId = intent.getIntExtra(EXTRA_FLARE_SESSION, NO_SESSION)
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status != PackageInstaller.STATUS_PENDING_USER_ACTION) {
            FlarePendingInstalls.complete(sessionId, installResult(status))
            return
        }
        val confirm = confirmIntent(intent)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (confirm == null) {
            FlarePendingInstalls.complete(
                sessionId,
                FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED),
            )
            return
        }
        // The page can open long after this receiver ended, so it does not keep the receiver's context.
        val app = context.applicationContext
        FlarePendingInstalls.confirmation(sessionId, onScreen()) {
            runCatching { app.startActivity(confirm) }.isSuccess
        }
    }

    private fun onScreen(): Boolean =
        ProcessLifecycleOwner.get().lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)

    private fun confirmIntent(intent: Intent): Intent? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        }

    internal companion object {
        const val EXTRA_FLARE_SESSION = "com.flare.im.update.extra.SESSION"
        const val NO_SESSION = -1
    }
}

/**
 * Installs through a [PackageInstaller] session. The system asks the user to confirm and, for an
 * app that has not been allowed to install, walks them through that permission first.
 */
internal class SystemPackageSessions(
    private val context: Context,
    private val io: CoroutineDispatcher = Dispatchers.IO,
    private val returns: FlareUpdateForegroundSource = ProcessResumeSource(),
) : FlarePackageSessions {
    override val installAllowed: Boolean
        get() = runCatching {
            context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
                .requestedPermissions
                ?.contains(Manifest.permission.REQUEST_INSTALL_PACKAGES) == true
        }.getOrDefault(false)

    override suspend fun install(plan: FlareUpdateInstallPlan.InstallPackage): FlareUpdateInstallResult {
        val installer = context.packageManager.packageInstaller
        val file = File(plan.path)
        val sessionId = try {
            withContext(io) { stage(installer, file) }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: IOException) {
            return FlareUpdateInstallResult.failed(stagingFailure(file.length(), allocatableBytes()))
        } catch (_: SecurityException) {
            return FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
        }
        return commit(installer, sessionId)
    }

    /** What the system would give an install now, caches it may clear included; null when it does not say. */
    private fun allocatableBytes(): Long? = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val storage = context.getSystemService(StorageManager::class.java)
            storage.getAllocatableBytes(storage.getUuidForPath(context.filesDir))
        } else {
            context.filesDir.usableSpace
        }
    }.getOrNull()

    /** Copies the package into a new session; sessions an earlier run left behind go first. */
    private fun stage(installer: PackageInstaller, file: File): Int {
        installer.mySessions
            .filter { it.appPackageName == context.packageName }
            .forEach { session -> runCatching { installer.abandonSession(session.sessionId) } }
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(file.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                setInstallReason(PackageManager.INSTALL_REASON_USER)
            }
        }
        val sessionId = installer.createSession(params)
        try {
            installer.openSession(sessionId).use { session ->
                FileInputStream(file).use { input ->
                    session.openWrite(PACKAGE_ENTRY, 0, file.length()).use { output ->
                        input.copyTo(output, COPY_BUFFER_BYTES)
                        session.fsync(output)
                    }
                }
            }
        } catch (failure: Throwable) {
            runCatching { installer.abandonSession(sessionId) }
            throw failure
        }
        return sessionId
    }

    private suspend fun commit(installer: PackageInstaller, sessionId: Int): FlareUpdateInstallResult {
        val ended = CompletableDeferred<FlareUpdateInstallResult>()
        FlarePendingInstalls.await(sessionId) { result -> ended.complete(result) }
        try {
            val result = awaitInstallEnd(sessionId, ended, returns) {
                installer.openSession(sessionId).use { session -> session.commit(statusSender(sessionId)) }
            }
            return result ?: unanswered(installer, sessionId)
        } catch (cancelled: CancellationException) {
            runCatching { installer.abandonSession(sessionId) }
            throw cancelled
        } catch (_: IOException) {
            return FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
        } catch (_: SecurityException) {
            return FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED)
        } finally {
            FlarePendingInstalls.forget(sessionId)
        }
    }

    /**
     * Nobody answered, which is not a failure: the file stays ready and the update is on offer again. A page the
     * user saw stays usable, and confirming it still installs; the next update drops the session otherwise. A page
     * that never opened has nothing left to reach the session, so the copy goes now.
     */
    private fun unanswered(installer: PackageInstaller, sessionId: Int): FlareUpdateInstallResult {
        if (!FlarePendingInstalls.pageOpened(sessionId)) runCatching { installer.abandonSession(sessionId) }
        return FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)
    }

    /** Mutable because the system fills in the status; explicit, so only our receiver gets it. */
    private fun statusSender(sessionId: Int): IntentSender {
        val intent = Intent(context, FlareUpdateInstallReceiver::class.java)
            .putExtra(FlareUpdateInstallReceiver.EXTRA_FLARE_SESSION, sessionId)
        val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(
            context,
            sessionId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or mutable,
        ).intentSender
    }

    private companion object {
        const val PACKAGE_ENTRY = "base.apk"
        const val COPY_BUFFER_BYTES = 64 * 1024
    }
}
