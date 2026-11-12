package com.flare.im.push.getui

import android.content.Context
import com.flare.im.push.FlarePush
import com.flare.im.push.FlarePushPayload
import com.flare.im.push.PlatformPushProviders
import com.igexin.sdk.GTIntentService
import com.igexin.sdk.PushManager
import com.igexin.sdk.message.GTCmdMessage
import com.igexin.sdk.message.GTNotificationMessage
import com.igexin.sdk.message.GTTransmitMessage
import kotlinx.coroutines.runBlocking

/**
 * 个推接入。个推 SDK 的类名与调用都只在这个文件里。
 *
 * 在线时服务端发透传消息，内容是载荷各键组成的 JSON，和 FCM 数据消息走同一个入口：交给引擎，
 * 等不到就按载荷展示。进程不在时由厂商通道代为展示通知，点击打开 `FlarePushOpenActivity`，
 * 载荷在 `flare_push` 附加数据里，由 [FlarePush.handleLaunchIntent] 处理。
 *
 * Flutter 插件按类名反射调 [install]（应用从 Dart 选择启用时），插件本身不依赖本模块；混淆规则随模块发出。
 */
object FlareGetuiPush {
    /**
     * 初始化个推并登记 clientid。在 [FlarePush.install] 之后、用户同意隐私政策之后调用：
     * 国内应用商店要求同意之前不初始化推送 SDK。再调一次无害。
     */
    fun install(context: Context) {
        val app = context.applicationContext ?: context
        val manager = PushManager.getInstance()
        manager.initialize(app)
        // 新版本也认清单里的服务声明；显式登记一次，两种方式都能收到回调。
        @Suppress("DEPRECATION")
        manager.registerPushIntentService(app, FlareGetuiIntentService::class.java)
        // 已经注册过的设备不一定再回调一次 clientid，主动取一次。
        manager.getClientid(app)?.let { submitClientId(it) }
    }

    internal fun submitClientId(clientId: String) {
        if (clientId.isBlank()) return
        FlarePush.submitToken(PlatformPushProviders.GETUI, clientId)
    }
}

/** 个推透传的内容：载荷 JSON 的 UTF-8 字节。认不出时为 null。 */
internal object GetuiTransmission {
    fun payload(bytes: ByteArray?): Map<String, String>? {
        if (bytes == null || bytes.isEmpty()) return null
        return FlarePushPayload.decode(String(bytes, Charsets.UTF_8))?.takeIf { it.isNotEmpty() }
    }
}

/**
 * 接收个推回调的服务，在本模块的清单里声明。回调在个推的工作线程上，透传在返回前处理完：
 * 等引擎的上限在 [FlarePush] 里，约三秒。
 */
class FlareGetuiIntentService : GTIntentService() {
    override fun onReceiveServicePid(context: Context, pid: Int) = Unit

    override fun onReceiveClientId(context: Context, clientid: String?) {
        clientid?.let { FlareGetuiPush.submitClientId(it) }
    }

    override fun onReceiveMessageData(context: Context, msg: GTTransmitMessage?) {
        val payload = GetuiTransmission.payload(msg?.payload) ?: return
        runBlocking {
            FlarePush.handleRemoteMessage(context.applicationContext ?: context, PlatformPushProviders.GETUI, payload)
        }
    }

    override fun onReceiveOnlineState(context: Context, online: Boolean) = Unit

    override fun onReceiveCommandResult(context: Context, cmdMessage: GTCmdMessage?) = Unit

    // 服务端不发个推自己渲染的通知（在线走透传，离线走厂商通道），这两个回调没有要做的事。
    override fun onNotificationMessageArrived(context: Context, msg: GTNotificationMessage?) = Unit

    override fun onNotificationMessageClicked(context: Context, msg: GTNotificationMessage?) = Unit
}
