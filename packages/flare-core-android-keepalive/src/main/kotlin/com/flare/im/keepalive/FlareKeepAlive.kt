package com.flare.im.keepalive

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.annotation.ColorInt
import androidx.annotation.DrawableRes
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 常驻连接的宿主：应用在这里把前台服务的开始与结束接到自己的会话上。回调在主线程上。
 *
 * 应用的接法：开始时不登记推送绑定（对每个推送通道调 `clearPushToken`，平台推送模块的
 * `FlarePush.setPushBindingsEnabled(false)` 替它做）、接上后台展示器（`FlareBackgroundPresenter.attach()`），
 * 并让进程级的客户端恢复会话、保持在线；结束且开关已关时反过来。
 */
interface FlareKeepAliveHost {
    /** 前台服务开始运行：用户刚打开、开机或应用更新后自启、进程被回收后重建。 */
    fun onKeepAliveStarted()

    /** 前台服务停了：用户关掉常驻连接，或系统停掉了它。开关是否还开着看 [FlareKeepAlive.isEnabled]。 */
    fun onKeepAliveStopped()
}

/** [FlareKeepAlive.install] 的选项。 */
class FlareKeepAliveOptions(
    /** 常驻通知的状态栏小图标，要是单色透明底的图；0 用模块自带的。 */
    @DrawableRes val smallIcon: Int = 0,
    /** 常驻通知的强调色。 */
    @ColorInt val color: Int? = null,
    /** 常驻通知的标题；null 用应用名。 */
    val title: String? = null,
    /** 常驻通知的正文；null 用模块的文案（随系统语言）。 */
    val text: String? = null,
    /** 点常驻通知打开的页面；null 用应用的启动页。 */
    val launchActivity: Class<out Activity>? = null,
    /** 系统不让启动或进入前台时从这里报出；不含任何账号与消息内容。 */
    val onError: (Throwable) -> Unit = {},
)

/**
 * Android 常驻连接模式（可选，默认关）：一个 `specialUse`（子类型 `im-persistent-connection`）前台服务加一条低重要级
 * 的常驻通知（渠道 `flare.keepalive`），让应用退到后台后进程与链路一直在。只面向没有任何推送通道的部署；上架应用商店
 * 的应用不应启用。
 *
 * 开关由模块记下：[start] 打开并启动服务，[stop] 关掉并停掉服务，[isEnabled] 读它。开着时开机与应用更新后自启，
 * 进程重建时（[install]）与每次回到前台时补启动；关着时什么都不启动。服务的开始与结束交给 [FlareKeepAliveHost]，
 * 运行状态从 [running] 读。电池优化的引导在 [FlareKeepAliveBattery]：模块只打开设置页，从不静默申请豁免。
 *
 * 在 `Application.onCreate`（主进程）里调 [install]，开机、更新后的自启也走到这里，宿主在那时就在。
 */
object FlareKeepAlive {
    /** 常驻通知的渠道。 */
    const val CHANNEL_ID = "flare.keepalive"

    /** 前台服务的 specialUse 子类型，与清单里的声明相同。 */
    const val SPECIAL_USE_SUBTYPE = "im-persistent-connection"

    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()

    @Volatile
    internal var options: FlareKeepAliveOptions = FlareKeepAliveOptions()
        private set

    @Volatile
    private var host: FlareKeepAliveHost? = null

    private var installed = false

    private val runningState = MutableStateFlow(false)

    // 最后交给宿主的状态，只在主线程上读写；换宿主时清掉。没告诉过「开始」就不告诉「结束」。
    private var announced: Boolean? = null

    /** 前台服务在运行。 */
    val running: StateFlow<Boolean> = runningState.asStateFlow()

    /**
     * 记下选项与宿主；开关开着就启动服务（进程在后台被拉起、系统不让启动时，回到前台再补）。再调一次只换选项与宿主。
     */
    fun install(
        application: Application,
        options: FlareKeepAliveOptions = FlareKeepAliveOptions(),
        host: FlareKeepAliveHost? = null,
    ) {
        val first = synchronized(lock) {
            this.options = options
            (!installed).also { installed = true }
        }
        setHost(host)
        if (!first) return
        if (isEnabled(application)) launch(application)
        main.post {
            ProcessLifecycleOwner.get().lifecycle.addObserver(
                object : DefaultLifecycleObserver {
                    override fun onStart(owner: LifecycleOwner) {
                        if (isEnabled(application) && !runningState.value) launch(application)
                    }
                },
            )
        }
    }

    /** 换宿主；服务已经在运行时新宿主马上收到 [FlareKeepAliveHost.onKeepAliveStarted]。null 是不再通知。 */
    fun setHost(host: FlareKeepAliveHost?) {
        this.host = host
        main.post {
            announced = null
            deliver()
        }
    }

    /** 常驻连接的开关（模块记下的）；默认关。 */
    fun isEnabled(context: Context): Boolean = KeepAlivePreferences.enabled(context)

    /**
     * 打开常驻连接：记下开关并启动前台服务。返回系统有没有接受启动请求；应用在后台时可能不接受，回到前台会再试。
     */
    fun start(context: Context): Boolean {
        KeepAlivePreferences.setEnabled(context, true)
        return launch(context)
    }

    /** 关掉常驻连接：记下开关并停掉前台服务，常驻通知随之消失。 */
    fun stop(context: Context) {
        KeepAlivePreferences.setEnabled(context, false)
        try {
            context.stopService(Intent(context, FlareKeepAliveService::class.java))
        } catch (error: RuntimeException) {
            options.onError(error)
        }
    }

    /** 开机、应用更新：开关开着才启动。 */
    internal fun restore(context: Context) {
        if (isEnabled(context)) launch(context)
    }

    private fun launch(context: Context): Boolean = try {
        ContextCompat.startForegroundService(context, Intent(context, FlareKeepAliveService::class.java))
        true
    } catch (error: RuntimeException) {
        // Android 12 起应用在后台时系统可能不让启动前台服务（ForegroundServiceStartNotAllowedException）。
        options.onError(error)
        false
    }

    internal fun serviceStarted() {
        runningState.value = true
        main.post { deliver() }
    }

    internal fun serviceStopped() {
        runningState.value = false
        main.post { deliver() }
    }

    /** 在主线程上：把当前运行状态告诉宿主，同一状态只说一次。 */
    private fun deliver() {
        val target = host ?: return
        val current = runningState.value
        if (announced == current || (announced == null && !current)) return
        announced = current
        if (current) target.onKeepAliveStarted() else target.onKeepAliveStopped()
    }
}

/** 开机与应用更新的广播里，哪些要按开关重新启动服务。 */
internal fun restartsOn(action: String?, enabled: Boolean): Boolean =
    enabled && (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED)

/** 模块自己的开关，存在单独的偏好文件里。读写失败按关处理：宁可不常驻，也不在用户没打开时常驻。 */
internal object KeepAlivePreferences {
    private const val FILE = "com.flare.im.keepalive"
    private const val ENABLED = "enabled"

    fun enabled(context: Context): Boolean =
        runCatching { preferences(context).getBoolean(ENABLED, false) }.getOrDefault(false)

    fun setEnabled(context: Context, enabled: Boolean) {
        runCatching { preferences(context).edit().putBoolean(ENABLED, enabled).apply() }
    }

    private fun preferences(context: Context) =
        (context.applicationContext ?: context).getSharedPreferences(FILE, Context.MODE_PRIVATE)
}
