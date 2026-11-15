package com.flare.im.push.flutter

import com.flare.im.push.FlarePushHost
import com.flare.im.push.PlatformNotificationCorrection
import com.flare.im.push.PlatformPushOutcome
import com.flare.im.push.PlatformPushPresentation
import com.flare.im.push.PlatformPushToken
import com.flare.im.push.PlatformPushWire
import com.flare.im.push.PlatformTapRoute
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * 进程里唯一的「当前宿主」。Dart 接上宿主时，是经那个引擎的方法通道转给 Dart 的宿主；
 * 没有引擎、引擎没了或 Dart 没接时为 null，推送模块按载荷原样展示。
 *
 * 每次接上都是新的实例：模块按实例判断换没换宿主，换了就重报令牌与权限（重新登录）。
 */
internal object FlutterPushHosts {
    @Volatile
    private var attached: FlutterChannelPushHost? = null

    fun current(): FlarePushHost? = attached

    @Synchronized
    fun attach(channel: MethodChannel) {
        attached = FlutterChannelPushHost(channel)
    }

    /** 这个通道接上的宿主；另一个引擎接上的、或没接上时为 null。 */
    fun attachedTo(channel: MethodChannel): FlutterChannelPushHost? = attached?.takeIf { it.channel === channel }

    /** 只摘这个通道接上的宿主：另一个引擎接上的不动。 */
    @Synchronized
    fun detach(channel: MethodChannel) {
        if (attached?.channel === channel) attached = null
    }

    /** 登出：不管是哪个引擎接上的，一律摘下。 */
    @Synchronized
    fun clear() {
        attached = null
    }
}

/**
 * 把宿主调用转给 Dart（`FlarePush.attach` 接上的那个宿主）。线上形状就是引擎契约的 JSON，读写用模块的
 * [PlatformPushWire]。等多久由模块定：远程推送约三秒，令牌与点击十五秒，超时就按载荷展示或留到下次；
 * 模块等不及时取消这次调用，Dart 晚到的答复丢掉。
 *
 * 引擎的事件反过来走：Dart 听着引擎的 `notification.present`、`notification.clear`、`notification.badge`，经方法通道
 * 交给插件，插件 [deliver] 与 [correct] 到这里，模块像收集原生宿主的事件那样收集（后台展示器发通知、撤除、
 * 桌面图标角标）。模块没在收集时（还没同步到这个宿主）到的事件丢掉：撤除另有插件的直接调用兜底。
 */
internal class FlutterChannelPushHost(val channel: MethodChannel) : FlarePushHost {
    private val presentations = MutableSharedFlow<PlatformPushPresentation>(
        extraBufferCapacity = EVENT_BUFFER,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    private val corrections = MutableSharedFlow<PlatformNotificationCorrection>(
        extraBufferCapacity = EVENT_BUFFER,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )

    /** Dart 转来的一条 `notification.present`。 */
    fun deliver(presentation: PlatformPushPresentation) {
        presentations.tryEmit(presentation)
    }

    /** Dart 转来的一条 `notification.clear` 或 `notification.badge`。 */
    fun correct(correction: PlatformNotificationCorrection) {
        corrections.tryEmit(correction)
    }

    override fun notificationPresentations(): Flow<PlatformPushPresentation> = presentations.asSharedFlow()

    override fun notificationCorrections(): Flow<PlatformNotificationCorrection> = corrections.asSharedFlow()

    /** 后台展示器接上或断开：Dart 转给它那个宿主的引擎（`notification.set_background_presenter`）。 */
    override suspend fun setBackgroundPresenter(attached: Boolean) {
        invoke("setBackgroundPresenter", mapOf("attached" to attached))
    }

    override suspend fun updatePushToken(token: PlatformPushToken) {
        invoke("updatePushToken", PlatformPushWire.tokenRequest(token))
    }

    override suspend fun setPushPermission(allowed: Boolean) {
        invoke("setPushPermission", mapOf("allowed" to allowed))
    }

    override suspend fun reconcilePush() {
        invoke("reconcilePush", null)
    }

    override suspend fun handleRemoteMessage(
        provider: String,
        payload: Map<String, String>,
        budgetMs: Int,
    ): PlatformPushOutcome {
        val answer = invoke(
            "handleRemoteMessage",
            mapOf("provider" to provider, "payload" to payload, "budgetMs" to budgetMs),
        )
        val outcome = plainMap(answer) ?: throw IllegalStateException("handleRemoteMessage did not answer an object")
        return PlatformPushWire.outcome(outcome)
    }

    override suspend fun resolveNotificationTap(payload: Map<String, String>): PlatformTapRoute? =
        plainMap(invoke("resolveNotificationTap", mapOf("payload" to payload)))?.let(PlatformPushWire::tapRoute)

    override suspend fun totalUnread(): Int =
        PlatformPushWire.int(invoke("totalUnread", null))?.coerceAtLeast(0) ?: 0

    /** 方法通道只能在主线程上用；被取消（模块等不及）后到的答复丢掉。 */
    private suspend fun invoke(method: String, arguments: Any?): Any? = withContext(Dispatchers.Main.immediate) {
        suspendCancellableCoroutine<Any?> { continuation ->
            channel.invokeMethod(
                method,
                arguments,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (continuation.isActive) continuation.resume(result)
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        if (continuation.isActive) {
                            continuation.resumeWithException(FlutterPushHostException(method, errorCode))
                        }
                    }

                    override fun notImplemented() {
                        if (continuation.isActive) {
                            continuation.resumeWithException(FlutterPushHostException(method, "notImplemented"))
                        }
                    }
                },
            )
        }
    }

    private companion object {
        /** 模块收集得慢时最多攒这么多条，再多丢最旧的：链路上的提示是一阵一阵的，同一会话后一条覆盖前一条。 */
        const val EVENT_BUFFER = 64
    }
}

/** Dart 侧的宿主调用失败。只带方法名与错误码：消息里可能有令牌或载荷。 */
internal class FlutterPushHostException(method: String, code: String) :
    RuntimeException("push host $method failed: $code")

/** 方法通道给的 Map 键不一定是字符串，转成 [PlatformPushWire] 认的形状。 */
private fun plainMap(value: Any?): Map<String, Any?>? =
    (value as? Map<*, *>)?.entries?.associate { (key, item) -> key.toString() to item }
