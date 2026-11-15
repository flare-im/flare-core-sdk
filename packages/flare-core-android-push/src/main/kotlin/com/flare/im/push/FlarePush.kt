package com.flare.im.push

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.ColorInt
import androidx.annotation.DrawableRes
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow

/** [FlarePush.install] 的选项。 */
class FlarePushOptions(
    /** 登记 FCM 令牌。只出国内渠道的构建可以关掉；关掉后收到的 FCM 消息照样展示。 */
    val fcm: Boolean = true,
    /** 状态栏小图标，要是单色透明底的图；0 用模块自带的。 */
    @DrawableRes val smallIcon: Int = 0,
    /** 通知的强调色。 */
    @ColorInt val color: Int? = null,
    /** 点击通知打开的页面；null 用应用的启动页。 */
    val launchActivity: Class<out Activity>? = null,
    /** 收到推送时等引擎答复的上限，超过就按载荷展示。与 iOS 模块相同，约三秒。 */
    val hostTimeoutMs: Long = 3_000,
    /** 令牌、权限上报与点击解析等宿主的上限，超过就留到下次回前台。 */
    val resolveTimeoutMs: Long = 15_000,
    /** 交给引擎的后台唤醒预算（FCM 高优先级消息约有十秒执行窗口）。 */
    val wakeBudgetMs: Int = 8_000,
    /** 上报与解析都是尽力而为，失败从这里出去；不含令牌与载荷。 */
    val onError: (Throwable) -> Unit = {},
)

/**
 * Android 平台推送：FCM 消息服务、通知展示器与四个渠道、通知点击、通知权限。
 *
 * 在 `Application.onCreate` 里调 [install]，宿主由 [install] 的 `hostProvider` 按需给出：核心 SDK 的
 * `CorePushHost`，或社交 SDK 的 `FlareSocialPushHost`。没登录、会话还没恢复时给 null，模块照样
 * 展示推送，令牌、权限与点击等登录或恢复后应用调 [refresh] 再报。登出时调 [signOut]。
 *
 * 宿主报来的通知更正（会话读了撤掉、会话结束全撤、角标）模块在宿主就绪期间自己照办，应用不用接线。
 * 链路在线时的后台提示由后台展示器发出（[FlareBackgroundPresenter]）；常驻连接模式关掉推送绑定
 * （[setPushBindingsEnabled]）。
 *
 * 启动页在 `onCreate` 与 `onNewIntent` 里把意图交给 [handleLaunchIntent]，然后收集 [routes] 跳到会话。
 * 通知权限从 [permission] 读，申请走 [FlarePushPermission.request]；后台运行的档位从 [backgroundDelivery] 读。
 */
object FlarePush {
    /** 启动意图里的推送载荷：载荷各键组成的 JSON 对象字符串。厂商通知的点击意图也用这个键。 */
    const val EXTRA_PAYLOAD = "flare_push"

    private val lock = Any()

    @Volatile
    private var runtime: Installation? = null

    // 安装之前就到的令牌与点击（例如应用先初始化了个推）：安装时交给协调器。
    private val earlyTokens = LinkedHashMap<String, PushRawToken>()
    private var earlyTap: Map<String, String>? = null

    @Volatile
    private var localeOverride: String? = null

    private val tapRoutes = Channel<PlatformTapRoute>(Channel.CONFLATED)

    private val permissionState = MutableStateFlow<FlarePushPermissionStatus?>(null)

    private val backgroundState = MutableStateFlow<FlarePushBackgroundDelivery?>(null)

    // 后台展示器与推送绑定：应用的意愿在安装之前也记下，安装时交给协调器。
    @Volatile
    private var presenterRequested = false

    @Volatile
    private var bindingsEnabled = true

    private val presenterState = MutableStateFlow(false)

    /**
     * 点击通知后要去的会话。只缓存最新一条，没人收集时也不丢；同一时间应该只有一个收集者
     * （启动页或导航层）。
     */
    val routes: Flow<PlatformTapRoute> = tapRoutes.receiveAsFlow()

    /**
     * 系统通知权限（三态）。[install] 时读第一次，之后在 [refresh]（授权框有结果后调用）与每次回到前台
     * 重读，变了才更新；[install] 之前为 null。
     */
    val permission: StateFlow<FlarePushPermissionStatus?> = permissionState.asStateFlow()

    /**
     * 后台运行的档位（电池设置里的三档），给「后台接收消息」的引导用。与 [permission] 一样：[install] 时读第一次，
     * 之后在 [refresh] 与每次回到前台重读（用户从电池设置回来就能看到），变了才更新；[install] 之前为 null。
     */
    val backgroundDelivery: StateFlow<FlarePushBackgroundDelivery?> = backgroundState.asStateFlow()

    /** [install] 调过。 */
    val isInstalled: Boolean
        get() = runtime != null

    private class Installation(
        val context: Context,
        val options: FlarePushOptions,
        val notifier: FlarePushNotifier,
        val coordinator: PushCoordinator,
    )

    /**
     * 装上推送模块：建通知渠道、取 FCM 令牌、读权限并上报、读后台运行的档位，并在每次回前台时重读重报权限、
     * 重读档位、补报变了的令牌。再调一次什么都不做。
     */
    fun install(
        application: Application,
        hostProvider: suspend () -> FlarePushHost?,
        options: FlarePushOptions = FlarePushOptions(),
    ) {
        val created = synchronized(lock) {
            if (runtime != null) return
            val notifier = notifier(application, options)
            val coordinator = PushCoordinator(
                hostProvider = hostProvider,
                presenter = notifier,
                environment = AndroidPushEnvironment(application) { localeOverride },
                scope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
                onRoute = { tapRoutes.trySend(it) },
                hostTimeoutMs = options.hostTimeoutMs,
                resolveTimeoutMs = options.resolveTimeoutMs,
                wakeBudgetMs = options.wakeBudgetMs,
                onError = options.onError,
                epochs = StoredPresenterEpochs(application),
                onBackgroundPresenter = { presenterState.value = it },
            )
            Installation(application, options, notifier, coordinator).also { fresh ->
                runtime = fresh
                // 意愿先交给协调器，之后的令牌与点击按它处理（推送绑定关着时令牌不登记）。
                if (!bindingsEnabled) fresh.coordinator.setPushBindings(false)
                if (presenterRequested) fresh.coordinator.setBackgroundPresenter(true)
                for ((provider, token) in earlyTokens) {
                    if (accepts(fresh, provider)) fresh.coordinator.submitToken(provider, token.token, token.capabilities)
                }
                earlyTokens.clear()
                earlyTap?.let { fresh.coordinator.openTap(it) }
                earlyTap = null
            }
        }
        created.notifier.ensureChannels()
        publishSystemState(created.context)
        if (options.fcm) {
            FirebaseTokens.fetch(application, options.onError) { token ->
                submitToken(PlatformPushProviders.FCM, token, listOf(PlatformPushCapabilities.DATA_MESSAGES))
            }
        }
        watchForeground(created)
    }

    /**
     * 启动页在 `onCreate` 与 `onNewIntent` 里调用。意图带着推送载荷（本模块的通知、厂商通知、
     * 中转页）时返回 true，载荷从意图上拿掉，解析出的去向从 [routes] 出来。
     */
    fun handleLaunchIntent(intent: Intent?): Boolean {
        intent ?: return false
        val payload = FlarePushIntents.payload(intent) ?: return false
        FlarePushIntents.consume(intent)
        val current = synchronized(lock) {
            runtime ?: run {
                earlyTap = payload
                null
            }
        }
        current?.coordinator?.openTap(payload)
        return true
    }

    /**
     * 登录成功、会话恢复、权限申请有结果之后调用：重读权限（[permission] 随之更新）并重报，重读后台运行的档位
     * （[backgroundDelivery] 随之更新），补报令牌，解析排队的点击。回前台时模块自己会做一遍。
     */
    fun refresh() {
        val current = runtime ?: return
        publishSystemState(current.context)
        current.coordinator.refresh()
    }

    /**
     * 登出：移除本模块发出的全部通知并把桌面角标归零，丢掉排队的点击（还没解析的、解析到一半的、没人收的去向），
     * 忘掉报过的令牌与权限，下一个账号的宿主重新登记。之后应用的 `hostProvider` 要给 null，直到再次登录。
     * 后台展示器与推送绑定的意愿（[FlareBackgroundPresenter.attach]、[setPushBindingsEnabled]）保留，下一个宿主照办。
     */
    fun signOut() {
        val current = synchronized(lock) {
            earlyTap = null
            runtime
        }
        // 先作废正在解析的点击，再清掉没人收的旧去向：顺序反过来，刚解析完的那条会漏过去。
        current?.coordinator?.reset()
        while (tapRoutes.tryReceive().isSuccess) {
            // 丢掉。
        }
        current?.notifier?.cancelAll()
        current?.notifier?.badge(0)
    }

    /**
     * 推送绑定开还是关，默认开。关掉（常驻连接模式：链路一直在线，不靠推送）：模块不再登记令牌，并在有宿主时对
     * 每个通道（`fcm`、`getui` 与拿到过令牌的）调一次宿主的 `clearPushToken`，撤销服务端已有的绑定；换了宿主
     * 再清一次。打开：对当前宿主重新登记全部令牌。安装前调用也算数；不持久化，应用每次启动按自己的设置调。
     */
    fun setPushBindingsEnabled(enabled: Boolean) {
        val current = synchronized(lock) {
            if (bindingsEnabled == enabled) return
            bindingsEnabled = enabled
            runtime
        }
        current?.coordinator?.setPushBindings(enabled)
    }

    /** 推送绑定开着（[setPushBindingsEnabled]）。 */
    val pushBindingsEnabled: Boolean
        get() = bindingsEnabled

    /** [FlareBackgroundPresenter.attached] 的来源。 */
    internal val backgroundPresenterState: StateFlow<Boolean> = presenterState.asStateFlow()

    /** [FlareBackgroundPresenter.isRequested] 的来源。 */
    internal val backgroundPresenterRequested: Boolean
        get() = presenterRequested

    /** [FlareBackgroundPresenter.attach] 与 [FlareBackgroundPresenter.detach]：记下意愿，装上了就交给协调器。 */
    internal fun requestBackgroundPresenter(wanted: Boolean) {
        val current = synchronized(lock) {
            if (presenterRequested == wanted) return
            presenterRequested = wanted
            runtime
        }
        current?.coordinator?.setBackgroundPresenter(wanted)
    }

    /**
     * 应用内选的语言（BCP 47，例如 `zh-CN`），令牌登记用它代替系统语言：服务端兜底文案要和界面一致。
     * 变了立刻重新登记，不等回到前台；null 或空白回到系统语言。安装前调用也算数。
     */
    fun setLocale(languageTag: String?) {
        val tag = languageTag?.trim()?.takeIf { it.isNotEmpty() && it != "und" }
        val changed = synchronized(lock) {
            if (localeOverride == tag) {
                false
            } else {
                localeOverride = tag
                true
            }
        }
        if (changed) runtime?.coordinator?.syncTokens()
    }

    /**
     * 撤掉这些合并键的通知（通知的 tag）。宿主报来的更正模块自己照办，应用不用调；没装上时什么也不做。
     */
    fun clearNotifications(collapseIds: Collection<String>) {
        runtime?.notifier?.cancel(collapseIds)
    }

    /** 撤掉本模块发出的全部通知，应用自己的其它通知不动。没装上时什么也不做。 */
    fun clearAllNotifications() {
        runtime?.notifier?.cancelAll()
    }

    /** 对账推送绑定，例如网络恢复时。 */
    suspend fun reconcile() {
        runtime?.coordinator?.reconcile()
    }

    /** 当前未读总数；没有宿主时为 null。 */
    suspend fun totalUnread(): Int? = runtime?.coordinator?.totalUnread()

    /** 这个构建与设备上 FCM 能不能用：没打包 `google-services.json`（Firebase 没初始化）时为 false。 */
    fun isFcmAvailable(context: Context): Boolean = FirebaseTokens.available(context)

    /**
     * 推送通道模块（本模块的 FCM 服务、个推模块）拿到或更换了令牌时调用。令牌不进日志。
     */
    fun submitToken(provider: String, token: String, capabilities: List<String> = emptyList()) {
        if (token.isBlank()) return
        val current = synchronized(lock) {
            runtime ?: run {
                earlyTokens[provider] = PushRawToken(token, capabilities)
                null
            }
        } ?: return
        if (accepts(current, provider)) current.coordinator.submitToken(provider, token, capabilities)
    }

    /**
     * 推送通道模块收到数据消息时调用，在调用方的线程上挂起，最长约 [FlarePushOptions.hostTimeoutMs]（三秒）。
     * 模块还没装上时（应用没在 `Application.onCreate` 里调 [install]）按载荷原样展示。
     */
    suspend fun handleRemoteMessage(context: Context, provider: String, payload: Map<String, String>) {
        if (payload.isEmpty()) return
        val current = runtime
        if (current != null) {
            current.coordinator.handleRemoteMessage(provider, payload)
            return
        }
        val notifier = notifier(context, FlarePushOptions())
        applyOutcome(FlarePushPayload.fallbackOutcome(payload), payload, notifier)
    }

    /** 中转页与通知点击用：点击打开的页面。 */
    internal fun launchActivity(): Class<out Activity>? = runtime?.options?.launchActivity

    private fun accepts(current: Installation, provider: String): Boolean =
        provider != PlatformPushProviders.FCM || current.options.fcm

    private fun notifier(context: Context, options: FlarePushOptions): FlarePushNotifier = FlarePushNotifier(
        context = context,
        smallIcon = options.smallIcon.takeIf { it != 0 } ?: R.drawable.flare_push_ic_notification,
        color = options.color,
        launchActivity = options.launchActivity,
    )

    /** 重读三态权限与后台运行的档位；与上次相同时 [permission]、[backgroundDelivery] 不变。 */
    private fun publishSystemState(context: Context) {
        permissionState.value = FlarePushPermission.status(context)
        backgroundState.value = FlareBackgroundRestrictions.delivery(context)
    }

    /**
     * 回前台时重读重报。进程被推送拉起、没有界面时不会回前台，安装时就报一次；有界面时添加观察者
     * 会立刻收到一次 onStart，不再另报。
     */
    private fun watchForeground(current: Installation) {
        Handler(Looper.getMainLooper()).post {
            val lifecycle = ProcessLifecycleOwner.get().lifecycle
            val started = lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
            lifecycle.addObserver(
                object : DefaultLifecycleObserver {
                    override fun onStart(owner: LifecycleOwner) {
                        current.notifier.ensureChannels()
                        publishSystemState(current.context)
                        current.coordinator.refresh()
                    }
                },
            )
            if (!started) current.coordinator.refresh()
        }
    }
}

/** 从系统读通知权限与令牌附带的设备信息；[localeOverride] 是应用内选的语言，有就用它。 */
internal class AndroidPushEnvironment(
    context: Context,
    private val localeOverride: () -> String?,
) : PushEnvironment {
    private val context = context.applicationContext ?: context

    override fun notificationsAllowed(): Boolean =
        runCatching { NotificationManagerCompat.from(context).areNotificationsEnabled() }.getOrDefault(false)

    override fun tokenMetadata(): PushTokenMetadata = PushTokenMetadata(
        appBundle = context.packageName,
        locale = localeOverride() ?: Locale.getDefault().toLanguageTag().takeIf { it.isNotBlank() && it != "und" },
        timeZone = TimeZone.getDefault().id,
        appVersion = appVersion(),
    )

    @Suppress("DEPRECATION")
    private fun appVersion(): String? = runCatching {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(0L))
        } else {
            context.packageManager.getPackageInfo(context.packageName, 0)
        }
        info.versionName
    }.getOrNull()?.takeIf { it.isNotBlank() }
}
