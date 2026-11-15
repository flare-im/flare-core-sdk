package com.flare.im.push

import android.content.Context
import java.util.UUID
import kotlinx.coroutines.flow.StateFlow

/**
 * 后台展示器：应用退到后台、链路还在时，引擎自己决定的提示（`notification.present`，展示面 `system`）由本模块发成
 * 系统通知，渠道、tag（合并键）与静默更新的规则同推送的通知；引擎的清除与角标照常照办。接上后引擎在后台上报
 * `STANDBY` 并照常确认，提示不再等服务端推送；进程被冻结或回收后确认不再到达，提示由推送通道补上。
 *
 * 应用在 [FlarePush.install] 之后（或之前，记下的意愿安装时生效）调 [attach]，不想要了调 [detach]。「接上」要三样
 * 都有：应用要（[attach]）、有宿主（登录或恢复了会话）、能展示通知（系统通知权限）。三样齐了模块调宿主的
 * `setBackgroundPresenter(true)`，缺了任何一样调 `false`：撤销通知权限会断开，重新授权后自动接回；换宿主
 * （重新登录、换了客户端）对新宿主再报一次。实际状态从 [attached] 读。
 *
 * 本模块发的这类通知点开时不经引擎解析：通知里带一个凭据，凭据在登出（[FlarePush.signOut]）与会话结束
 * （引擎的全部清除）时换掉，旧通知的点击只打开应用，不会打开上一个账号的会话。
 */
object FlareBackgroundPresenter {
    /** 引擎知道本模块在替它出后台提示：宿主已经答复了 `setBackgroundPresenter(true)`。 */
    val attached: StateFlow<Boolean>
        get() = FlarePush.backgroundPresenterState

    /** 应用要不要后台展示器（[attach] 与 [detach] 记下的意愿）；是否真的接上看 [attached]。 */
    val isRequested: Boolean
        get() = FlarePush.backgroundPresenterRequested

    /** 要后台展示器。重复调用不做事；有宿主且通知权限已允许时立刻告诉引擎。 */
    fun attach() {
        FlarePush.requestBackgroundPresenter(true)
    }

    /** 不要后台展示器：告诉引擎后台提示交给服务端推送，已经发出的通知不动。 */
    fun detach() {
        FlarePush.requestBackgroundPresenter(false)
    }
}

/**
 * 本模块自己发的通知（后台展示器）的点击凭据。登出与会话结束时换一个，换之前发出的通知点开后不再路由。
 * 凭据要撑过进程被回收：同一个账号重启应用后，通知栏里留着的通知照样能打开会话。
 */
internal interface PresenterEpochs {
    fun current(): String

    fun rotate()
}

/** 只在内存里的凭据：单测与没有上下文的场合用。 */
internal class MemoryPresenterEpochs : PresenterEpochs {
    @Volatile
    private var epoch = UUID.randomUUID().toString()

    override fun current(): String = epoch

    override fun rotate() {
        epoch = UUID.randomUUID().toString()
    }
}

/** 存在本模块的偏好文件里的凭据。读写失败时退回进程内的值：最坏是旧通知点开后只打开应用。 */
internal class StoredPresenterEpochs(context: Context) : PresenterEpochs {
    private val context = context.applicationContext ?: context
    private val lock = Any()
    private var cached: String? = null

    override fun current(): String = synchronized(lock) {
        cached ?: (runCatching { preferences().getString(KEY, null) }.getOrNull()?.takeIf { it.isNotBlank() } ?: fresh())
            .also { cached = it }
    }

    override fun rotate() {
        synchronized(lock) { cached = fresh() }
    }

    private fun fresh(): String = UUID.randomUUID().toString().also { epoch ->
        runCatching { preferences().edit().putString(KEY, epoch).apply() }
    }

    private fun preferences() = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private companion object {
        // 与通知权限的记录同一个文件。
        const val PREFERENCES = "com.flare.im.push"
        const val KEY = "presenterEpoch"
    }
}

/** 后台展示器发出的通知带的点击载荷：与推送载荷同一组键，外加来源与凭据。不带标题与正文。 */
internal object LocalPresentations {
    const val ORIGIN = "flare_origin"
    const val ORIGIN_LINK = "link"
    const val EPOCH = "flare_epoch"

    fun tapPayload(presentation: PlatformPushPresentation, epoch: String): Map<String, String> = buildMap {
        put(FlarePushPayload.COLLAPSE_ID, presentation.collapseId)
        put(FlarePushPayload.THREAD_ID, presentation.threadId)
        if (presentation.conversationId.isNotBlank()) put(FlarePushPayload.CONVERSATION_ID, presentation.conversationId)
        if (presentation.messageId.isNotBlank()) put(FlarePushPayload.MESSAGE_ID, presentation.messageId)
        if (presentation.seq > 0) put(FlarePushPayload.SEQ, presentation.seq.toString())
        put(ORIGIN, ORIGIN_LINK)
        put(EPOCH, epoch)
    }

    /**
     * 点开的是不是本模块自己发的通知：不是时为 null（交给引擎解析）；是时给出去向，凭据过期或没有会话（摘要通知）
     * 时去向为 null。
     */
    fun tap(payload: Map<String, String>, epoch: String): LocalTap? {
        if (payload[ORIGIN] != ORIGIN_LINK) return null
        val conversationId = payload[FlarePushPayload.CONVERSATION_ID]?.trim().orEmpty()
        if (payload[EPOCH] != epoch || conversationId.isEmpty()) return LocalTap(null)
        return LocalTap(
            PlatformTapRoute(
                conversationId = conversationId,
                messageId = payload[FlarePushPayload.MESSAGE_ID]?.trim()?.takeIf(String::isNotEmpty),
                seq = payload[FlarePushPayload.SEQ]?.trim()?.toLongOrNull()?.takeIf { it > 0 },
            ),
        )
    }
}

/** 本模块自己发的通知点开后的去向；null 表示只打开应用。 */
internal data class LocalTap(val route: PlatformTapRoute?)
