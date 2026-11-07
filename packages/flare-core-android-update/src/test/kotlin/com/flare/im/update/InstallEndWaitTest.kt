package com.flare.im.update

import java.io.IOException
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** The system reports nothing for a page that never opened or was left, so the wait has to end by itself. */
@OptIn(ExperimentalCoroutinesApi::class)
class InstallEndWaitTest {
    private val session = nextSession.incrementAndGet()
    private val returns = FakeForeground()
    private val ended = CompletableDeferred<FlareUpdateInstallResult>()
    private val done = FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED)
    private var opens = 0
    private val page: () -> Boolean = {
        opens += 1
        true
    }

    private fun TestScope.waiting(): Deferred<FlareUpdateInstallResult?> {
        FlarePendingInstalls.await(session) { result -> ended.complete(result) }
        val wait = async { awaitInstallEnd(session, ended, returns) {} }
        runCurrent()
        return wait
    }

    @After
    fun forget() {
        FlarePendingInstalls.forget(session)
    }

    @Test
    fun aPageOpensAtOnceWhileTheAppIsOnScreen() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = true, page = page)
        assertEquals(1, opens)

        FlarePendingInstalls.complete(session, done)
        assertEquals(done, wait.await())
    }

    /** The case that used to hang: Android silently drops an activity started from the background. */
    @Test
    fun aPageInTheBackgroundOpensOnTheReturn() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = false, page = page)
        assertEquals("nothing on screen to open it from", 0, opens)

        returns.emit()
        runCurrent()
        assertEquals(1, opens)

        FlarePendingInstalls.complete(session, done)
        assertEquals(done, wait.await())
    }

    /** The user reads the page they came back to for as long as they like, within the limit. */
    @Test
    fun aPageOpenedOnTheReturnHasTheWholeLimit() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = false, page = page)
        returns.emit()
        runCurrent()

        advanceTimeBy(INSTALL_LEFT_LIMIT_MS * 2)
        runCurrent()
        assertFalse(wait.isCompleted)
    }

    /** A user who never comes back must not hold the update open. */
    @Test
    fun aPageThatNeverOpensEndsTheWait() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = false, page = page)

        advanceTimeBy(INSTALL_ANSWER_LIMIT_MS - 1)
        runCurrent()
        assertFalse(wait.isCompleted)

        advanceTimeBy(1)
        runCurrent()
        assertNull(wait.await())
        assertEquals(0, opens)
        assertFalse("nothing can reach this session any more", FlarePendingInstalls.pageOpened(session))
    }

    /** No answer on an open page ends the wait too; the session stays, so confirming it still installs. */
    @Test
    fun aPageNobodyAnswersEndsTheWait() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = true, page = page)

        advanceTimeBy(INSTALL_ANSWER_LIMIT_MS)
        runCurrent()
        assertNull(wait.await())
        assertTrue(FlarePendingInstalls.pageOpened(session))
    }

    /** Back in the app with the page left behind: the prompt has no way out, so the end comes soon. */
    @Test
    fun aPageLeftBehindEndsTheWaitSoonAfterTheReturn() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = true, page = page)

        returns.emit()
        advanceTimeBy(INSTALL_LEFT_LIMIT_MS - 1)
        runCurrent()
        assertFalse(wait.isCompleted)

        advanceTimeBy(1)
        runCurrent()
        assertNull(wait.await())
    }

    /** The user who answered also comes back to the app: the install is running, so it must not ask again. */
    @Test
    fun aPageThatOpenedNeverOpensAgain() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = true, page = page)

        returns.emit()
        runCurrent()
        assertEquals(1, opens)

        FlarePendingInstalls.complete(session, done)
        assertEquals(done, wait.await())
    }

    /** A cancel on the page is a status like any other, and it wins over the return it causes. */
    @Test
    fun anAnswerAfterTheReturnEndsTheWaitWithIt() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = true, page = page)
        returns.emit()
        runCurrent()

        val cancelled = FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)
        FlarePendingInstalls.complete(session, cancelled)
        assertEquals(cancelled, wait.await())
    }

    @Test
    fun aReturnBeforeTheSystemAsksChangesNothing() = runTest {
        val wait = waiting()
        returns.emit()
        runCurrent()
        assertFalse(wait.isCompleted)
        assertEquals(0, opens)

        FlarePendingInstalls.confirmation(session, onScreen = true, page = page)
        assertEquals(1, opens)

        advanceTimeBy(INSTALL_LEFT_LIMIT_MS * 2)
        runCurrent()
        assertFalse("this return was before the page, so the page gets the whole limit", wait.isCompleted)
    }

    @Test
    fun aPageThatCannotStartFailsTheInstall() = runTest {
        val wait = waiting()
        FlarePendingInstalls.confirmation(session, onScreen = false) { false }
        returns.emit()
        runCurrent()
        assertEquals(FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED), wait.await())
    }

    /** The process restarted meanwhile: the page is all that is left of the session. */
    @Test
    fun aPageNobodyWaitsForStillOpens() {
        FlarePendingInstalls.confirmation(session, onScreen = false, page = page)
        assertEquals(1, opens)
    }

    @Test
    fun theWaitStopsFollowingTheApp() = runTest {
        val wait = waiting()
        assertTrue(returns.listening)

        FlarePendingInstalls.complete(session, done)
        wait.await()
        assertFalse(returns.listening)
    }

    @Test
    fun aCommitThatFailsStopsFollowingTheApp() {
        assertThrows(IOException::class.java) {
            runBlocking { awaitInstallEnd(session, ended, returns) { throw IOException("full") } }
        }
        assertFalse(returns.listening)
    }

    @Test
    fun aCancelledWaitStopsFollowingTheApp() = runTest {
        val wait = waiting()
        wait.cancel()
        runCurrent()
        assertTrue(wait.isCancelled)
        assertFalse(returns.listening)
    }

    @Test
    fun `a session refused for want of room says so`() {
        assertEquals(FlareUpdateErrorCodes.INSUFFICIENT_SPACE, stagingFailure(110, 72))
        assertEquals(FlareUpdateErrorCodes.INSTALL_FAILED, stagingFailure(110, 110))
        assertEquals(FlareUpdateErrorCodes.INSTALL_FAILED, stagingFailure(110, null))
    }

    private companion object {
        val nextSession = AtomicInteger(9000)
    }
}
