package com.flare.im.keepalive

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat

/**
 * 常驻连接的前台服务。它自己不做任何网络的事：只让进程在后台一直算「前台」，链路由进程里的客户端照常维持。
 * 系统回收后按 `START_STICKY` 重建；开关已经关掉时进入前台后马上退出（`startForegroundService` 之后必须先进入前台）。
 */
class FlareKeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!enterForeground()) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!FlareKeepAlive.isEnabled(this)) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        FlareKeepAlive.serviceStarted()
        return START_STICKY
    }

    override fun onDestroy() {
        FlareKeepAlive.serviceStopped()
        super.onDestroy()
    }

    private fun enterForeground(): Boolean = try {
        // Android 14 起前台服务要带清单里声明的类型；更早的系统不认 specialUse，不带类型。
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, KeepAliveNotification.ID, KeepAliveNotification.build(this, FlareKeepAlive.options), type)
        true
    } catch (error: RuntimeException) {
        // 后台时不让进入前台、缺权限：这次不常驻，回到前台时模块再试。
        FlareKeepAlive.options.onError(error)
        false
    }
}

/** 开机与应用更新后按开关重新启动服务。 */
class FlareKeepAliveRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (restartsOn(intent.action, FlareKeepAlive.isEnabled(context))) FlareKeepAlive.restore(context)
    }
}

/** 常驻通知与它的渠道：低重要级、不响不振、不进角标，一直挂着。 */
internal object KeepAliveNotification {
    const val ID = 0x464B

    fun build(context: Context, options: FlareKeepAliveOptions): Notification {
        ensureChannel(context)
        val builder = NotificationCompat.Builder(context, FlareKeepAlive.CHANNEL_ID)
            .setSmallIcon(options.smallIcon.takeIf { it != 0 } ?: R.drawable.flare_keepalive_ic_notification)
            .setContentTitle(options.title ?: appLabel(context))
            .setContentText(options.text ?: context.getString(R.string.flare_keepalive_notification_text))
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
        options.color?.let { builder.setColor(it) }
        contentIntent(context, options)?.let { builder.setContentIntent(it) }
        return builder.build()
    }

    /** 建渠道；名称与描述随系统语言改写，重要级建好后归用户管。 */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannelCompat.Builder(FlareKeepAlive.CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
            .setName(context.getString(R.string.flare_keepalive_channel))
            .setDescription(context.getString(R.string.flare_keepalive_channel_description))
            .setShowBadge(false)
            .setSound(null, null)
            .setVibrationEnabled(false)
            .build()
        try {
            NotificationManagerCompat.from(context).createNotificationChannel(channel)
        } catch (error: RuntimeException) {
            // 系统服务暂时不可用；通知照样交给系统，下次进入前台再建。
        }
    }

    /** 点通知打开应用：显式指向启动页（或选项里的页面），应用已在运行时交给 onNewIntent。 */
    private fun contentIntent(context: Context, options: FlareKeepAliveOptions): PendingIntent? {
        val component = options.launchActivity?.let { ComponentName(context, it) }
            ?: context.packageManager.getLaunchIntentForPackage(context.packageName)?.component
            ?: return null
        val intent = Intent()
            .setComponent(component)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(context, ID, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun appLabel(context: Context): String =
        runCatching { context.applicationInfo.loadLabel(context.packageManager).toString() }.getOrDefault("")
}
