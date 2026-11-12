package com.flare.im.push.flutter

import com.flare.im.push.FlareBackgroundPresenter
import com.flare.im.push.FlarePush
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 方法通道 `im.flare.push/presenter` 的 Android 一端：Dart 的 `FlareNotificationPresenter` 在这里要或不要后台展示器
 * （[FlareBackgroundPresenter.attach]、[FlareBackgroundPresenter.detach]）。
 *
 * 接上与否、什么时候告诉引擎都由模块决定：应用要、有宿主（[FlutterChannelPushHost]）、通知权限也允许时，模块经宿主
 * 调 Dart 的 `setBackgroundPresenter(true)`，缺一样调 `false`。要展示的通知、清除与角标由 Dart 的 `FlarePush` 经
 * `im.flare.push` 转来（`presentNotification` 等），不走这个通道。
 *
 * - `attach`：答 `{attached, backend: "android"}`，`attached` 是模块已经装上（`FlarePush.start` 调过）。
 * - `detach`：不要了；已经发出的通知不动。
 * 其余方法（桌面的展示与授权）Android 上没有：Dart 不调。
 */
internal class BackgroundPresenterBridge : MethodChannel.MethodCallHandler {
    // 这个 Flutter 引擎要过后台展示器：引擎拆掉时替它说不要了，下一个引擎的 Dart 自己再要。
    private var requested = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                requested = true
                FlareBackgroundPresenter.attach()
                result.success(mapOf("attached" to FlarePush.isInstalled, "backend" to BACKEND))
            }
            "detach" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Flutter 引擎拆掉了，或 Dart 不要了：经这个引擎的宿主再也收不到要展示的通知。 */
    fun release() {
        if (!requested) return
        requested = false
        FlareBackgroundPresenter.detach()
    }

    companion object {
        const val CHANNEL = "im.flare.push/presenter"
        private const val BACKEND = "android"
    }
}
