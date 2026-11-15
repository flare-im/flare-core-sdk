package com.flare.im.push

import android.content.Context
import android.net.Uri
import android.os.Bundle

/**
 * 桌面图标角标。Android 没有系统级角标接口：华为、荣耀桌面有公开的角标接口（经桌面的内容提供者设一个数），
 * 本模块用它；其它桌面（原生的圆点、三星与小米的计数）的角标来自通知本身（渠道允许角标，通知带条数），这里不做事。
 * 接口要的权限与包可见性在本模块的清单里声明。
 */
internal object FlareLauncherBadge {
    private const val METHOD = "change_badge"
    private val HUAWEI = Uri.parse("content://com.huawei.android.launcher.settings/badge/")
    private val HONOR = Uri.parse("content://com.hihonor.android.launcher.settings/badge/")

    private val lock = Any()
    private var applied: Int? = null

    /** 把角标设成 [count]（0 是去掉）。与上次设的相同时不再跨进程调用；失败只是没有角标。 */
    fun apply(context: Context, count: Int) {
        val value = count.coerceAtLeast(0)
        val providers = when (FlarePushVendor.current()) {
            FlarePushVendor.HUAWEI -> listOf(HUAWEI)
            // 早期荣耀机型用的还是华为桌面。
            FlarePushVendor.HONOR -> listOf(HONOR, HUAWEI)
            else -> return
        }
        synchronized(lock) {
            if (applied == value) return
            val appContext = context.applicationContext ?: context
            val launcher = launcherClass(appContext) ?: return
            val extras = Bundle().apply {
                putString("package", appContext.packageName)
                putString("class", launcher)
                putInt("badgenumber", value)
            }
            val done = providers.any { uri ->
                runCatching { appContext.contentResolver.call(uri, METHOD, null, extras) }.isSuccess
            }
            if (done) applied = value
        }
    }

    /** 桌面图标对应的启动页类名：角标接口按它找图标。 */
    private fun launcherClass(context: Context): String? = runCatching {
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.component?.className
    }.getOrNull()
}
