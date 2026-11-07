package com.flare.im.update.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.flare.im.ui.FlareUpdateFallbackTarget as KitFallbackTarget
import com.flare.im.ui.FlareUpdateProgress as KitProgress
import com.flare.im.ui.FlareUpdatePromptForm as KitPromptForm
import com.flare.im.ui.UpdatePrompt
import com.flare.im.ui.VersionPanel
import com.flare.im.update.FlareUpdateController
import com.flare.im.update.FlareUpdateFallbackTarget
import com.flare.im.update.FlareUpdatePromptForm
import com.flare.im.update.FlareUpdateState
import com.flare.im.update.FlareUpdateStatus

/** The Kit's form for `status.prompt`; null when nothing interrupts the user, which is all a badge does. */
val FlareUpdateStatus.kitPromptForm: KitPromptForm?
    get() = when (prompt) {
        FlareUpdatePromptForm.SHEET -> KitPromptForm.Sheet
        FlareUpdatePromptForm.MODAL -> KitPromptForm.Modal
        FlareUpdatePromptForm.FULLSCREEN -> KitPromptForm.Fullscreen
        FlareUpdatePromptForm.NONE, FlareUpdatePromptForm.BADGE -> null
    }

/** The version the prompt names: the running one when the server refused this build before any release arrived. */
val FlareUpdateStatus.kitVersion: String get() = release?.version ?: current.version.orEmpty()

/** Forced, which the state says on its own before a release arrives. */
val FlareUpdateStatus.kitMandatory: Boolean get() = state == FlareUpdateState.REQUIRED || release?.mandatory == true

val FlareUpdateStatus.kitProgress: KitProgress? get() = progress?.let { KitProgress(it.received, it.total) }

val FlareUpdateStatus.kitFallbackTarget: KitFallbackTarget
    get() = when (fallbackTarget) {
        FlareUpdateFallbackTarget.WEBSITE -> KitFallbackTarget.Website
        FlareUpdateFallbackTarget.STORE -> KitFallbackTarget.Store
    }

/**
 * The update prompt over the app, in either sign-in state: on screen for as long as `status.prompt` is
 * a form, and told to the engine once it is. Put it where the Kit's theme and strings reach it.
 */
@Composable
fun FlareUpdatePromptHost(controller: FlareUpdateController) {
    val status by controller.state.collectAsState()
    val shown = status ?: return
    val form = shown.kitPromptForm ?: return
    LaunchedEffect(form, shown.release?.build) { controller.markPrompted() }
    UpdatePrompt(
        form = form,
        version = shown.kitVersion,
        notes = shown.release?.notes.orEmpty(),
        reason = shown.blockReason,
        sizeBytes = shown.release?.sizeBytes,
        mandatory = shown.kitMandatory,
        state = shown.state.wireValue,
        progress = shown.kitProgress,
        errorCode = shown.error?.code,
        retryable = shown.error?.retryable ?: true,
        fallbackTarget = shown.kitFallbackTarget,
        canContinueReadOnly = shown.canContinueReadOnly,
        onUpdate = { controller.launch { update() } },
        onLater = { controller.launch { later() } },
        onSkip = { controller.launch { skip() } },
        onRetry = { controller.launch { update() } },
        // The Kit draws the fallback only when it has a handler, and there is nowhere to go without a link.
        onFallback = if (shown.error?.fallbackUrl == null) null else ({ controller.launch { openFallback() } }),
        onContinueReadOnly = { controller.launch { continueReadOnly() } },
    )
}

/** The version block of the about page. [installedVersion] shows until the first status is read. */
@Composable
fun FlareUpdateVersionPanel(controller: FlareUpdateController, installedVersion: String) {
    val status by controller.state.collectAsState()
    VersionPanel(
        version = status?.current?.version ?: installedVersion,
        build = status?.current?.build,
        channel = status?.current?.channel,
        updateState = status?.state?.wireValue,
        onCheck = { controller.launch { check() } },
        onUpdate = { controller.launch { update() } },
    )
}
