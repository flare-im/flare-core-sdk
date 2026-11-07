package com.flare.im.update.play

import com.flare.im.update.FlareUpdateErrorCodes
import com.flare.im.update.FlareUpdateHandoff
import com.flare.im.update.FlareUpdateInstallPlan
import com.flare.im.update.FlareUpdateInstallResult
import com.flare.im.update.FlareUpdateInstaller
import com.flare.im.update.FlareUpdateKind
import com.flare.im.update.FlareUpdateOutcome
import com.flare.im.update.FlareUpdateRelease
import java.io.IOException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FlarePlayUpdateInstallerTest {
    private class FakePlay(
        var snapshot: PlayUpdateSnapshot? = PlayUpdateSnapshot(
            available = true,
            downloaded = false,
            immediateAllowed = true,
            flexibleAllowed = true,
        ),
        var flow: PlayFlowResult = PlayFlowResult.ACCEPTED,
    ) : PlayUpdateClient {
        val started = mutableListOf<Boolean>()
        var completed = 0
        var listeners = 0
        var onEnd: ((PlayDownloadEnd) -> Unit)? = null
        var refusal: Exception? = null

        override suspend fun query(): PlayUpdateSnapshot = snapshot ?: throw IOException("Play is not on this device")

        override suspend fun start(immediate: Boolean): PlayFlowResult {
            started += immediate
            refusal?.let { throw it }
            return flow
        }

        override suspend fun completeUpdate() {
            completed += 1
        }

        override fun listen(onEnd: (PlayDownloadEnd) -> Unit): AutoCloseable {
            listeners += 1
            this.onEnd = onEnd
            return AutoCloseable { this.onEnd = null }
        }
    }

    private class FakeFallback : FlareUpdateInstaller {
        val plans = mutableListOf<FlareUpdateInstallPlan>()

        override suspend fun execute(plan: FlareUpdateInstallPlan): FlareUpdateInstallResult {
            plans += plan
            return FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED)
        }
    }

    private val play = FakePlay()
    private val fallback = FakeFallback()
    private val installer = FlarePlayUpdateInstaller(play, fallback)
    private val flexible = FlareUpdateInstallPlan.OpenStore("play", packageName = "com.acme.chat")
    private val immediate = flexible.copy(immediate = true)
    private val release = FlareUpdateRelease("rel", "2.4.0", 20400, kind = FlareUpdateKind.STORE)

    @Test
    fun aForcedPlanRunsTheImmediateFlow() = runTest {
        assertEquals(FlareUpdateOutcome.COMPLETED, installer.execute(immediate).outcome)
        assertEquals(listOf(true), play.started)
        assertEquals("Play owns the whole immediate flow", 0, play.listeners)
    }

    @Test
    fun anyOtherPlanRunsTheFlexibleFlow() = runTest {
        assertEquals(FlareUpdateOutcome.STARTED, installer.execute(flexible).outcome)
        assertEquals(listOf(false), play.started)
        assertEquals(1, play.listeners)
    }

    /** Nothing Play knows of means no prompt, whether it says so or cannot be asked. */
    @Test
    fun isNotPromptedWithoutAnUpdateFromPlay() = runTest {
        play.snapshot = PlayUpdateSnapshot(available = false, downloaded = false, immediateAllowed = false, flexibleAllowed = false)
        assertFalse(installer.canPrompt(release))
        play.snapshot = null
        assertFalse(installer.canPrompt(release))
    }

    @Test
    fun isPromptedWhenPlayHasTheUpdate() = runTest {
        assertTrue(installer.canPrompt(release))
    }

    /** A download an earlier run left behind asks for its restart. */
    @Test
    fun aDownloadFromAnEarlierRunAsksForTheRestart() = runTest {
        play.snapshot = PlayUpdateSnapshot(available = false, downloaded = true, immediateAllowed = false, flexibleAllowed = false)
        assertTrue(installer.canPrompt(release))
        assertEquals(FlareUpdateHandoff.RESTART_READY, installer.handoff.value)
    }

    /** A tap that reaches a Play with nothing on offer still leads somewhere: the Play page. */
    @Test
    fun withoutAnUpdateThePlayPageOpens() = runTest {
        play.snapshot = PlayUpdateSnapshot(available = false, downloaded = false, immediateAllowed = false, flexibleAllowed = false)
        installer.execute(flexible)
        assertEquals(listOf<FlareUpdateInstallPlan>(flexible), fallback.plans)
        assertTrue(play.started.isEmpty())
    }

    @Test
    fun aDisallowedFlowOpensThePlayPage() = runTest {
        play.snapshot = PlayUpdateSnapshot(available = true, downloaded = false, immediateAllowed = false, flexibleAllowed = true)
        installer.execute(immediate)
        assertEquals(listOf<FlareUpdateInstallPlan>(immediate), fallback.plans)
        assertTrue(play.started.isEmpty())
    }

    @Test
    fun noActivityOpensThePlayPage() = runTest {
        play.flow = PlayFlowResult.NO_ACTIVITY
        installer.execute(flexible)
        assertEquals(listOf<FlareUpdateInstallPlan>(flexible), fallback.plans)
    }

    @Test
    fun aDeclinedDialogIsCancelled() = runTest {
        play.flow = PlayFlowResult.CANCELED
        assertEquals(FlareUpdateOutcome.CANCELLED, installer.execute(flexible).outcome)
    }

    @Test
    fun aFailedDialogFails() = runTest {
        play.flow = PlayFlowResult.FAILED
        assertEquals(
            FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED),
            installer.execute(flexible),
        )
    }

    /**
     * Play can fail the flow rather than answer it. The engine sits in `installing` until it hears how the install
     * ended, so this has to come back as a result, and the listener of the flexible flow has to go.
     */
    @Test
    fun aFlowPlayFailsIsAFailedInstall() = runTest {
        play.refusal = IOException("Play refused the flow")

        assertEquals(
            FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED),
            installer.execute(flexible),
        )
        assertNull(play.onEnd)
    }

    /** Other plans are none of this installer's business. */
    @Test
    fun otherPlansGoToTheFallback() = runTest {
        val appgallery = FlareUpdateInstallPlan.OpenStore("appgallery", url = "https://appgallery.huawei.com/app/C1")
        val website = FlareUpdateInstallPlan.OpenStore(FlareUpdateInstallPlan.OpenStore.WEBSITE, url = "https://example.com")
        installer.execute(appgallery)
        installer.execute(website)
        assertEquals(listOf<FlareUpdateInstallPlan>(appgallery, website), fallback.plans)
        assertTrue(play.started.isEmpty())
    }

    /** The finished download only asks: the restart happens when the user says so. */
    @Test
    fun aFlexibleDownloadWaitsForTheUser() = runTest {
        installer.execute(flexible)
        assertEquals(FlareUpdateHandoff.NONE, installer.handoff.value)

        play.onEnd?.invoke(PlayDownloadEnd.DOWNLOADED)

        assertEquals(FlareUpdateHandoff.RESTART_READY, installer.handoff.value)
        assertEquals(0, play.completed)

        assertEquals(FlareUpdateOutcome.COMPLETED, installer.completeHandoff().outcome)
        assertEquals(1, play.completed)
    }

    @Test
    fun aDownloadThatEndsBadlyIsHandedBack() = runTest {
        installer.execute(flexible)
        play.onEnd?.invoke(PlayDownloadEnd.FAILED)
        assertEquals(FlareUpdateHandoff.FAILED, installer.handoff.value)

        installer.execute(flexible)
        assertEquals("a new attempt starts clean", FlareUpdateHandoff.NONE, installer.handoff.value)
        play.onEnd?.invoke(PlayDownloadEnd.CANCELED)
        assertEquals(FlareUpdateHandoff.CANCELLED, installer.handoff.value)
    }

    /** Nothing waits for a restart, so nothing restarts. */
    @Test
    fun completingWithoutADownloadDoesNothing() = runTest {
        assertEquals(FlareUpdateOutcome.CANCELLED, installer.completeHandoff().outcome)
        assertEquals(0, play.completed)
    }
}
