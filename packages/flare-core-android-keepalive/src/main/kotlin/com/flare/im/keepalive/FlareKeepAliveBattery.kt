package com.flare.im.keepalive

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

/**
 * 电池优化的引导：常驻连接开着时系统的电池优化仍可能停掉服务或断开网络，要用户自己把应用放出电池优化。
 * 只读状态、只打开系统的设置页；不用直接弹豁免框的 `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`（要额外权限，
 * 商店政策也限制），也不在用户没点的时候打开任何页面。
 */
object FlareKeepAliveBattery {
    /** 应用已经被放出电池优化。 */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean = runCatching {
        context.getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(context.packageName) == true
    }.getOrDefault(false)

    /** 电池优化的应用列表页，用户在里面放开本应用。 */
    fun settingsIntent(): Intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

    /** 打开 [settingsIntent]，打不开时退到本应用的详情页；都打不开返回 false。 */
    fun openSettings(context: Context): Boolean =
        open(context, settingsIntent()) ||
            open(context, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))

    private fun open(context: Context, intent: Intent): Boolean {
        if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            true
        } catch (error: RuntimeException) {
            // 页面不存在（部分厂商系统）或不让打开。
            false
        }
    }
}
