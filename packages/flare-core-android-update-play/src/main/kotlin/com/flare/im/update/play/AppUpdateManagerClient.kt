package com.flare.im.update.play

import android.app.Activity
import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/** [PlayUpdateClient] on Play's [AppUpdateManager]. */
internal class AppUpdateManagerClient(
    context: Context,
    private val activity: () -> Activity?,
) : PlayUpdateClient {
    private val manager: AppUpdateManager = AppUpdateManagerFactory.create(context.applicationContext ?: context)

    override suspend fun query(): PlayUpdateSnapshot {
        val info = manager.appUpdateInfo.await()
        return PlayUpdateSnapshot(
            available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ||
                info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS,
            downloaded = info.installStatus() == InstallStatus.DOWNLOADED,
            immediateAllowed = isAllowed(info, AppUpdateType.IMMEDIATE),
            flexibleAllowed = isAllowed(info, AppUpdateType.FLEXIBLE),
        )
    }

    override suspend fun start(immediate: Boolean): PlayFlowResult {
        val host = activity() ?: return PlayFlowResult.NO_ACTIVITY
        val type = if (immediate) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
        val info = manager.appUpdateInfo.await()
        return when (manager.startUpdateFlow(info, host, AppUpdateOptions.defaultOptions(type)).await()) {
            Activity.RESULT_OK -> PlayFlowResult.ACCEPTED
            Activity.RESULT_CANCELED -> PlayFlowResult.CANCELED
            else -> PlayFlowResult.FAILED
        }
    }

    override suspend fun completeUpdate() {
        manager.completeUpdate().await()
    }

    override fun listen(onEnd: (PlayDownloadEnd) -> Unit): AutoCloseable {
        val listener = InstallStateUpdatedListener { state ->
            when (state.installStatus()) {
                InstallStatus.DOWNLOADED -> onEnd(PlayDownloadEnd.DOWNLOADED)
                InstallStatus.FAILED -> onEnd(PlayDownloadEnd.FAILED)
                InstallStatus.CANCELED -> onEnd(PlayDownloadEnd.CANCELED)
                else -> Unit
            }
        }
        manager.registerListener(listener)
        return AutoCloseable { manager.unregisterListener(listener) }
    }

    private fun isAllowed(info: AppUpdateInfo, type: Int): Boolean =
        info.isUpdateTypeAllowed(AppUpdateOptions.defaultOptions(type))

    private suspend fun <T> Task<T>.await(): T = suspendCancellableCoroutine { continuation ->
        addOnSuccessListener { value -> continuation.resume(value) }
        addOnFailureListener { failure -> continuation.resumeWithException(failure) }
    }
}
