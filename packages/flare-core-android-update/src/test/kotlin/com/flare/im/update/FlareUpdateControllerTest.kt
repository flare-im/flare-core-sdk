package com.flare.im.update

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FlareUpdateControllerTest {
    private val engine = FakeEngine()
    private val installer = FakeInstaller()
    private val foreground = FakeForeground()

    private fun TestScope.controller(initial: Map<String, Any?> = status("available")): FlareUpdateController {
        engine.answers[FlareUpdateOperations.GET_STATE] = initial
        val controller = FlareUpdateController(engine, installer, foreground, scope = backgroundScope).install()
        runCurrent()
        return controller
    }

    /** Events do not arrive before login, so the start, the foreground and login each read the status. */
    @Test
    fun readsTheStatusOnStartForegroundAndLogin() = runTest {
        val controller = controller()
        assertEquals(1, engine.count(FlareUpdateOperations.GET_STATE))
        assertEquals(FlareUpdateState.AVAILABLE, controller.state.value?.state)

        foreground.emit()
        runCurrent()
        assertEquals(2, engine.count(FlareUpdateOperations.GET_STATE))

        controller.onLoginSucceeded()
        runCurrent()
        assertEquals(3, engine.count(FlareUpdateOperations.GET_STATE))

        controller.onLoginFailed()
        runCurrent()
        assertEquals(4, engine.count(FlareUpdateOperations.GET_STATE))
    }

    /** A return says so itself, since `lifecycle.set_app_state` may reach the engine after this read. */
    @Test
    fun aReturnToTheForegroundSaysSo() = runTest {
        val controller = controller()
        assertEquals(emptyMap<String, Any?>(), engine.calls.last().second)

        foreground.emit()
        runCurrent()
        assertEquals(mapOf("foreground" to true), engine.calls.last().second)

        controller.onLoginSucceeded()
        runCurrent()
        assertEquals(emptyMap<String, Any?>(), engine.calls.last().second)
    }

    /** `update.check` answers at once: what it returns is no result, the poll of `checking` brings that. */
    @Test
    fun aCheckAnswersAtOnceAndThePollBringsItsResult() = runTest {
        val controller = controller(status("idle", release = null))
        val running = status("checking", release = null)
        engine.answers[FlareUpdateOperations.CHECK] = running
        engine.answers[FlareUpdateOperations.GET_STATE] = running

        val answer = controller.check()
        assertEquals(FlareUpdateState.CHECKING, answer?.state)
        assertEquals(1, engine.count(FlareUpdateOperations.GET_STATE))

        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS)
        runCurrent()
        assertEquals(2, engine.count(FlareUpdateOperations.GET_STATE))

        engine.answers[FlareUpdateOperations.GET_STATE] = status("available")
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS)
        runCurrent()
        assertEquals(FlareUpdateState.AVAILABLE, controller.state.value?.state)

        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS * 3)
        runCurrent()
        assertEquals("a settled state is not polled", 3, engine.count(FlareUpdateOperations.GET_STATE))
    }

    /** The answer to a new language is a status like any other: the words of the reason come with it. */
    @Test
    fun aLanguageChangeReachesTheEngineAndComesBack() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.SET_LOCALE] =
            status("required", release = wireRelease(mandatory = true), blockReason = "No longer supported")

        controller.setLocale("en-US")

        assertEquals(
            mapOf("locale" to "en-US"),
            engine.calls.single { it.first == FlareUpdateOperations.SET_LOCALE }.second,
        )
        assertEquals("No longer supported", controller.state.value?.blockReason)
    }

    /** Language is no step of the update: a refusal does not show up as an update failure. */
    @Test
    fun aLanguageTheEngineRefusesIsNoUpdateError() = runTest {
        val controller = controller()
        engine.refusals[FlareUpdateOperations.SET_LOCALE] = FlareUpdateException(FlareUpdateErrorCodes.INSTALL_FAILED)

        controller.setLocale("en-US")

        assertNull(controller.state.value?.error)
    }

    /** The engine refuses a language before `init` and does not keep it: it waits for the first status. */
    @Test
    fun aLanguageSetBeforeTheEngineIsUpWaitsForItsFirstStatus() = runTest {
        engine.answers[FlareUpdateOperations.GET_STATE] = status("available")
        val controller = FlareUpdateController(engine, installer, foreground, scope = backgroundScope)

        controller.setLocale("en-US")
        assertEquals(0, engine.count(FlareUpdateOperations.SET_LOCALE))

        controller.install()
        runCurrent()

        assertEquals(
            mapOf("locale" to "en-US"),
            engine.calls.single { it.first == FlareUpdateOperations.SET_LOCALE }.second,
        )
    }

    @Test
    fun aLanguageTheEngineRefusedGoesAgainWithTheNextStatus() = runTest {
        val controller = controller()
        engine.refusals[FlareUpdateOperations.SET_LOCALE] = FlareUpdateException(FlareUpdateErrorCodes.INSTALL_FAILED)

        controller.setLocale("en-US")
        assertEquals(1, engine.count(FlareUpdateOperations.SET_LOCALE))

        controller.onLoginSucceeded()
        runCurrent()
        assertEquals(2, engine.count(FlareUpdateOperations.SET_LOCALE))

        controller.onLoginSucceeded()
        runCurrent()
        assertEquals("one that went through is not sent again", 2, engine.count(FlareUpdateOperations.SET_LOCALE))
    }

    /** Silence while something runs is filled by reading the status; the reads stop with the state. */
    @Test
    fun pollsARunningStateThatStaysSilent() = runTest {
        controller(status("downloading"))
        assertEquals(1, engine.count(FlareUpdateOperations.GET_STATE))

        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS - 1)
        runCurrent()
        assertEquals("no read before the interval", 1, engine.count(FlareUpdateOperations.GET_STATE))

        advanceTimeBy(1)
        runCurrent()
        assertEquals(2, engine.count(FlareUpdateOperations.GET_STATE))

        engine.answers[FlareUpdateOperations.GET_STATE] = status("readyToInstall")
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS)
        runCurrent()
        assertEquals(3, engine.count(FlareUpdateOperations.GET_STATE))

        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS * 4)
        runCurrent()
        assertEquals("a settled state is not polled", 3, engine.count(FlareUpdateOperations.GET_STATE))
    }

    /** `checking` and `verifying` are polled as well; `installing` is not. */
    @Test
    fun pollsOnlyCheckingDownloadingAndVerifying() = runTest {
        for (running in listOf("checking", "verifying")) {
            engine.calls.clear()
            val controller = controller(status(running))
            advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS)
            runCurrent()
            assertEquals(running, 2, engine.count(FlareUpdateOperations.GET_STATE))
            controller.dispose()
        }
        engine.calls.clear()
        controller(status("installing"))
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS * 3)
        runCurrent()
        assertEquals(1, engine.count(FlareUpdateOperations.GET_STATE))
    }

    /** An event means the bus is alive: it stops the wait, and only a new silence reads again. */
    @Test
    fun anEventHoldsThePollBack() = runTest {
        controller(status("downloading"))
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS - 100)
        engine.emit(status("downloading"))
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS - 100)
        runCurrent()
        assertEquals(1, engine.count(FlareUpdateOperations.GET_STATE))

        engine.emit(status("readyToInstall"))
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS * 3)
        runCurrent()
        assertEquals(1, engine.count(FlareUpdateOperations.GET_STATE))
    }

    /** Every route's return value is the latest status, with no event needed. */
    @Test
    fun takesEveryReturnValueAsTheLatestStatus() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.CHECK] = status("upToDate", release = null)
        controller.check()
        assertEquals(FlareUpdateState.UP_TO_DATE, controller.state.value?.state)
        assertEquals(mapOf("manual" to true), engine.calls.last { it.first == FlareUpdateOperations.CHECK }.second)
    }

    /** The whole direct flow, in order, and the outcome goes back to the engine. */
    @Test
    fun runsDownloadInstallAndReport() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.DOWNLOAD] = status("readyToInstall")
        engine.answers[FlareUpdateOperations.INSTALL] = PACKAGE_PLAN
        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("installing")
        installer.result = FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED)
        engine.calls.clear()

        controller.update()

        assertEquals(
            listOf(
                FlareUpdateOperations.DOWNLOAD,
                FlareUpdateOperations.INSTALL,
                FlareUpdateOperations.GET_STATE,
                FlareUpdateOperations.REPORT_INSTALL,
            ),
            engine.routes(),
        )
        assertEquals(mapOf("allowMetered" to false), engine.calls[0].second)
        assertEquals(mapOf("outcome" to "completed"), engine.calls[3].second)
        assertEquals(1, installer.executed.size)
    }

    /** `update.download` may return while it runs: the flow waits for the state, polled if need be. */
    @Test
    fun waitsForADownloadThatReturnsEarly() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.DOWNLOAD] = status("downloading")
        engine.answers[FlareUpdateOperations.INSTALL] = PACKAGE_PLAN
        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("installing")
        val run = launch { controller.update() }
        runCurrent()
        assertTrue("nothing installs before the download ends", installer.executed.isEmpty())

        engine.answers[FlareUpdateOperations.GET_STATE] = status("readyToInstall")
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS)
        runCurrent()
        run.join()
        assertEquals(1, installer.executed.size)
    }

    /** An install nobody answered ends the update like any other, so the next tap starts over. */
    @Test
    fun anUnansweredInstallEndsTheUpdateAndTheNextTapRuns() = runTest {
        val controller = controller(status("readyToInstall"))
        engine.answers[FlareUpdateOperations.INSTALL] = PACKAGE_PLAN
        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("readyToInstall")
        val waiting = CompletableDeferred<FlareUpdateInstallResult>()
        installer.waitsFor = waiting
        val run = launch { controller.update() }
        runCurrent()

        controller.update()
        assertEquals("a tap during the wait runs nothing", 1, installer.executed.size)

        waiting.complete(FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED))
        run.join()
        assertEquals(
            mapOf("outcome" to "cancelled"),
            engine.calls.last { it.first == FlareUpdateOperations.REPORT_INSTALL }.second,
        )

        installer.waitsFor = null
        controller.update()
        assertEquals(2, installer.executed.size)
    }

    /** A failed download ends the flow: nothing is installed. */
    @Test
    fun stopsWhenTheDownloadFails() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.DOWNLOAD] = status(
            "failed",
            error = mapOf("code" to FlareUpdateErrorCodes.HASH_MISMATCH, "retryable" to true),
        )
        controller.update()
        assertTrue(installer.executed.isEmpty())
        assertEquals(0, engine.count(FlareUpdateOperations.INSTALL))
        assertEquals(FlareUpdateErrorCodes.HASH_MISMATCH, controller.state.value?.error?.code)
    }

    /** A store release has nothing to download. */
    @Test
    fun aStoreReleaseSkipsTheDownload() = runTest {
        val controller = controller(status("available", release = wireRelease(kind = "store"), distribution = "play"))
        engine.answers[FlareUpdateOperations.INSTALL] = mapOf("kind" to "openStore", "store" to "play", "immediate" to false)
        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("installing", release = wireRelease(kind = "store"))
        controller.update()
        assertEquals(0, engine.count(FlareUpdateOperations.DOWNLOAD))
        assertEquals(
            mapOf("outcome" to "completed"),
            engine.calls.last { it.first == FlareUpdateOperations.REPORT_INSTALL }.second,
        )
    }

    /** The first tap asks; the second, with the error on screen, is the confirmation. */
    @Test
    fun aMeteredRefusalMakesTheNextUpdateAllowMetered() = runTest {
        val controller = controller()
        engine.refusals[FlareUpdateOperations.DOWNLOAD] =
            FlareUpdateException(FlareUpdateErrorCodes.METERED_CONFIRMATION_REQUIRED, retryable = true)
        controller.update()
        assertEquals(FlareUpdateErrorCodes.METERED_CONFIRMATION_REQUIRED, controller.state.value?.error?.code)

        engine.answers[FlareUpdateOperations.DOWNLOAD] = status("readyToInstall")
        engine.answers[FlareUpdateOperations.INSTALL] = PACKAGE_PLAN
        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("installing")
        controller.update()

        val downloads = engine.calls.filter { it.first == FlareUpdateOperations.DOWNLOAD }
        assertEquals(listOf(false, true), downloads.map { it.second["allowMetered"] })
        assertNull(controller.state.value?.error)
    }

    /** The engine may put the same refusal in the status instead. */
    @Test
    fun aMeteredErrorInTheStatusCountsTheSame() = runTest {
        val controller = controller(
            status("available", error = mapOf("code" to FlareUpdateErrorCodes.METERED_CONFIRMATION_REQUIRED)),
        )
        engine.answers[FlareUpdateOperations.DOWNLOAD] = status("available")
        controller.update()
        assertEquals(
            true,
            engine.calls.single { it.first == FlareUpdateOperations.DOWNLOAD }.second["allowMetered"],
        )
    }

    /** `later` is always the engine's to decide, the download phases included. */
    @Test
    fun laterAlwaysDefers() = runTest {
        for (state in listOf("available", "downloading", "verifying")) {
            engine.calls.clear()
            val controller = controller(status(state, prompt = "sheet"))
            engine.answers[FlareUpdateOperations.DEFER] = status(state, prompt = "none")

            controller.later()

            assertEquals(state, 1, engine.count(FlareUpdateOperations.DEFER))
            assertEquals(state, FlareUpdatePromptForm.NONE, controller.state.value?.prompt)
            controller.dispose()
        }
    }

    /** A download the user walked away from ends in a prompt, not in an installer opening by itself. */
    @Test
    fun aDownloadPutAsideWaitsForTheUser() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.DOWNLOAD] = status("downloading")
        engine.answers[FlareUpdateOperations.DEFER] = status("downloading")
        val run = launch { controller.update() }
        runCurrent()

        controller.later()
        engine.emit(status("readyToInstall", prompt = "sheet"))
        run.join()

        assertTrue(installer.executed.isEmpty())
        assertEquals(0, engine.count(FlareUpdateOperations.INSTALL))
        assertEquals(FlareUpdateState.READY_TO_INSTALL, controller.state.value?.state)

        engine.answers[FlareUpdateOperations.INSTALL] = PACKAGE_PLAN
        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("installing")
        controller.update()
        assertEquals("the user's own tap installs", 1, installer.executed.size)
    }

    /** The engine maintains the prompt: what it says is what the state shows. */
    @Test
    fun bindsThePromptTheEngineGives() = runTest {
        val controller = controller(status("available", prompt = "sheet"))
        engine.answers[FlareUpdateOperations.MARK_PROMPTED] = status("available", prompt = "badge")

        controller.markPrompted()

        assertEquals(
            mapOf("build" to 20400L, "form" to "sheet"),
            engine.calls.single { it.first == FlareUpdateOperations.MARK_PROMPTED }.second,
        )
        assertEquals(FlareUpdatePromptForm.BADGE, controller.state.value?.prompt)
    }

    /** The server can refuse this build before the manifest arrives: forced, with no release yet. */
    @Test
    fun aForcedStateNeedsNoRelease() = runTest {
        val controller = controller(status("required", release = null, prompt = "modal"))
        assertTrue(controller.state.value?.canContinueReadOnly == true)

        controller.markPrompted()
        assertEquals(
            mapOf("form" to "modal"),
            engine.calls.single { it.first == FlareUpdateOperations.MARK_PROMPTED }.second,
        )

        controller.update()
        assertEquals(0, engine.count(FlareUpdateOperations.INSTALL))
        assertTrue(installer.executed.isEmpty())

        engine.answers[FlareUpdateOperations.DEFER] = status("required", release = null, readOnly = true)
        controller.continueReadOnly()
        assertEquals(1, engine.count(FlareUpdateOperations.DEFER))
        assertEquals(FlareUpdatePromptForm.NONE, controller.state.value?.prompt)
        assertEquals(true, controller.state.value?.readOnly)
    }

    /** `update()` looks for the release the refusal did not bring; the check it starts ends in the background. */
    @Test
    fun updateLooksForTheReleaseARefusalDidNotBring() = runTest {
        val controller = controller(status("required", release = null, prompt = "modal"))
        val running = status("checking", release = null, prompt = "modal")
        engine.answers[FlareUpdateOperations.CHECK] = running
        engine.answers[FlareUpdateOperations.GET_STATE] = running

        val answer = controller.update()

        assertEquals(FlareUpdateState.CHECKING, answer?.state)
        assertEquals(
            mapOf("manual" to true),
            engine.calls.single { it.first == FlareUpdateOperations.CHECK }.second,
        )
        assertEquals(0, engine.count(FlareUpdateOperations.INSTALL))

        engine.answers[FlareUpdateOperations.GET_STATE] =
            status("required", release = wireRelease(mandatory = true), prompt = "modal")
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS)
        runCurrent()
        assertEquals("2.4.0", controller.state.value?.release?.version)
        assertEquals(FlareUpdateState.REQUIRED, controller.state.value?.state)
        assertEquals(0, engine.count(FlareUpdateOperations.INSTALL))
    }

    /** A forced download stays forced after it leaves the `required` state. */
    @Test
    fun aForcedDownloadCanStillBePutAside() = runTest {
        val controller = controller(status("downloading", release = wireRelease(mandatory = true)))
        assertTrue(controller.state.value?.canContinueReadOnly == true)
    }

    /** A route refused without a code still shows: `update` falls back to the install failure. */
    @Test
    fun aFailureWithoutACodeReachesTheState() = runTest {
        val controller = controller(status("available", release = wireRelease(kind = "store")))
        engine.failures[FlareUpdateOperations.INSTALL] = IllegalStateException("bridge is gone")
        controller.update()
        assertEquals(FlareUpdateErrorCodes.INSTALL_FAILED, controller.state.value?.error?.code)
        assertEquals(true, controller.state.value?.error?.retryable)
    }

    /** A refused route leaves its facts in the status: what the engine recorded replaces what the exception said. */
    @Test
    fun aRefusalReadsWhatTheEngineRecorded() = runTest {
        val controller = controller(status("available", release = wireRelease(kind = "store")))
        val recorded = mapOf(
            "code" to FlareUpdateErrorCodes.NO_ARTIFACT,
            "retryable" to true,
            "fallbackUrl" to "https://example.com/download",
        )
        engine.refusals[FlareUpdateOperations.INSTALL] = FlareUpdateException(FlareUpdateErrorCodes.NO_ARTIFACT)
        engine.answers[FlareUpdateOperations.GET_STATE] = status("available", release = wireRelease(kind = "store"), error = recorded)

        controller.update()

        assertEquals(true, controller.state.value?.error?.retryable)
        assertEquals("https://example.com/download", controller.state.value?.error?.fallbackUrl)
    }

    /** The screen that started an action can go; the action runs on the controller's own scope. */
    @Test
    fun launchRunsOnTheControllersScope() = runTest {
        val controller = controller(status("available", release = wireRelease(kind = "store")))
        engine.answers[FlareUpdateOperations.DEFER] = status("available", release = wireRelease(kind = "store"))

        controller.launch { later() }
        runCurrent()

        assertEquals(1, engine.count(FlareUpdateOperations.DEFER))
    }

    @Test
    fun namesTheCodeInAnErrorText() {
        assertEquals(FlareUpdateErrorCodes.NO_ARTIFACT, FlareUpdateErrorCodes.named("INVALID_PARAMETER: update.noArtifact"))
        assertEquals(null, FlareUpdateErrorCodes.named("the update center is not initialised; call init first"))
        assertEquals(null, FlareUpdateErrorCodes.named(null))
    }

    /** A badge is not a prompt on screen. */
    @Test
    fun aBadgeIsNotMarked() = runTest {
        val controller = controller(status("available", prompt = "badge"))
        controller.markPrompted()
        assertEquals(0, engine.count(FlareUpdateOperations.MARK_PROMPTED))
    }

    @Test
    fun skipsTheReleaseOnOffer() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.SKIP] = status("idle", release = null)
        controller.skip()
        assertEquals(
            mapOf("build" to 20400L),
            engine.calls.single { it.first == FlareUpdateOperations.SKIP }.second,
        )
    }

    /** The engine refuses to skip a forced release; the refusal shows in the state, nothing is thrown. */
    @Test
    fun aRefusedRouteReachesTheState() = runTest {
        val controller = controller(status("required", release = wireRelease(mandatory = true)))
        engine.refusals[FlareUpdateOperations.SKIP] = FlareUpdateException(FlareUpdateErrorCodes.NOT_SKIPPABLE)
        controller.skip()
        assertEquals(FlareUpdateErrorCodes.NOT_SKIPPABLE, controller.state.value?.error?.code)
    }

    /** Read-only browsing is the engine's: `update.defer` folds the prompt away, and nothing is kept here. */
    @Test
    fun continueReadOnlyGoesThroughTheEngine() = runTest {
        val forced = status("required", release = wireRelease(mandatory = true), prompt = "modal")
        val controller = controller(forced)
        assertTrue(controller.state.value?.canContinueReadOnly == true)
        engine.answers[FlareUpdateOperations.DEFER] =
            status("required", release = wireRelease(mandatory = true), readOnly = true)

        controller.continueReadOnly()

        assertEquals(1, engine.count(FlareUpdateOperations.DEFER))
        assertEquals(FlareUpdatePromptForm.NONE, controller.state.value?.prompt)
        assertEquals(true, controller.state.value?.readOnly)

        foreground.emit()
        runCurrent()
        assertEquals(FlareUpdatePromptForm.MODAL, controller.state.value?.prompt)
        assertEquals(false, controller.state.value?.readOnly)
    }

    /** A blocking update cannot be put aside. */
    @Test
    fun aBlockingUpdateHasNoReadOnlyWayOut() = runTest {
        val controller = controller(
            status("required", release = wireRelease(mandatory = true), prompt = "fullscreen", blockUi = true),
        )
        assertFalse(controller.state.value?.canContinueReadOnly == true)
        controller.continueReadOnly()
        assertEquals(0, engine.count(FlareUpdateOperations.DEFER))
        assertEquals(FlareUpdatePromptForm.FULLSCREEN, controller.state.value?.prompt)
    }

    /** The Kit gets retryable as sent, and the fallback target from the distribution. */
    @Test
    fun exposesRetryableAndTheFallbackTarget() = runTest {
        val failed = mapOf(
            "code" to FlareUpdateErrorCodes.HASH_MISMATCH,
            "retryable" to true,
            "fallbackUrl" to "https://example.com/download",
        )
        val direct = controller(status("failed", error = failed))
        assertEquals(true, direct.state.value?.error?.retryable)
        assertEquals(FlareUpdateFallbackTarget.WEBSITE, direct.state.value?.fallbackTarget)

        engine.emit(status("failed", error = failed, distribution = "play"))
        assertEquals(FlareUpdateFallbackTarget.STORE, direct.state.value?.fallbackTarget)
    }

    @Test
    fun opensTheFallbackLink() = runTest {
        val controller = controller(
            status("failed", error = mapOf("code" to "update.downloadFailed", "fallbackUrl" to "https://example.com")),
        )
        assertTrue(controller.openFallback())
        assertEquals(
            FlareUpdateInstallPlan.OpenStore(FlareUpdateInstallPlan.OpenStore.WEBSITE, url = "https://example.com"),
            installer.executed.single(),
        )
    }

    /** A store with nothing to offer silences an optional release, the badge included. */
    @Test
    fun aStoreWithoutTheUpdateIsNotPrompted() = runTest {
        installer.prompts = false
        val controller = controller(status("available", release = wireRelease(kind = "store"), prompt = "sheet"))
        assertEquals(FlareUpdatePromptForm.NONE, controller.state.value?.prompt)

        installer.prompts = true
        foreground.emit()
        runCurrent()
        assertEquals("the store is asked again", FlareUpdatePromptForm.SHEET, controller.state.value?.prompt)
    }

    /** A forced release keeps its prompt: the server already refuses this build. */
    @Test
    fun aForcedReleaseIsPromptedWhateverTheStoreSays() = runTest {
        installer.prompts = false
        val controller = controller(
            status("required", release = wireRelease(kind = "store", mandatory = true), prompt = "modal"),
        )
        assertEquals(FlareUpdatePromptForm.MODAL, controller.state.value?.prompt)
    }

    /** A package release does not depend on any store. */
    @Test
    fun aPackageReleaseIsNotGated() = runTest {
        installer.prompts = false
        val controller = controller(status("available", prompt = "sheet"))
        assertEquals(FlareUpdatePromptForm.SHEET, controller.state.value?.prompt)
    }

    /** A finished store download asks for the restart; only the user's tap performs it. */
    @Test
    fun aDownloadedStoreUpdateWaitsForTheUser() = runTest {
        val controller = controller(status("installing", release = wireRelease(kind = "store"), prompt = "sheet"))
        installer.handoffs.value = FlareUpdateHandoff.RESTART_READY
        runCurrent()

        assertEquals(FlareUpdateState.READY_TO_INSTALL, controller.state.value?.state)
        assertEquals(FlareUpdatePromptForm.SHEET, controller.state.value?.prompt)
        assertEquals(0, installer.completed)

        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("idle", release = null)
        controller.update()

        assertEquals(1, installer.completed)
        assertEquals(0, engine.count(FlareUpdateOperations.INSTALL))
        assertEquals(
            mapOf("outcome" to "completed"),
            engine.calls.last { it.first == FlareUpdateOperations.REPORT_INSTALL }.second,
        )
    }

    /** A background store download that fails still ends the install on the engine. */
    @Test
    fun aFailedHandoffIsReported() = runTest {
        controller(status("installing", release = wireRelease(kind = "store")))
        engine.answers[FlareUpdateOperations.REPORT_INSTALL] = status("failed", release = wireRelease(kind = "store"))
        installer.handoffs.value = FlareUpdateHandoff.FAILED
        runCurrent()
        assertEquals(
            mapOf("outcome" to "failed", "code" to FlareUpdateErrorCodes.INSTALL_FAILED),
            engine.calls.last { it.first == FlareUpdateOperations.REPORT_INSTALL }.second,
        )
    }

    /** Nothing moves after dispose. */
    @Test
    fun disposeStopsEverything() = runTest {
        val controller = controller(status("downloading"))
        controller.dispose()
        assertTrue(engine.closed)
        advanceTimeBy(FlareUpdateController.POLL_INTERVAL_MS * 3)
        runCurrent()
        assertEquals(1, engine.count(FlareUpdateOperations.GET_STATE))
        engine.emit(status("idle"))
        assertEquals(FlareUpdateState.DOWNLOADING, controller.state.value?.state)
    }

    /** The content stays the text the engine verified, for the Kit to read. */
    @Test
    fun loadsTheResourcePacksOfThisRun() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.GET_RESOURCES] = mapOf(
            "packs" to listOf(
                mapOf("id" to "emoji", "kind" to "emoji", "packVersion" to 3L, "contentJson" to "{\"packs\":[]}"),
                mapOf("id" to "strings", "kind" to "strings", "packVersion" to 12, "contentJson" to "{}"),
            ),
        )

        assertEquals(
            listOf(
                FlareUpdateResourcePack("emoji", "emoji", 3, "{\"packs\":[]}"),
                FlareUpdateResourcePack("strings", "strings", 12, "{}"),
            ),
            controller.loadResources(),
        )
        assertEquals(emptyMap<String, Any?>(), engine.calls.last().second)
    }

    @Test
    fun noResourcePacksIsAnEmptyList() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.GET_RESOURCES] = mapOf("packs" to emptyList<Any?>())
        assertEquals(emptyList<FlareUpdateResourcePack>(), controller.loadResources())
    }

    /** Packs are no step of the update: the app stays on its built-in resources and the prompt shows no error. */
    @Test
    fun aFailedResourceReadOnlyReachesOnError() = runTest {
        val errors = mutableListOf<Throwable>()
        engine.answers[FlareUpdateOperations.GET_STATE] = status("available")
        val controller = FlareUpdateController(
            engine,
            installer,
            foreground,
            onError = { errors += it },
            scope = backgroundScope,
        ).install()
        runCurrent()
        engine.refusals[FlareUpdateOperations.GET_RESOURCES] = FlareUpdateException(FlareUpdateErrorCodes.INSTALL_FAILED)

        assertEquals(emptyList<FlareUpdateResourcePack>(), controller.loadResources())
        assertEquals(1, errors.size)
        assertNull(controller.state.value?.error)
    }

    /** A pack with a field missing is a broken answer: nothing of it is used. */
    @Test
    fun aMalformedResourceAnswerIsNoPacks() = runTest {
        val controller = controller()
        engine.answers[FlareUpdateOperations.GET_RESOURCES] = mapOf("packs" to listOf(mapOf("id" to "strings")))
        assertEquals(emptyList<FlareUpdateResourcePack>(), controller.loadResources())
    }

    /** A malformed event is dropped and reported; the state keeps its last good value. */
    @Test
    fun aMalformedEventIsDropped() = runTest {
        val errors = mutableListOf<Throwable>()
        engine.answers[FlareUpdateOperations.GET_STATE] = status("available")
        val controller = FlareUpdateController(
            engine,
            installer,
            foreground,
            onError = { errors += it },
            scope = backgroundScope,
        ).install()
        runCurrent()
        engine.emit(mapOf("state" to "unheardOf"))
        assertEquals(FlareUpdateState.AVAILABLE, controller.state.value?.state)
        assertEquals(1, errors.size)
    }
}
