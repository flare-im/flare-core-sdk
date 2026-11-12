package com.flare.im.push

import android.app.Activity
import android.os.Bundle

/**
 * 厂商通知的点击落点。系统代为展示的厂商通知（个推的厂商通道）点击时按服务端给的意图打开这里：
 * 组件名由本模块固定为 `com.flare.im.push.FlarePushOpenActivity`，服务端只需要知道应用包名，
 * 不用知道每个应用的启动页。它把载荷原样转给启动页，由 [FlarePush.handleLaunchIntent] 处理，
 * 然后立即结束。
 *
 * 这个页面是导出的；转过去的载荷在启动页里还要经引擎核对属于当前账号，才会变成去向。
 */
class FlarePushOpenActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val payload = FlarePushIntents.payload(intent)
        val launch = FlarePushIntents.launchIntent(this, FlarePush.launchActivity())
        if (launch != null) {
            payload?.let { launch.putExtra(FlarePush.EXTRA_PAYLOAD, FlarePushPayload.encode(it)) }
            try {
                startActivity(launch)
            } catch (error: RuntimeException) {
                // 启动页找不到或被禁用：什么都不做，至少不让中转页崩掉。
            }
        }
        finish()
    }
}
