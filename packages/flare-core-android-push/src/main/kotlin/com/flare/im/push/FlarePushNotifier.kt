package com.flare.im.push

import android.annotation.SuppressLint
import android.app.Activity
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Locale

/**
 * 把展示意图落成系统通知。
 *
 * 一个会话一条通知：tag 取合并键、id 固定，同会话的新通知覆盖旧的，推送与链路两条路径互相覆盖
 * 而不是重复。静默替换用只提示一次、不响铃的方式。渠道由本模块创建，声音与重要级在渠道上，
 * 渠道建好后归用户管，这里不删不重建去覆盖用户的选择。
 */
internal class FlarePushNotifier(
    context: Context,
    private val smallIcon: Int,
    private val color: Int?,
    private val launchActivity: Class<out Activity>?,
) : PushPresenter {
    private val context = context.applicationContext ?: context
    private val manager = NotificationManagerCompat.from(this.context)

    @Volatile
    private var channelsLocale: String? = null

    /** 建好四个渠道；语言变了就按新语言重写名称（渠道名称与描述可改，重要级不可改）。 */
    fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val locale = Locale.getDefault().toLanguageTag()
        if (channelsLocale == locale) return
        val channels = PlatformPushChannel.values().map { channel(it) }
        try {
            manager.createNotificationChannelsCompat(channels)
            channelsLocale = locale
        } catch (error: RuntimeException) {
            // 系统服务暂时不可用；下次展示前再试。
        }
    }

    @SuppressLint("MissingPermission")
    override fun show(presentation: PlatformPushPresentation, payload: Map<String, String>, quiet: Boolean) {
        // Android 13 起没授权时 notify 被系统丢掉；先判断，免得白建一条通知。
        if (!manager.areNotificationsEnabled()) return
        ensureChannels()
        val silent = quiet || !presentation.sound
        val title = presentation.title.ifBlank { appLabel() }
        val builder = NotificationCompat.Builder(context, presentation.channel.channelId)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(presentation.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(presentation.body))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(priority(presentation.channel))
            .setNumber(presentation.count)
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setOnlyAlertOnce(quiet)
            .setSilent(silent)
        if (presentation.threadId.isNotBlank()) builder.setGroup(presentation.threadId)
        color?.let { builder.setColor(it) }
        if (!silent && Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            // 8.0 以前没有渠道，声音与振动跟着通知走。
            builder.setDefaults(NotificationCompat.DEFAULT_ALL)
        }
        contentIntent(presentation.collapseId, payload)?.let { builder.setContentIntent(it) }
        try {
            manager.notify(presentation.collapseId, NOTIFICATION_ID, builder.build())
        } catch (error: SecurityException) {
            // 权限在判断之后被撤销。
        } catch (error: RuntimeException) {
            // 系统服务暂时不可用；同步之后链路上的提示会补上。
        }
    }

    override fun cancel(collapseIds: Collection<String>) {
        for (collapseId in collapseIds) {
            if (collapseId.isBlank()) continue
            runCatching { manager.cancel(collapseId, NOTIFICATION_ID) }
        }
    }

    /** 移除本模块发出的全部通知（登出、会话结束时用），应用自己的其它通知不动。 */
    override fun cancelAll() {
        val system = context.getSystemService(NotificationManager::class.java) ?: return
        val active = runCatching { system.activeNotifications }.getOrNull() ?: return
        for (notification in active) {
            if (notification.id == NOTIFICATION_ID) runCatching { system.cancel(notification.tag, NOTIFICATION_ID) }
        }
    }

    /** 角标绝对值：华为、荣耀桌面经它们的角标接口设，其它桌面的计数来自通知本身。 */
    override fun badge(count: Int) {
        FlareLauncherBadge.apply(context, count)
    }

    private fun channel(channel: PlatformPushChannel): NotificationChannelCompat {
        val (importance, name, description) = when (channel) {
            PlatformPushChannel.MESSAGES -> Triple(
                NotificationManagerCompat.IMPORTANCE_HIGH,
                R.string.flare_push_channel_messages,
                R.string.flare_push_channel_messages_description,
            )
            PlatformPushChannel.QUIET -> Triple(
                NotificationManagerCompat.IMPORTANCE_LOW,
                R.string.flare_push_channel_quiet,
                R.string.flare_push_channel_quiet_description,
            )
            PlatformPushChannel.MENTIONS -> Triple(
                NotificationManagerCompat.IMPORTANCE_HIGH,
                R.string.flare_push_channel_mentions,
                R.string.flare_push_channel_mentions_description,
            )
            PlatformPushChannel.URGENT -> Triple(
                NotificationManagerCompat.IMPORTANCE_HIGH,
                R.string.flare_push_channel_urgent,
                R.string.flare_push_channel_urgent_description,
            )
        }
        val builder = NotificationChannelCompat.Builder(channel.channelId, importance)
            .setName(context.getString(name))
            .setDescription(context.getString(description))
            .setShowBadge(true)
        if (channel == PlatformPushChannel.QUIET) {
            // 静默更新只改内容与计数：不响、不振。
            builder.setSound(null, null).setVibrationEnabled(false)
        } else {
            builder
                .setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setVibrationEnabled(true)
                .setLightsEnabled(true)
        }
        return builder.build()
    }

    private fun priority(channel: PlatformPushChannel): Int = when (channel) {
        PlatformPushChannel.QUIET -> NotificationCompat.PRIORITY_LOW
        PlatformPushChannel.URGENT -> NotificationCompat.PRIORITY_MAX
        PlatformPushChannel.MESSAGES, PlatformPushChannel.MENTIONS -> NotificationCompat.PRIORITY_HIGH
    }

    /** 点击打开应用的启动页，带上载荷；请求码按合并键区分，各会话的通知各带各的载荷。 */
    private fun contentIntent(collapseId: String, payload: Map<String, String>): PendingIntent? {
        val intent = FlarePushIntents.launchIntent(context, launchActivity) ?: return null
        intent.putExtra(FlarePush.EXTRA_PAYLOAD, FlarePushPayload.encode(payload))
        return PendingIntent.getActivity(
            context,
            collapseId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun appLabel(): String =
        runCatching { context.applicationInfo.loadLabel(context.packageManager).toString() }.getOrDefault("")

    companion object {
        /** 本模块所有通知共用的 id；同一会话靠 tag（合并键）区分。 */
        const val NOTIFICATION_ID = 0x464C
    }
}

/** 启动意图的构造与解析，通知、厂商通知与中转页共用。 */
internal object FlarePushIntents {
    /**
     * 打开应用的意图：显式指向启动页（或 [activity]），不带 MAIN/LAUNCHER。和任务根意图不同，
     * 应用已在运行时也会把意图交给 onNewIntent，而不是只把任务拉到前台、丢掉附加数据。
     */
    fun launchIntent(context: Context, activity: Class<out Activity>?): Intent? {
        val component = if (activity != null) {
            ComponentName(context, activity)
        } else {
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.component ?: return null
        }
        return Intent()
            .setComponent(component)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    /**
     * 意图里的推送载荷：[FlarePush.EXTRA_PAYLOAD] 里的 JSON，或厂商意图逐键铺开的字符串附加数据。
     * 没有载荷时为 null。
     */
    fun payload(intent: Intent): Map<String, String>? {
        val extras = try {
            intent.extras
        } catch (error: RuntimeException) {
            // 外部发来的意图可能带解不开的附加数据。
            null
        } ?: return null
        val json = try {
            extras.getString(FlarePush.EXTRA_PAYLOAD)
        } catch (error: RuntimeException) {
            null
        }
        if (json != null) return FlarePushPayload.decode(json)?.takeIf { it.isNotEmpty() }
        val spread = LinkedHashMap<String, String>()
        for (key in FlarePushPayload.KEYS) {
            val value = try {
                extras.getString(key)
            } catch (error: RuntimeException) {
                null
            } ?: continue
            spread[key] = value
        }
        val routable = spread.containsKey(FlarePushPayload.COLLAPSE_ID) || spread.containsKey(FlarePushPayload.CONVERSATION_ID)
        return spread.takeIf { routable }
    }

    /** 读过的载荷从意图上拿掉，界面重建时不会再路由一次。 */
    fun consume(intent: Intent) {
        intent.removeExtra(FlarePush.EXTRA_PAYLOAD)
        for (key in FlarePushPayload.KEYS) intent.removeExtra(key)
    }
}
