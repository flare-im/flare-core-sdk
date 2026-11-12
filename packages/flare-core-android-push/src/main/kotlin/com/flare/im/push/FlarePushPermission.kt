package com.flare.im.push

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.ActivityResultLauncher
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** 系统通知权限的三种情形。 */
enum class FlarePushPermissionStatus(val wireValue: String) {
    /** 还没问过：可以弹系统授权框（Android 13 起）。 */
    NOT_DETERMINED("notDetermined"),

    /** 拒绝过，或在系统设置里关掉了：引导去系统设置（[FlarePushPermission.canRequest] 为 true 时授权框还能再弹一次）。 */
    DENIED("denied"),

    /** 能展示通知。 */
    GRANTED("granted"),
    ;

    companion object {
        /** 认不出的当作 [DENIED]：不弹框，只引导去设置。 */
        fun fromWire(value: String?): FlarePushPermissionStatus =
            values().firstOrNull { it.wireValue == value } ?: DENIED
    }
}

/**
 * 通知权限。Android 13 起展示通知要运行时授权，更早的系统由用户在设置里开关。
 *
 * 申请时机由应用决定（不要在启动时直接弹），而且要经这里的 [request]：模块记下弹过授权框，
 * 才分得清「还没问过」与「拒绝过」（系统自己不给这个区分），应用不用另记。授权框的结果回来后调
 * [FlarePush.refresh]，结果（包括拒绝）就报给了引擎，[FlarePush.permission] 也随之更新。
 * 用户在设置里改了开关，回前台时模块自己会重读重报。
 */
object FlarePushPermission {
    /** `Manifest.permission.POST_NOTIFICATIONS`，本模块的清单已声明。 */
    const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"

    private const val PREFERENCES = "com.flare.im.push"
    private const val ASKED = "notificationPermissionAsked"

    /** 三态权限；变化从 [FlarePush.permission] 读。 */
    fun status(context: Context): FlarePushPermissionStatus =
        permissionStatus(granted = isGranted(context), needsRequest = needsRequest(context), asked = hasAsked(context))

    /** 现在能不能展示通知：没授权、或用户在设置里关了，都是 false。 */
    fun isGranted(context: Context): Boolean =
        runCatching { NotificationManagerCompat.from(context).areNotificationsEnabled() }.getOrDefault(false)

    /** 需要弹系统授权框：Android 13 及以上且还没授权。 */
    fun needsRequest(context: Context): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED

    /**
     * 系统授权框现在还会弹出来：需要申请，而且还没问过、或用户只拒绝过一次（系统建议先解释再申请）。
     * 为 false 而 [isGranted] 也是 false 时，只能去 [openSettings]。
     */
    fun canRequest(activity: Activity): Boolean =
        needsRequest(activity) && (!hasAsked(activity) || shouldShowRationale(activity))

    /**
     * 同 `canRequest(activity)`，给手里只有 [Context] 的调用方（例如 Compose 的 `LocalContext.current`）：沿 `ContextWrapper` 找到所在的
     * 页面再判断。找不到页面（应用上下文、服务）时为 false：没有页面就弹不了授权框。
     */
    fun canRequest(context: Context): Boolean = context.hostingActivity()?.let { canRequest(it) } ?: false

    /**
     * 需要时用 [launcher]（`registerForActivityResult(ActivityResultContracts.RequestPermission())`）
     * 弹系统授权框，弹了返回 true，并记下问过。结果回调里调 [FlarePush.refresh]。不需要弹、而 [isGranted]
     * 仍是 false 时，引导用户去 [openSettings]。
     */
    fun request(context: Context, launcher: ActivityResultLauncher<String>): Boolean {
        if (!needsRequest(context)) return false
        markAsked(context)
        launcher.launch(POST_NOTIFICATIONS)
        return true
    }

    /**
     * 不经 `ActivityResultLauncher` 的申请（例如 Flutter 插件）：用 [requestCode] 弹系统授权框，结果到
     * [activity] 的 `onRequestPermissionsResult`，在那里调 [FlarePush.refresh]。弹了返回 true，并记下问过。
     */
    fun request(activity: Activity, requestCode: Int): Boolean {
        if (!needsRequest(activity)) return false
        markAsked(activity)
        ActivityCompat.requestPermissions(activity, arrayOf(POST_NOTIFICATIONS), requestCode)
        return true
    }

    /** 用户拒绝过一次、系统建议先解释再申请。 */
    fun shouldShowRationale(activity: Activity): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ActivityCompat.shouldShowRequestPermissionRationale(activity, POST_NOTIFICATIONS)

    /** 本应用的通知设置页；8.0 以前是应用详情页。 */
    fun settingsIntent(context: Context): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        } else {
            FlareBackgroundRestrictions.appDetailsSettingsIntent(context)
        }

    /** 打开 [settingsIntent]，打不开时退到应用详情页；都打不开返回 false。 */
    fun openSettings(context: Context): Boolean =
        startGuarded(context, settingsIntent(context)) ||
            startGuarded(context, FlareBackgroundRestrictions.appDetailsSettingsIntent(context))

    /**
     * 经本模块弹过系统授权框。权限按安装算：重装应用后它跟着清掉，正好又是没问过。
     */
    internal fun hasAsked(context: Context): Boolean =
        runCatching { preferences(context).getBoolean(ASKED, false) }.getOrDefault(false)

    private fun markAsked(context: Context) {
        runCatching { preferences(context).edit().putBoolean(ASKED, true).apply() }
    }

    private fun preferences(context: Context) =
        (context.applicationContext ?: context).getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}

/**
 * 三态的判定：能展示就是允许；Android 13 起要运行时授权、而本模块还没弹过授权框是没问过；其余
 * （拒绝过、13 以前在设置里关掉、授权了但在设置里关掉）都是拒绝。
 */
internal fun permissionStatus(granted: Boolean, needsRequest: Boolean, asked: Boolean): FlarePushPermissionStatus =
    when {
        granted -> FlarePushPermissionStatus.GRANTED
        needsRequest && !asked -> FlarePushPermissionStatus.NOT_DETERMINED
        else -> FlarePushPermissionStatus.DENIED
    }

/** 打开设置类页面：非 Activity 的上下文要新任务；页面不存在或不让打开都不崩。 */
internal fun startGuarded(context: Context, intent: Intent): Boolean {
    if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    return try {
        context.startActivity(intent)
        true
    } catch (error: RuntimeException) {
        // ActivityNotFoundException 与 SecurityException（厂商页面未导出）都在这里。
        false
    }
}

internal fun packageUri(context: Context): Uri = Uri.fromParts("package", context.packageName, null)

/** 沿 `ContextWrapper` 一层层往里找所在的页面；应用上下文、服务等不在页面里的为 null。 */
internal fun Context.hostingActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
