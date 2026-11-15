package com.flare.im.push

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeout

/** 把展示意图落成系统通知的一方；Android 上是 [FlarePushNotifier]。 */
internal interface PushPresenter {
    /** 展示或替换 [presentation.collapseId] 那条通知；[quiet] 时只提示一次、不响铃。点击时带回 [payload]。 */
    fun show(presentation: PlatformPushPresentation, payload: Map<String, String>, quiet: Boolean)

    fun cancel(collapseIds: Collection<String>)

    /** 移除本模块发出的全部通知，应用自己的其它通知不动。 */
    fun cancelAll()

    /** 桌面图标角标的绝对值；桌面没有角标接口时什么都不做（计数来自通知本身）。 */
    fun badge(count: Int) {}
}

/** 令牌登记时随令牌上报的设备信息；变了要重报。 */
internal data class PushTokenMetadata(
    val appBundle: String?,
    val locale: String?,
    val timeZone: String?,
    val appVersion: String?,
)

/** 平台状态的读取口，测试里换成假的。 */
internal interface PushEnvironment {
    fun notificationsAllowed(): Boolean

    fun tokenMetadata(): PushTokenMetadata
}

/** 推送通道交来的原始令牌。 */
internal data class PushRawToken(val token: String, val capabilities: List<String>) {
    override fun toString(): String = "PushRawToken(capabilities=$capabilities)"
}

/**
 * 按引擎答复（拿不到就按载荷）处理一条推送：先移除要清的，再展示或静默替换。
 * 应用在前台时展示面是应用内横幅，这里不再发系统通知。
 */
internal fun applyOutcome(outcome: PlatformPushOutcome, payload: Map<String, String>, presenter: PushPresenter) {
    val cleared = LinkedHashSet(outcome.clearCollapseIds)
    if (outcome.action == PlatformPushAction.CLEAR) {
        // 清除指令也覆盖这条载荷自己的合并键，引擎没列出来时也不残留。
        outcome.presentation?.collapseId?.let(cleared::add)
        payload[FlarePushPayload.COLLAPSE_ID]?.takeIf(String::isNotBlank)?.let(cleared::add)
    }
    if (cleared.isNotEmpty()) presenter.cancel(cleared)
    // 角标是绝对值，知道就设：有角标接口的桌面用它，其它桌面的计数来自通知本身。
    outcome.badge?.takeIf { it >= 0 }?.let(presenter::badge)
    val presentation = outcome.presentation ?: return
    if (presentation.surface != PlatformPushSurface.SYSTEM) return
    when (outcome.action) {
        PlatformPushAction.PRESENT -> presenter.show(presentation, payload, quiet = false)
        PlatformPushAction.UPDATE -> presenter.show(presentation, payload, quiet = true)
        PlatformPushAction.CLEAR, PlatformPushAction.BADGE_ONLY, PlatformPushAction.IGNORE -> Unit
    }
}

/**
 * 推送模块的全部决策，不碰 Android 类型：远程消息、令牌与权限上报、通知点击。
 *
 * 宿主按需向 [hostProvider] 要：被推送冷启动的进程里应用可能还在初始化，没登录或会话没恢复时
 * 它给 null。远程消息只等 [hostTimeoutMs]，等不到就按载荷展示；令牌、权限与点击每次调用不超过
 * [resolveTimeoutMs]，等不到就留着，下次回前台或应用调 [refresh] 时再报。超时都经 [onError] 报出
 * [FlarePushHostTimeoutException]。
 *
 * 同步时认下的宿主（[syncedHost]）报来的通知更正一直收集着、照办；换了宿主或登出时停止收集。
 *
 * 后台展示器（[setBackgroundPresenter]）：应用要、有宿主、能展示通知三样齐了才告诉宿主接上，缺一样告诉它断开；
 * 每次同步重新判断，换了宿主重报。接上期间宿主交来的展示面为 `system` 的提示由 [presenter] 发出，点击载荷带
 * [epochs] 的凭据（[LocalPresentations]）。实际状态经 [onBackgroundPresenter] 报出。
 *
 * 推送绑定（[setPushBindings]）：关掉时不再登记令牌，并对每个通道调一次宿主的 `clearPushToken`（常驻连接模式）。
 */
internal class PushCoordinator(
    private val hostProvider: suspend () -> FlarePushHost?,
    private val presenter: PushPresenter,
    private val environment: PushEnvironment,
    private val scope: CoroutineScope,
    private val onRoute: (PlatformTapRoute) -> Unit,
    private val hostTimeoutMs: Long,
    private val resolveTimeoutMs: Long,
    private val wakeBudgetMs: Int,
    private val onError: (Throwable) -> Unit,
    private val epochs: PresenterEpochs = MemoryPresenterEpochs(),
    private val onBackgroundPresenter: (Boolean) -> Unit = {},
) {
    private val lock = Any()
    private val syncLock = Mutex()
    private val tapLock = Mutex()
    private val tokens = LinkedHashMap<String, PushRawToken>()

    // 下面几项只对 syncedHost 有效：换了宿主（重新登录、换了客户端）或登出就要全部重报。
    private var syncedHost: FlarePushHost? = null
    private val sentTokens = HashMap<String, PlatformPushToken>()
    private var sentPermission: Boolean? = null

    // 对 syncedHost 报过的后台展示器状态；null 是还没报过。宿主不支持时记下，不再每次重试。
    private var presenterTold: Boolean? = null
    private var presenterUnsupported = false

    // 关掉推送绑定后已经对 syncedHost 清过的通道。
    private val clearedProviders = HashSet<String>()

    // 应用的意愿，跨宿主、跨登出保留。
    private var presenterWanted = false
    private var presenterEverWanted = false
    private var bindingsEnabled = true

    private var pendingTap: Map<String, String>? = null

    // 收集 syncedHost 通知更正与链路提示的协程。
    private var corrections: Job? = null

    // 每次登出加一：登出前开始解析的点击，结果不再发出去。
    private var tapEpoch = 0L

    /** 一条远程推送：引擎在 [hostTimeoutMs] 内答复就照办，否则按载荷原样展示。 */
    suspend fun handleRemoteMessage(provider: String, payload: Map<String, String>): PlatformPushOutcome {
        val outcome = withHost(HANDLE_REMOTE_MESSAGE, hostTimeoutMs) { host ->
            host.handleRemoteMessage(provider, payload, wakeBudgetMs)
        } ?: FlarePushPayload.fallbackOutcome(payload)
        applyOutcome(outcome, payload, presenter)
        return outcome
    }

    /** 推送通道拿到（或换了）令牌。 */
    fun submitToken(provider: String, token: String, capabilities: List<String>): Job {
        synchronized(lock) { tokens[provider] = PushRawToken(token, capabilities) }
        return scope.launch { sync(reportPermission = false) }
    }

    /** 安装时、回前台时、应用登录或恢复会话后：重报权限，补报变了的令牌，处理排队的点击。 */
    fun refresh(): Job = scope.launch {
        sync(reportPermission = true)
        resolvePendingTap()
    }

    /** 令牌附带的信息（例如应用内的语言）变了：补报变了的令牌，权限没变就不重报。 */
    fun syncTokens(): Job = scope.launch { sync(reportPermission = false) }

    /** 应用要不要后台展示器；有宿主时在这次同步里告诉它。 */
    fun setBackgroundPresenter(wanted: Boolean): Job {
        synchronized(lock) {
            presenterWanted = wanted
            if (wanted) presenterEverWanted = true
        }
        return scope.launch { sync(reportPermission = false) }
    }

    /**
     * 推送绑定开还是关。关掉：不再登记令牌，对每个通道清一次绑定；打开：对当前宿主重新登记全部令牌。
     */
    fun setPushBindings(enabled: Boolean): Job {
        synchronized(lock) {
            if (bindingsEnabled != enabled) {
                bindingsEnabled = enabled
                clearedProviders.clear()
                sentTokens.clear()
            }
        }
        return scope.launch { sync(reportPermission = false) }
    }

    /**
     * 登出：丢掉排队的点击，作废正在解析的点击，忘掉报过的令牌、权限与后台展示器状态，换掉本模块通知的点击凭据。
     * 下一个宿主（哪怕还是同一个实例）全部重报。应用对后台展示器与推送绑定的意愿保留。
     */
    fun reset() {
        val following = synchronized(lock) {
            pendingTap = null
            tapEpoch++
            syncedHost = null
            sentTokens.clear()
            sentPermission = null
            presenterTold = null
            presenterUnsupported = false
            clearedProviders.clear()
            corrections.also { corrections = null }
        }
        following?.cancel()
        epochs.rotate()
        onBackgroundPresenter(false)
    }

    /** 点击通知打开了应用。只排一条，新点击顶掉旧的；宿主就绪后解析成去向。 */
    fun openTap(payload: Map<String, String>): Job {
        synchronized(lock) { pendingTap = payload }
        return scope.launch { resolvePendingTap() }
    }

    suspend fun reconcile() {
        withHost(RECONCILE_PUSH, resolveTimeoutMs) { host -> host.reconcilePush() }
    }

    suspend fun totalUnread(): Int? = withHost(TOTAL_UNREAD, hostTimeoutMs) { host -> host.totalUnread() }

    internal suspend fun sync(reportPermission: Boolean) {
        syncLock.withLock { syncLocked(reportPermission) }
    }

    private suspend fun syncLocked(reportPermission: Boolean) {
        val host = withHost(HOST_PROVIDER, resolveTimeoutMs) { it } ?: return
        val allowed = environment.notificationsAllowed()
        val metadata = environment.tokenMetadata()
        val state = synchronized(lock) {
            if (host !== syncedHost) {
                syncedHost = host
                sentTokens.clear()
                sentPermission = null
                presenterTold = null
                presenterUnsupported = false
                clearedProviders.clear()
                followCorrectionsLocked(host)
            }
            SyncState(
                tokens = tokens.toMap(),
                permissionDue = reportPermission || sentPermission != allowed,
                presenter = presenterDueLocked(presenterWanted && allowed),
                bindingsEnabled = bindingsEnabled,
            )
        }
        // 权限在前：引擎的权限默认是关，先报权限，令牌那一轮对账就能直接登记。
        if (state.permissionDue && bounded(SET_PUSH_PERMISSION) { host.setPushPermission(allowed) } != null) {
            synchronized(lock) { if (syncedHost === host) sentPermission = allowed }
        }
        state.presenter?.let { attached -> tellPresenter(host, attached) }
        if (state.bindingsEnabled) registerTokens(host, state.tokens, metadata) else clearBindings(host, state.tokens.keys)
    }

    /** 一次同步要做的事，在锁里一次读出。 */
    private class SyncState(
        val tokens: Map<String, PushRawToken>,
        val permissionDue: Boolean,
        /** 要告诉宿主的后台展示器状态；null 是不用报。 */
        val presenter: Boolean?,
        val bindingsEnabled: Boolean,
    )

    /**
     * 在锁里调用：这次同步要不要把 [desired] 报给宿主，要报时返回它。没报过的宿主：要接上就报；不接上时只在应用要过
     * 后台展示器的情况下报一次断开（引擎默认就是断开，但同一个客户端可能还记着上一个宿主报的接上）。
     */
    private fun presenterDueLocked(desired: Boolean): Boolean? = when {
        presenterUnsupported -> null
        presenterTold == null -> desired.takeIf { desired || presenterEverWanted }
        presenterTold != desired -> desired
        else -> null
    }

    /** 告诉 [host] 后台展示器接上或断开；答复了才算数，失败留到下次同步。宿主不支持时记下，不再重试。 */
    private suspend fun tellPresenter(host: FlarePushHost, attached: Boolean) {
        val supported = bounded(SET_BACKGROUND_PRESENTER) { supported { host.setBackgroundPresenter(attached) } } ?: return
        synchronized(lock) {
            if (syncedHost !== host) return
            if (!supported) {
                presenterUnsupported = true
                return
            }
            presenterTold = attached
        }
        onBackgroundPresenter(attached)
    }

    /**
     * 推送绑定关着：不登记令牌，每个通道（已知的与拿到过令牌的）对 [host] 清一次。失败的下次同步再清；宿主不支持时
     * 当作清过，不再重试。
     */
    private suspend fun clearBindings(host: FlarePushHost, seen: Set<String>) {
        val providers = LinkedHashSet(KNOWN_PROVIDERS).apply { addAll(seen) }
        for (provider in providers) {
            if (synchronized(lock) { provider in clearedProviders }) continue
            if (bounded(CLEAR_PUSH_TOKEN) { supported { host.clearPushToken(provider) } } != null) {
                synchronized(lock) { if (syncedHost === host) clearedProviders += provider }
            }
        }
    }

    /** 宿主没实现这个可选方法（默认实现抛 [UnsupportedOperationException]）时为 false，其余错误照常抛出。 */
    private suspend fun supported(block: suspend () -> Unit): Boolean = try {
        block()
        true
    } catch (unsupported: UnsupportedOperationException) {
        false
    }

    private suspend fun registerTokens(host: FlarePushHost, snapshot: Map<String, PushRawToken>, metadata: PushTokenMetadata) {
        for ((provider, raw) in snapshot) {
            val desired = PlatformPushToken(
                provider = provider,
                token = raw.token,
                appBundle = metadata.appBundle,
                locale = metadata.locale,
                timeZone = metadata.timeZone,
                appVersion = metadata.appVersion,
                capabilities = raw.capabilities,
            )
            if (synchronized(lock) { sentTokens[provider] } == desired) continue
            if (bounded(UPDATE_PUSH_TOKEN) { host.updatePushToken(desired) } != null) {
                synchronized(lock) { if (syncedHost === host) sentTokens[provider] = desired }
            }
        }
    }

    /**
     * 在锁里调用：改为收集 [host] 的更正与提示，上一个宿主的收集取消。收集出错只报告，不重试：下次换宿主再收。
     * 两路各自出错，互不牵连。
     */
    private fun followCorrectionsLocked(host: FlarePushHost) {
        corrections?.cancel()
        corrections = scope.launch {
            launch {
                reporting {
                    host.notificationCorrections().collect { correction ->
                        if (synchronized(lock) { syncedHost === host }) applyCorrection(correction)
                    }
                }
            }
            launch {
                reporting {
                    host.notificationPresentations().collect { presentation -> presentLocal(host, presentation) }
                }
            }
        }
    }

    private suspend fun reporting(block: suspend () -> Unit) {
        try {
            block()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Throwable) {
            onError(error)
        }
    }

    private fun applyCorrection(correction: PlatformNotificationCorrection) {
        when (correction) {
            is PlatformNotificationCorrection.Clear -> presenter.cancel(correction.collapseIds)
            PlatformNotificationCorrection.ClearAll -> {
                presenter.cancelAll()
                // 会话结束：之前发出的本模块通知（已经撤掉，或用户没来得及看到的）点开后不再路由。
                epochs.rotate()
            }
            is PlatformNotificationCorrection.Badge -> presenter.badge(correction.count.coerceAtLeast(0))
        }
    }

    /**
     * 引擎在链路上决定的一条提示：后台展示器对 [host] 接上时，展示面为 `system` 的发成系统通知，`inApp` 的归应用内
     * 横幅。通知权限这时已经没了：通知发不出去，同步一次让引擎知道断开了，提示改走服务端推送。
     */
    private fun presentLocal(host: FlarePushHost, presentation: PlatformPushPresentation) {
        if (presentation.surface != PlatformPushSurface.SYSTEM) return
        if (synchronized(lock) { syncedHost !== host || presenterTold != true }) return
        if (!environment.notificationsAllowed()) {
            syncTokens()
            return
        }
        // 没有声音的是静默替换或静默提示：只提示一次、不响铃，与推送的 update 相同。
        presenter.show(presentation, LocalPresentations.tapPayload(presentation, epochs.current()), quiet = !presentation.sound)
    }

    internal suspend fun resolvePendingTap() {
        tapLock.withLock { resolvePendingTapLocked() }
    }

    private suspend fun resolvePendingTapLocked() {
        val (payload, epoch) = synchronized(lock) { pendingTap?.let { it to tapEpoch } } ?: return
        // 宿主还没就绪：点击留着，等登录或会话恢复后的 refresh。
        val host = withHost(HOST_PROVIDER, resolveTimeoutMs) { it } ?: return
        // 本模块自己发的通知（后台展示器）由凭据认账号，不经引擎；其余的由引擎核对属于当前账号。
        // 解析失败或超时不重试：坏载荷会在每次回前台都失败一遍。
        val local = LocalPresentations.tap(payload, epochs.current())
        val route = if (local != null) local.route else bounded(RESOLVE_NOTIFICATION_TAP) { host.resolveNotificationTap(payload) }
        val current = synchronized(lock) {
            if (pendingTap === payload) pendingTap = null
            tapEpoch == epoch
        }
        // 解析期间登出了：不能把上一个账号的会话打开。
        if (current) route?.let(onRoute)
    }

    /** 拿到宿主并调用它，整段不超过 [timeoutMs]；没有宿主、超时或出错都是 null，超时与出错报给 onError。 */
    private suspend fun <T> withHost(call: String, timeoutMs: Long, block: suspend (FlarePushHost) -> T): T? =
        guarded(call, timeoutMs) { hostProvider()?.let { block(it) } }

    /** 调一次宿主，不超过 [resolveTimeoutMs]；超时或出错都是 null。 */
    private suspend fun <T> bounded(call: String, block: suspend () -> T): T? = guarded(call, resolveTimeoutMs, block)

    private suspend fun <T> guarded(call: String, timeoutMs: Long, block: suspend () -> T): T? = try {
        withTimeout(timeoutMs) { block() }
    } catch (timeout: TimeoutCancellationException) {
        onError(FlarePushHostTimeoutException(call, timeoutMs))
        null
    } catch (cancelled: CancellationException) {
        throw cancelled
    } catch (error: Throwable) {
        onError(error)
        null
    }

    private companion object {
        const val HOST_PROVIDER = "hostProvider"
        const val HANDLE_REMOTE_MESSAGE = "handleRemoteMessage"
        const val SET_PUSH_PERMISSION = "setPushPermission"
        const val UPDATE_PUSH_TOKEN = "updatePushToken"
        const val RECONCILE_PUSH = "reconcilePush"
        const val RESOLVE_NOTIFICATION_TAP = "resolveNotificationTap"
        const val TOTAL_UNREAD = "totalUnread"
        const val SET_BACKGROUND_PRESENTER = "setBackgroundPresenter"
        const val CLEAR_PUSH_TOKEN = "clearPushToken"

        /** 推送绑定关掉时要清的通道：Android 上的两个，外加拿到过令牌的。 */
        val KNOWN_PROVIDERS = listOf(PlatformPushProviders.FCM, PlatformPushProviders.GETUI)
    }
}
