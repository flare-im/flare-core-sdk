package com.flare.im.push

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PushCoordinatorTest {
    private class FakeHost : FlarePushHost {
        val tokens = mutableListOf<PlatformPushToken>()
        val permissions = mutableListOf<Boolean>()
        val handled = mutableListOf<Triple<String, Map<String, String>, Int>>()
        val taps = mutableListOf<Map<String, String>>()
        var reconciled = 0
        var outcome = PlatformPushOutcome(PlatformPushAction.IGNORE, reason = "stale")
        var route: PlatformTapRoute? = null
        var answerAfterMs = 0L
        var tapAfterMs = 0L
        var failing = false

        override suspend fun updatePushToken(token: PlatformPushToken) {
            tokens += token
        }

        override suspend fun setPushPermission(allowed: Boolean) {
            permissions += allowed
        }

        override suspend fun reconcilePush() {
            reconciled++
        }

        override suspend fun handleRemoteMessage(provider: String, payload: Map<String, String>, budgetMs: Int): PlatformPushOutcome {
            if (answerAfterMs > 0) delay(answerAfterMs)
            if (failing) error("engine unavailable")
            handled += Triple(provider, payload, budgetMs)
            return outcome
        }

        override suspend fun resolveNotificationTap(payload: Map<String, String>): PlatformTapRoute? {
            taps += payload
            if (tapAfterMs > 0) delay(tapAfterMs)
            return route
        }

        override suspend fun totalUnread(): Int = 7
    }

    /** 报更正的宿主：更正流一直开着，测试结束前要 reset 停止收集。 */
    private class CorrectingHost(base: FakeHost = FakeHost()) : FlarePushHost by base {
        val corrections = MutableSharedFlow<PlatformNotificationCorrection>(extraBufferCapacity = 16)

        override fun notificationCorrections() = corrections
    }

    private class FakePresenter : PushPresenter {
        val shown = mutableListOf<Pair<PlatformPushPresentation, Boolean>>()
        val cancelled = mutableListOf<String>()
        var cancelledAll = 0

        override fun show(presentation: PlatformPushPresentation, payload: Map<String, String>, quiet: Boolean) {
            shown += presentation to quiet
        }

        override fun cancel(collapseIds: Collection<String>) {
            cancelled += collapseIds
        }

        override fun cancelAll() {
            cancelledAll++
        }
    }

    private class FakeEnvironment : PushEnvironment {
        var allowed = true
        var metadata = PushTokenMetadata("com.acme.chat", "zh-CN", "Asia/Shanghai", "2.4.0")

        override fun notificationsAllowed(): Boolean = allowed

        override fun tokenMetadata(): PushTokenMetadata = metadata
    }

    private class Fixture(scope: CoroutineScope, host: FlarePushHost?) {
        var host: FlarePushHost? = host
        val presenter = FakePresenter()
        val environment = FakeEnvironment()
        val routes = mutableListOf<PlatformTapRoute>()
        val errors = mutableListOf<Throwable>()
        val coordinator = PushCoordinator(
            hostProvider = { this.host },
            presenter = presenter,
            environment = environment,
            scope = scope,
            onRoute = { routes += it },
            hostTimeoutMs = 3_000,
            resolveTimeoutMs = 15_000,
            wakeBudgetMs = 8_000,
            onError = { errors += it },
        )
    }

    private val payload = mapOf(
        "conversation_id" to "conv-1",
        "collapse_id" to "c:1",
        "thread_id" to "c:1",
        "disposition" to "loud",
        "alert_class" to "normal",
        "seq" to "5",
        "count" to "1",
        "title" to "Alice",
        "body" to "hi",
        "sound" to "1",
    )

    private fun presentation(surface: PlatformPushSurface = PlatformPushSurface.SYSTEM) = PlatformPushPresentation(
        collapseId = "c:1",
        threadId = "c:1",
        conversationId = "conv-1",
        messageId = "m-1",
        seq = 5,
        title = "Alice (rendered)",
        body = "hi",
        count = 1,
        sound = true,
        channel = PlatformPushChannel.MESSAGES,
        surface = surface,
    )

    /** 引擎答复了就照办：载荷与唤醒预算交给它，展示用它渲染的意图。 */
    @Test
    fun theEngineDecidesWhatIsShown() = runTest {
        val host = FakeHost().apply {
            outcome = PlatformPushOutcome(PlatformPushAction.PRESENT, presentation(), clearCollapseIds = listOf("c:old"))
        }
        val fixture = Fixture(this, host)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        assertEquals(listOf(Triple("fcm", payload, 8_000)), host.handled)
        assertEquals(listOf("c:old"), fixture.presenter.cancelled)
        assertEquals(listOf(presentation() to false), fixture.presenter.shown)
    }

    @Test
    fun anUpdateReplacesQuietly() = runTest {
        val host = FakeHost().apply { outcome = PlatformPushOutcome(PlatformPushAction.UPDATE, presentation()) }
        val fixture = Fixture(this, host)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        assertEquals(listOf(presentation() to true), fixture.presenter.shown)
    }

    /** 前台时应用内横幅负责提示，系统通知不重复。 */
    @Test
    fun anInAppSurfacePostsNothing() = runTest {
        val host = FakeHost().apply {
            outcome = PlatformPushOutcome(PlatformPushAction.PRESENT, presentation(PlatformPushSurface.IN_APP))
        }
        val fixture = Fixture(this, host)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        assertTrue(fixture.presenter.shown.isEmpty())
    }

    @Test
    fun aClearAlsoRemovesThePayloadsOwnNotification() = runTest {
        val host = FakeHost().apply { outcome = PlatformPushOutcome(PlatformPushAction.CLEAR) }
        val fixture = Fixture(this, host)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        assertEquals(listOf("c:1"), fixture.presenter.cancelled)
        assertTrue(fixture.presenter.shown.isEmpty())
    }

    @Test
    fun anIgnoredMessageShowsNothing() = runTest {
        val fixture = Fixture(this, FakeHost())

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        assertTrue(fixture.presenter.shown.isEmpty())
        assertTrue(fixture.presenter.cancelled.isEmpty())
    }

    /** 进程被推送拉起、应用还没恢复会话：没有宿主也照样展示。 */
    @Test
    fun withoutAHostThePayloadIsShownAsIs() = runTest {
        val fixture = Fixture(this, null)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        val (shown, quiet) = fixture.presenter.shown.single()
        assertEquals("Alice", shown.title)
        assertEquals("c:1", shown.collapseId)
        assertEquals(false, quiet)
    }

    @Test
    fun aSlowEngineFallsBackToThePayload() = runTest {
        val host = FakeHost().apply {
            answerAfterMs = 5_000
            outcome = PlatformPushOutcome(PlatformPushAction.PRESENT, presentation())
        }
        val fixture = Fixture(this, host)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        assertEquals("Alice", fixture.presenter.shown.single().first.title)
        assertTrue(host.handled.isEmpty())
    }

    @Test
    fun aFailingEngineFallsBackToThePayload() = runTest {
        val host = FakeHost().apply { failing = true }
        val fixture = Fixture(this, host)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        assertEquals("Alice", fixture.presenter.shown.single().first.title)
        assertEquals(1, fixture.errors.size)
    }

    /** 每次 refresh 都报权限（包括拒绝）；令牌只在第一次和附带信息变了时报。 */
    @Test
    fun permissionIsReportedEveryTimeAndTokensOnlyWhenTheyChange() = runTest {
        val host = FakeHost()
        val fixture = Fixture(this, host)

        fixture.coordinator.submitToken("fcm", "tok-1", listOf("dataMessages"))
        advanceUntilIdle()
        fixture.coordinator.refresh()
        advanceUntilIdle()
        fixture.environment.allowed = false
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertEquals(listOf(true, true, false), host.permissions)
        assertEquals(1, host.tokens.size)
        val token = host.tokens.single()
        assertEquals("fcm", token.provider)
        assertEquals("tok-1", token.token)
        assertEquals("android", token.platform)
        assertEquals("com.acme.chat", token.appBundle)
        assertEquals("zh-CN", token.locale)
        assertEquals("Asia/Shanghai", token.timeZone)
        assertEquals("2.4.0", token.appVersion)
        assertEquals(listOf("dataMessages"), token.capabilities)

        fixture.environment.metadata = fixture.environment.metadata.copy(locale = "en-US", timeZone = "Europe/Berlin")
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertEquals(listOf("zh-CN", "en-US"), host.tokens.map { it.locale })
        assertEquals("Europe/Berlin", host.tokens.last().timeZone)
    }

    /** 新令牌到达时只在权限没报过或变了时顺带报权限，不重复对账。 */
    @Test
    fun aNewTokenDoesNotRepeatAnUnchangedPermission() = runTest {
        val host = FakeHost()
        val fixture = Fixture(this, host)

        fixture.coordinator.refresh()
        advanceUntilIdle()
        fixture.coordinator.submitToken("getui", "cid-1", emptyList())
        advanceUntilIdle()

        assertEquals(listOf(true), host.permissions)
        assertEquals(listOf("getui"), host.tokens.map { it.provider })
    }

    /** 宿主换了（重新登录、换了客户端）就全部重报。 */
    @Test
    fun aNewHostGetsEverythingAgain() = runTest {
        val first = FakeHost()
        val fixture = Fixture(this, first)
        fixture.coordinator.submitToken("fcm", "tok-1", emptyList())
        advanceUntilIdle()

        val second = FakeHost()
        fixture.host = second
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertEquals(1, first.tokens.size)
        assertEquals(1, second.tokens.size)
        assertEquals(listOf(true), second.permissions)
    }

    @Test
    fun nothingIsReportedWithoutAHost() = runTest {
        val fixture = Fixture(this, null)

        fixture.coordinator.submitToken("fcm", "tok-1", emptyList())
        fixture.coordinator.refresh()
        advanceUntilIdle()

        val host = FakeHost()
        fixture.host = host
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertEquals(listOf("tok-1"), host.tokens.map { it.token })
        assertEquals(listOf(true), host.permissions)
    }

    /** 点击在宿主就绪前到达：排着，宿主就绪后的 refresh 解析出去向。 */
    @Test
    fun aTapWaitsForTheHost() = runTest {
        val fixture = Fixture(this, null)

        fixture.coordinator.openTap(payload)
        advanceUntilIdle()
        assertTrue(fixture.routes.isEmpty())

        val host = FakeHost().apply { route = PlatformTapRoute("conv-1", "m-1", 5) }
        fixture.host = host
        fixture.coordinator.refresh()
        advanceUntilIdle()
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertEquals(listOf(PlatformTapRoute("conv-1", "m-1", 5)), fixture.routes)
        assertEquals(listOf(payload), host.taps)
    }

    @Test
    fun onlyTheLatestTapIsKept() = runTest {
        val fixture = Fixture(this, null)
        val older = payload + ("conversation_id" to "conv-0")

        fixture.coordinator.openTap(older)
        fixture.coordinator.openTap(payload)
        advanceUntilIdle()
        val host = FakeHost().apply { route = PlatformTapRoute("conv-1") }
        fixture.host = host
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertEquals(listOf(payload), host.taps)
    }

    /** 载荷不属于当前账号：没有去向，也不再重试。 */
    @Test
    fun aTapForAnotherAccountGoesNowhere() = runTest {
        val host = FakeHost()
        val fixture = Fixture(this, host)

        fixture.coordinator.openTap(payload)
        advanceUntilIdle()
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertTrue(fixture.routes.isEmpty())
        assertEquals(1, host.taps.size)
    }

    /** 卡住的宿主按超时报出，只带方法名与上限。 */
    @Test
    fun aStuckHostIsReportedAsATimeout() = runTest {
        val host = FakeHost().apply { answerAfterMs = 60_000 }
        val fixture = Fixture(this, host)

        fixture.coordinator.handleRemoteMessage("fcm", payload)

        val timeout = fixture.errors.single() as FlarePushHostTimeoutException
        assertEquals("handleRemoteMessage", timeout.call)
        assertEquals(3_000L, timeout.limitMs)
        assertEquals("Alice", fixture.presenter.shown.single().first.title)
    }

    /** 应用内换了语言：令牌立刻重报，权限没变就不重报。 */
    @Test
    fun aChangedLocaleRegistersTheTokensAgainWithoutRepeatingThePermission() = runTest {
        val host = FakeHost()
        val fixture = Fixture(this, host)
        fixture.coordinator.submitToken("fcm", "tok-1", emptyList())
        advanceUntilIdle()

        fixture.environment.metadata = fixture.environment.metadata.copy(locale = "en-US")
        fixture.coordinator.syncTokens()
        advanceUntilIdle()

        assertEquals(listOf("zh-CN", "en-US"), host.tokens.map { it.locale })
        assertEquals(listOf(true), host.permissions)
    }

    /** 登出：排队的点击丢掉；报过的全部忘掉，同一个宿主实例也重新登记。 */
    @Test
    fun signingOutDropsTheTapAndForgetsWhatWasSent() = runTest {
        val host = FakeHost().apply { route = PlatformTapRoute("conv-1") }
        val fixture = Fixture(this, null)
        fixture.coordinator.openTap(payload)
        advanceUntilIdle()
        fixture.host = host
        fixture.coordinator.submitToken("fcm", "tok-1", emptyList())
        advanceUntilIdle()

        fixture.coordinator.reset()
        fixture.coordinator.refresh()
        advanceUntilIdle()

        assertTrue(fixture.routes.isEmpty())
        assertTrue(host.taps.isEmpty())
        assertEquals(listOf("tok-1", "tok-1"), host.tokens.map { it.token })
        assertEquals(listOf(true, true), host.permissions)
    }

    /** 解析到一半时登出：结果作废，不能打开上一个账号的会话。 */
    @Test
    fun aTapResolvedAcrossASignOutGoesNowhere() = runTest {
        val host = FakeHost().apply {
            route = PlatformTapRoute("conv-1")
            tapAfterMs = 1_000
        }
        val fixture = Fixture(this, host)

        fixture.coordinator.openTap(payload)
        advanceTimeBy(500)
        fixture.coordinator.reset()
        advanceUntilIdle()

        assertEquals(1, host.taps.size)
        assertTrue(fixture.routes.isEmpty())
    }

    @Test
    fun reconcileAndTotalUnreadGoToTheHost() = runTest {
        val host = FakeHost()
        val fixture = Fixture(this, host)

        fixture.coordinator.reconcile()

        assertEquals(1, host.reconciled)
        assertEquals(7, fixture.coordinator.totalUnread())
        assertEquals(null, Fixture(this, null).coordinator.totalUnread())
    }

    /** 认下的宿主报来的更正照办：按合并键撤、全部撤，角标不做事；换宿主或登出后不再收集旧宿主的更正。 */
    @Test
    fun correctionsFromTheSyncedHostReachThePresenter() = runTest {
        val first = CorrectingHost()
        val fixture = Fixture(this, first)

        fixture.coordinator.refresh()
        advanceUntilIdle()
        first.corrections.emit(PlatformNotificationCorrection.Clear(listOf("c:1", "c:2")))
        first.corrections.emit(PlatformNotificationCorrection.Badge(4))
        first.corrections.emit(PlatformNotificationCorrection.ClearAll)
        advanceUntilIdle()

        assertEquals(listOf("c:1", "c:2"), fixture.presenter.cancelled)
        assertEquals(1, fixture.presenter.cancelledAll)

        val second = CorrectingHost()
        fixture.host = second
        fixture.coordinator.refresh()
        advanceUntilIdle()
        assertEquals(0, first.corrections.subscriptionCount.value)
        first.corrections.emit(PlatformNotificationCorrection.Clear(listOf("c:old")))
        second.corrections.emit(PlatformNotificationCorrection.Clear(listOf("c:3")))
        advanceUntilIdle()
        assertEquals(listOf("c:1", "c:2", "c:3"), fixture.presenter.cancelled)

        fixture.coordinator.reset()
        advanceUntilIdle()
        assertEquals(0, second.corrections.subscriptionCount.value)
        second.corrections.emit(PlatformNotificationCorrection.ClearAll)
        advanceUntilIdle()
        assertEquals(1, fixture.presenter.cancelledAll)
    }
}
