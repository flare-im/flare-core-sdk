package com.flare.im.push

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.runBlocking

/**
 * FCM 消息服务，在本模块的清单里声明（不导出）。
 *
 * 发给 Android 设备的 FCM 一律是纯数据消息，由这里交给引擎再展示：引擎给出展示意图就照办，
 * 等不到（冷启动还在初始化、没登录、超时或出错）就按载荷原样展示，提示不丢。
 */
class FlareFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        FlarePush.submitToken(
            PlatformPushProviders.FCM,
            token,
            listOf(PlatformPushCapabilities.DATA_MESSAGES),
        )
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val payload = HashMap(message.data)
        if (payload.isEmpty()) return
        // FCM 在自己的工作线程上调用这里，返回后进程随时可能被冻结：在返回前把通知落下。
        // 等引擎的上限在 FlarePush 里，阻塞不会超过约三秒。
        runBlocking {
            FlarePush.handleRemoteMessage(applicationContext, PlatformPushProviders.FCM, payload)
        }
    }
}

/**
 * Firebase 在运行期是可选的：应用不带 `google-services.json` 时默认 FirebaseApp 不会初始化，
 * 这里报不可用，不去碰 FirebaseMessaging（它会抛错）。
 */
internal object FirebaseTokens {
    fun available(context: Context): Boolean = try {
        FirebaseApp.getApps(context).isNotEmpty()
    } catch (error: Throwable) {
        // 应用在打包时剔除了 Firebase 也走这里。
        false
    }

    /** 取当前 FCM 令牌；Firebase 不可用时什么都不做。 */
    fun fetch(context: Context, onError: (Throwable) -> Unit, onToken: (String) -> Unit) {
        if (!available(context)) return
        try {
            FirebaseMessaging.getInstance().token
                .addOnSuccessListener { token -> if (!token.isNullOrBlank()) onToken(token) }
                .addOnFailureListener { error -> onError(error) }
        } catch (error: Throwable) {
            onError(error)
        }
    }
}
