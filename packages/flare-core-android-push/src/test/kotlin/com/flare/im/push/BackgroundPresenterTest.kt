package com.flare.im.push

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** 后台展示器与推送绑定开关：协调器怎么告诉宿主、怎么发链路上的提示、点开后去哪。 */
@OptIn(ExperimentalCoroutinesApi::class)
class BackgroundPresenterTest {
    private class PresentingHost : FlarePushHost {
        val presenterCalls = mutableListOf<Boolean>()
        val cleared = mutableListOf<String>()
        val tokens = mutableListOf<PlatformPushToken>()
        val taps = mutableListOf<Map<String, String>>()
        val presentations = MutableSharedFlow<PlatformPushPresentation>(extraBufferCapacity = 16)
        val corrections = MutableSharedFlow<PlatformNotificationCorrection>(extraBufferCapacity = 16)

        override suspend fun updatePushToken(token: PlatformPushToken) {
            tokens += token
        }

        override suspend fun setPushPermission(allowed: Boolean) = Unit

        override suspend fun reconcilePush() = Unit

        override suspend fun handleRemoteMessage(provider: String, payload: Map<String, String>, budgetMs: Int) =
            PlatformPushOutcome(PlatformPushAction.IGNORE)

        override suspend fun resolveNotificationTap(payload: Map<String, String>): PlatformTapRoute? {
            taps += payload
            return null
        }

        override suspend fun totalUnread(): Int = 0

        override fun notificationCorrections() = corrections

        override fun notificationPresentations() = presentations

        override suspend fun setBackgroundPresenter(attached: Boolean) {
            presenterCalls += attached
        }

        override suspend fun clearPushToken(provider: String) {
            cleared += provider
        }
    }

    /** 只实现必需方法的宿主：后台展示器与清绑定都走接口的默认实现。 */
    private class PlainHost : FlarePushHost {
        override suspend fun updatePushToken(token: PlatformPushToken) = Unit
        override suspend fun setPushPermission(allowed: Boolean) = Unit
        override suspend fun reconcilePush() = Unit
        override suspend fun handleRemoteMessage(provider: String, payload: Map<String, String>, budgetMs: Int) =
            PlatformPushOutcome(PlatformPushAction.IGNORE)
        override suspend fun resolveNotificationTap(payload: Map<String, String>): PlatformTapRoute? = null
        override suspend fun totalUnread(): Int = 0
    }

    private class RecordingPresenter : PushPresenter {
        val shown = mutableListOf<Triple<PlatformPushPresentation, Map<String, String>, Boolean>>()
        val badges = mutableListOf<Int>()

        override fun show(presentation: PlatformPushPresentation, payload: Map<String, String>, quiet: Boolean) {
            shown += Triple(presentation, payload, quiet)
        }

        override fun cancel(collapseIds: Collection<String>) = Unit

        override fun cancelAll() = Unit

        override fun badge(count: Int) {
            badges += count
        }
    }

    private class Environment : PushEnvironment {
        var allowed = true

        override fun notificationsAllowed(): Boolean = allowed

        override fun tokenMetadata() = PushTokenMetadata("com.acme.chat", "zh-CN", "Asia/Shanghai", "2.4.0")
    }

    private class Fixture(scope: CoroutineScope, var host: FlarePushHost?) {
        val presenter = RecordingPresenter()
        val environment = Environment()
        val epochs = MemoryPresenterEpochs()
        val attached = mutableListOf<Boolean>()
        val routes = mutableListOf<PlatformTapRoute>()
        val errors = mutableListOf<Throwable>()
        val coordinator = PushCoordinator(
            hostProvider = { host },
            presenter = presenter,
            environment = environment,
            scope = scope,
            onRoute = { routes += it },
            hostTimeoutMs = 3_000,
            resolveTimeoutMs = 15_000,
            wakeBudgetMs = 8_000,
            onError = { errors += it },
            epochs = epochs,
            onBackgroundPresenter = { attached += it },
        )
    }

    private fun presentation(surface: PlatformPushSurface, sound: Boolean = true) = PlatformPushPresentation(
        collapseId = "c:1",
        threadId = "c:1",
        conversationId = "conv-1",
        messageId = "m-9",
        seq = 9,
        title = "Alice",
        body = "hi",
        count = 2,
        sound = sound,
        channel = PlatformPushChannel.MESSAGES,
        surface = surface,
    )

    @Test
    fun attachingTellsTheHostOnlyWithPermissionAndDetachesWhenItIsRevoked() = runTest {
        val host = PresentingHost()
        val fixture = Fixture(this, host)

        fixture.coordinator.refresh()
        advanceUntilIdle()
        // 应用没要过：不报。
        assertEquals(emptyList<Boolean>(), host.presenterCalls)

        fixture.coordinator.setBackgroundPresenter(true)
        advanceUntilIdle()
        assertEquals(listOf(true), host.presenterCalls)
        assertEquals(listOf(true), fixture.attached)

        fixture.environment.allowed = false
        fixture.coordinator.refresh()
        advanceUntilIdle()
        assertEquals(listOf(true, false), host.presenterCalls)

        fixture.environment.allowed = true
        fixture.coordinator.refresh()
        advanceUntilIdle()
        assertEquals(listOf(true, false, true), host.presenterCalls)

        fixture.coordinator.setBackgroundPresenter(false)
        advanceUntilIdle()
        assertEquals(listOf(true, false, true, false), host.presenterCalls)
        fixture.coordinator.reset()
    }

    @Test
    fun aNewHostIsToldAgainAndSignOutPublishesDetached() = runTest {
        val first = PresentingHost()
        val fixture = Fixture(this, first)
        fixture.coordinator.setBackgroundPresenter(true)
        advanceUntilIdle()

        fixture.coordinator.reset()
        assertEquals(false, fixture.attached.last())

        val second = PresentingHost()
        fixture.host = second
        fixture.coordinator.refresh()
        advanceUntilIdle()
        assertEquals(listOf(true), second.presenterCalls)
        fixture.coordinator.reset()
    }

    @Test
    fun systemPresentationsAreShownWhileAttachedWithALocalTapPayload() = runTest {
        val host = PresentingHost()
        val fixture = Fixture(this, host)
        fixture.coordinator.refresh()
        advanceUntilIdle()

        // 没接上：不发。
        host.presentations.emit(presentation(PlatformPushSurface.SYSTEM))
        advanceUntilIdle()
        assertTrue(fixture.presenter.shown.isEmpty())

        fixture.coordinator.setBackgroundPresenter(true)
        advanceUntilIdle()
        host.presentations.emit(presentation(PlatformPushSurface.IN_APP))
        host.presentations.emit(presentation(PlatformPushSurface.SYSTEM))
        host.presentations.emit(presentation(PlatformPushSurface.SYSTEM, sound = false))
        advanceUntilIdle()

        assertEquals(2, fixture.presenter.shown.size)
        val (_, payload, quiet) = fixture.presenter.shown[0]
        assertEquals(false, quiet)
        assertEquals(true, fixture.presenter.shown[1].third)
        assertEquals("conv-1", payload[FlarePushPayload.CONVERSATION_ID])
        assertEquals("c:1", payload[FlarePushPayload.COLLAPSE_ID])
        assertEquals(LocalPresentations.ORIGIN_LINK, payload[LocalPresentations.ORIGIN])
        assertEquals(fixture.epochs.current(), payload[LocalPresentations.EPOCH])
        assertNull(payload[FlarePushPayload.BODY])

        // 点开：不经引擎，直接去那条会话。
        fixture.coordinator.openTap(payload)
        advanceUntilIdle()
        assertEquals(listOf(PlatformTapRoute("conv-1", "m-9", 9)), fixture.routes)
        assertTrue(host.taps.isEmpty())

        // 会话结束换了凭据：旧通知只打开应用。
        host.corrections.emit(PlatformNotificationCorrection.ClearAll)
        advanceUntilIdle()
        fixture.coordinator.openTap(payload)
        advanceUntilIdle()
        assertEquals(1, fixture.routes.size)
        assertTrue(host.taps.isEmpty())
        fixture.coordinator.reset()
    }

    @Test
    fun aPresentationAfterThePermissionWentAwayDetachesInsteadOfShowing() = runTest {
        val host = PresentingHost()
        val fixture = Fixture(this, host)
        fixture.coordinator.setBackgroundPresenter(true)
        advanceUntilIdle()

        fixture.environment.allowed = false
        host.presentations.emit(presentation(PlatformPushSurface.SYSTEM))
        advanceUntilIdle()

        assertTrue(fixture.presenter.shown.isEmpty())
        assertEquals(listOf(true, false), host.presenterCalls)
        fixture.coordinator.reset()
    }

    @Test
    fun badgeCorrectionsReachThePresenter() = runTest {
        val host = PresentingHost()
        val fixture = Fixture(this, host)
        fixture.coordinator.refresh()
        advanceUntilIdle()

        host.corrections.emit(PlatformNotificationCorrection.Badge(5))
        advanceUntilIdle()
        assertEquals(listOf(5), fixture.presenter.badges)
        fixture.coordinator.reset()
    }

    @Test
    fun withBindingsOffTokensAreNotRegisteredAndEveryProviderIsClearedOncePerHost() = runTest {
        val host = PresentingHost()
        val fixture = Fixture(this, host)
        fixture.coordinator.setPushBindings(false)
        fixture.coordinator.submitToken(PlatformPushProviders.FCM, "token-a", emptyList())
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertTrue(host.tokens.isEmpty())
        assertEquals(listOf(PlatformPushProviders.FCM, PlatformPushProviders.GETUI), host.cleared)

        fixture.coordinator.refresh()
        advanceUntilIdle()
        assertEquals(2, host.cleared.size)

        fixture.coordinator.setPushBindings(true)
        advanceUntilIdle()
        assertEquals(listOf("token-a"), host.tokens.map { it.token })
        fixture.coordinator.reset()
    }

    @Test
    fun aHostWithoutTheOptionalMethodsIsNotAskedAgain() = runTest {
        val fixture = Fixture(this, PlainHost())
        fixture.coordinator.setBackgroundPresenter(true)
        fixture.coordinator.setPushBindings(false)
        advanceUntilIdle()
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertTrue(fixture.errors.isEmpty())
        assertTrue(fixture.attached.isEmpty())
        fixture.coordinator.reset()
    }
}
