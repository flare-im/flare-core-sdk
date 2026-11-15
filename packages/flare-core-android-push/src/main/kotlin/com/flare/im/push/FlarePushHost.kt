package com.flare.im.push

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

/**
 * 推送模块与引擎之间的宿主适配器。
 *
 * 推送模块不依赖任何引擎包：核心 SDK 提供 `CorePushHost`（包在核心客户端上），社交应用提供
 * `com.flare.social.app.ffi.FlareSocialPushHost`（经社交 SDK 的 IM 透传）。所有方法都可能抛错，模块按尽力而为处理：
 * 令牌与权限下次回前台重报，远程消息改用载荷原样展示。模块给每次调用设上限（远程消息约 3 秒，其余约 15 秒），
 * 超时的调用会被取消。
 */
interface FlarePushHost {
    /** 登记或更新一个推送令牌（`sdk.update_push_token`）。 */
    suspend fun updatePushToken(token: PlatformPushToken)

    /** 上报系统通知权限，拒绝与撤销也要报（`sdk.set_push_permission`）。 */
    suspend fun setPushPermission(allowed: Boolean)

    /** 对账推送绑定（`sdk.reconcile_push`）。 */
    suspend fun reconcilePush()

    /**
     * 远程推送的无界面入口（`sdk.handle_remote_message`）：引擎在约 150ms 内给出展示意图，
     * [budgetMs] 大于 0 时它另起一次有界的后台唤醒，不阻塞这次返回。
     */
    suspend fun handleRemoteMessage(provider: String, payload: Map<String, String>, budgetMs: Int): PlatformPushOutcome

    /** 点击通知后解析去向（`sdk.resolve_notification_tap`）；载荷不属于当前账号时为 null。 */
    suspend fun resolveNotificationTap(payload: Map<String, String>): PlatformTapRoute?

    /** 当前未读总数，口径与角标一致（`conversation.total_unread`）。 */
    suspend fun totalUnread(): Int

    /**
     * 引擎对已经发出的通知的更正（`notification.clear`、`notification.badge`）。模块在这个宿主就绪期间收集它，
     * 换了宿主或登出时取消收集；实现随收集结束退掉对引擎事件的订阅（例如 `callbackFlow` 的 `awaitClose`）。
     * 经方法通道转发的 Flutter 宿主也覆盖它：Dart 把引擎的事件转过来，插件交给这个流。没有引擎事件的宿主（测试）
     * 用默认的空流。
     */
    fun notificationCorrections(): Flow<PlatformNotificationCorrection> = emptyFlow()

    /**
     * 链路在线时引擎要展示的通知（`notification.present`），原样交出，展示面由模块看：只有 `system` 的由后台展示器
     * （[FlareBackgroundPresenter]）发成系统通知，`inApp` 的归应用内横幅。收集的时机与退订同
     * [notificationCorrections]。标题与正文是消息预览，实现不能写进日志。不经引擎事件的宿主用默认的空流。
     */
    fun notificationPresentations(): Flow<PlatformPushPresentation> = emptyFlow()

    /**
     * 告诉引擎本模块在应用退到后台时替它发系统通知（`notification.set_background_presenter`）：为 true 时引擎在后台
     * 照常确认、自己出提示（`notification.present` 的展示面为 `system`），为 false 时后台提示交给服务端推送。
     * 不登录也能调。默认实现抛 [UnsupportedOperationException]：不支持的宿主上后台展示器一直没接上。
     */
    suspend fun setBackgroundPresenter(attached: Boolean) {
        throw UnsupportedOperationException("setBackgroundPresenter")
    }

    /**
     * 撤掉这个通道的推送绑定（`sdk.clear_push_token`）：引擎忘掉它的令牌，并在服务端撤销已有的绑定。常驻连接模式下
     * 模块对每个通道调一次（[FlarePush.setPushBindingsEnabled]）。默认实现抛 [UnsupportedOperationException]。
     */
    suspend fun clearPushToken(provider: String) {
        throw UnsupportedOperationException("clearPushToken")
    }
}

/** 引擎对已经发出的通知的一条更正，模块照办，应用什么都不用做。 */
sealed interface PlatformNotificationCorrection {
    /** 撤掉这些合并键（通知的 tag）的通知：会话读了或删了。 */
    data class Clear(val collapseIds: List<String>) : PlatformNotificationCorrection

    /** 撤掉本模块的全部通知：会话结束（登出、换账号）。 */
    object ClearAll : PlatformNotificationCorrection {
        override fun toString(): String = "ClearAll"
    }

    /**
     * 角标绝对值：未读总数变了、登录之后、回到前台。Android 没有系统级角标接口：华为、荣耀桌面经它们的角标接口设成
     * 这个数，其它桌面上的计数来自通知本身。
     */
    data class Badge(val count: Int) : PlatformNotificationCorrection
}

/** 宿主在上限内没有答复，经 [FlarePushOptions.onError] 报出。只带方法名与上限：不含令牌与载荷。 */
class FlarePushHostTimeoutException(val call: String, val limitMs: Long) :
    RuntimeException("push host $call did not answer within $limitMs ms")

/** 一次令牌登记，对应引擎的 `PushTokenInput`。可选字段为 null 时不上报。 */
data class PlatformPushToken(
    /** `fcm`、`getui` 或 `apns`。 */
    val provider: String,
    val token: String,
    val platform: String = PLATFORM_ANDROID,
    /** Android 的 applicationId。 */
    val appBundle: String? = null,
    /** 只有 APNs 用：`sandbox` 或 `production`。 */
    val environment: String? = null,
    /** BCP 47，例如 `zh-CN`。 */
    val locale: String? = null,
    /** IANA 时区，例如 `Asia/Shanghai`。 */
    val timeZone: String? = null,
    val appVersion: String? = null,
    /** 已知取值见 [PlatformPushCapabilities]。 */
    val capabilities: List<String> = emptyList(),
) {
    // 令牌不能进日志。
    override fun toString(): String = "PlatformPushToken(provider=$provider, platform=$platform)"

    companion object {
        const val PLATFORM_ANDROID = "android"
    }
}

/** 推送通道的标识，与服务端绑定里的 provider 相同。 */
object PlatformPushProviders {
    const val FCM = "fcm"
    const val GETUI = "getui"
    const val APNS = "apns"
}

/** 令牌登记里的能力取值。 */
object PlatformPushCapabilities {
    /** 设备能收到数据消息并由端上代码渲染（Android FCM）。 */
    const val DATA_MESSAGES = "dataMessages"
}

/** 引擎对一条远程推送的处理结果。 */
enum class PlatformPushAction(val wireValue: String) {
    /** 新通知，可以响铃。 */
    PRESENT("present"),

    /** 静默替换同一合并键的通知。 */
    UPDATE("update"),

    /** 移除通知。 */
    CLEAR("clear"),

    /** 只更新角标。 */
    BADGE_ONLY("badgeOnly"),

    /** 什么都不做，原因见 [PlatformPushOutcome.reason]。 */
    IGNORE("ignore"),
    ;

    companion object {
        /** 认 `badgeOnly`、`badge_only`、`BADGE_ONLY` 几种写法；认不出的当作 [IGNORE]。 */
        fun fromWire(value: String?): PlatformPushAction =
            values().firstOrNull { wireKey(it.wireValue) == wireKey(value) } ?: IGNORE
    }
}

/** 系统通知渠道。渠道标识由本模块创建，服务端的厂商参数引用同一组标识。 */
enum class PlatformPushChannel(val wireValue: String, val channelId: String) {
    MESSAGES("messages", "flare.messages"),
    QUIET("quiet", "flare.quiet"),
    MENTIONS("mentions", "flare.mentions"),
    URGENT("urgent", "flare.urgent"),
    ;

    companion object {
        fun fromWire(value: String?): PlatformPushChannel =
            values().firstOrNull { wireKey(it.wireValue) == wireKey(value) } ?: MESSAGES
    }
}

/** 通知展示在哪里：前台时由应用内横幅负责，系统通知不再重复。 */
enum class PlatformPushSurface(val wireValue: String) {
    SYSTEM("system"),
    IN_APP("inApp"),
    ;

    companion object {
        fun fromWire(value: String?): PlatformPushSurface =
            values().firstOrNull { wireKey(it.wireValue) == wireKey(value) } ?: SYSTEM
    }
}

/** 要展示的一条通知，对应引擎的 `NotificationPresentation`。 */
data class PlatformPushPresentation(
    /** 通知的 tag；一个会话一条通知。 */
    val collapseId: String,
    /** 分组键。 */
    val threadId: String,
    val conversationId: String,
    val messageId: String,
    val seq: Long,
    val title: String,
    val body: String,
    /** 这条通知代表的未读条数，至少为 1。 */
    val count: Int,
    val sound: Boolean,
    val channel: PlatformPushChannel,
    val surface: PlatformPushSurface,
)

/** 对应引擎的 `RemoteMessageOutcome`。 */
data class PlatformPushOutcome(
    val action: PlatformPushAction,
    val presentation: PlatformPushPresentation? = null,
    /** 无论 [action] 是什么都要移除的通知。 */
    val clearCollapseIds: List<String> = emptyList(),
    /** 角标绝对值，只在已知时给出。 */
    val badge: Int? = null,
    /** 诊断用，`ignore` 时给出：`otherAccount`、`notLoggedIn`、`stale`、`alreadyAlerted`、`malformed`。 */
    val reason: String? = null,
)

/** 点击通知后要去的会话，对应引擎的 `NotificationTapResult`。 */
data class PlatformTapRoute(
    val conversationId: String,
    val messageId: String? = null,
    val seq: Long? = null,
)

/** 把 `badgeOnly`、`badge_only`、`BADGE_ONLY` 归成同一个键，枚举与字符串两种生成形态都能对上。 */
internal fun wireKey(value: String?): String = value.orEmpty().replace("_", "").lowercase()
