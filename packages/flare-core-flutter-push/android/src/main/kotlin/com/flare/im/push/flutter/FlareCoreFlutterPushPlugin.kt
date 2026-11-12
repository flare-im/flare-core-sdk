package com.flare.im.push.flutter

import android.annotation.SuppressLint
import android.app.Application
import android.content.Context
import android.content.Intent
import android.util.Log
import com.flare.im.push.FlareBackgroundRestrictions
import com.flare.im.push.FlarePush
import com.flare.im.push.FlarePushOptions
import com.flare.im.push.FlarePushPermission
import com.flare.im.push.FlarePushPermissionStatus
import com.flare.im.push.PlatformNotificationCorrection
import com.flare.im.push.PlatformPushWire
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.lang.reflect.InvocationTargetException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch

/**
 * 系统推送的 Flutter 桥（Android）。推送的平台行为全在 `flare-core-android-push`：Dart 调 `start` 时
 * 用 [FlarePush.install] 装上它，宿主经方法通道转给 Dart（[FlutterChannelPushHost]）；启动页的意图交给
 * [FlarePush.handleLaunchIntent]，点击去向从 [FlarePush.routes] 转回 Dart，权限从 [FlarePush.permission]、
 * 后台限制从 [FlarePush.backgroundDelivery] 转回 Dart。
 *
 * - 方法通道 `im.flare.push`：Dart 调 `start`、`attach`、`detach`、`signOut`、`setLocale`、`permissionStatus`、
 *   `canRequestPermission`、`requestPermission`、`openNotificationSettings`、`installGetui`、`backgroundStatus`、
 *   `openBatterySettings`、`openAutoStartSettings`，引擎更正的落地 `clearNotifications`（`{collapseIds}`）、
 *   `clearAllNotifications`、`setBadge`（`{count}`），以及链路在线时的通知 `presentNotification`（引擎
 *   `NotificationPresentation` 的形状）。更正与通知交给 Dart 接上的宿主（[FlutterChannelPushHost]），模块像收集原生
 *   宿主的事件那样照办：后台展示器发通知、撤除、桌面图标角标；撤除另外直接落地一次，宿主还没同步时也不残留。
 *   原生调 Dart 的是宿主的七个方法（含后台展示器的 `setBackgroundPresenter`）、`permissionChanged` 与
 *   `backgroundChanged`。
 * - 方法通道 `im.flare.push/presenter`：后台展示器要还是不要（[BackgroundPresenterBridge]）。
 * - 事件通道 `im.flare.push/routes`：点击去向 `{conversationId, messageId?, seq?}`。
 *
 * 推送把进程冷启动起来时没有 Flutter 引擎：插件不在，模块也没装上，FCM 服务按载荷原样展示。
 * 引擎在、Dart 还没接上宿主时，宿主同样给 null，模块照样按载荷展示。
 */
class FlareCoreFlutterPushPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.NewIntentListener {
    private var context: Context? = null
    private var methods: MethodChannel? = null
    private var routes: EventChannel? = null
    private var presenterChannel: MethodChannel? = null
    private val presenter = BackgroundPresenterBridge()
    private var scope: CoroutineScope? = null
    private var routeJob: Job? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val application = binding.applicationContext
        context = application
        val channel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        methods = channel
        routes = EventChannel(binding.binaryMessenger, ROUTES_CHANNEL).also {
            it.setStreamHandler(this)
        }
        presenterChannel = MethodChannel(binding.binaryMessenger, BackgroundPresenterBridge.CHANNEL).also {
            it.setMethodCallHandler(presenter)
        }
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate).also { created ->
            // 权限与后台档位变了就告诉 Dart（模块装上之前是 null，不发）。Dart 没监听时调用落空，无害。
            created.launch {
                FlarePush.permission.filterNotNull().collect { status ->
                    channel.invokeMethod(PERMISSION_CHANGED, status.wireValue)
                }
            }
            // 档位变了才发，每次带完整的现状（与 `backgroundStatus` 同形）。
            created.launch {
                FlarePush.backgroundDelivery.filterNotNull().collect {
                    channel.invokeMethod(BACKGROUND_CHANGED, backgroundStatus(application))
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // 引擎没了，经它转给 Dart 的宿主也就没了：之后的推送按载荷展示，点击留到下次接上。后台展示器也收不到
        // 要展示的通知了：替这个引擎说不要（引擎那头由 Dart 在页面拆掉时已经报过断开，见 README 的已知限制）。
        presenter.release()
        methods?.let { FlutterPushHosts.detach(it) }
        methods?.setMethodCallHandler(null)
        routes?.setStreamHandler(null)
        presenterChannel?.setMethodCallHandler(null)
        scope?.cancel()
        methods = null
        routes = null
        presenterChannel = null
        scope = null
        routeJob = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // 旋转屏幕时授权框的结果会送到重建后的页面，答复留着。
        detachActivity(answerPending = false)
    }

    override fun onDetachedFromActivity() {
        detachActivity(answerPending = true)
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        binding.addOnNewIntentListener(this)
        // 点击通知（含冷启动）打开的启动页：载荷交给模块，接上宿主后解析成去向。
        FlarePush.handleLaunchIntent(binding.activity.intent)
    }

    private fun detachActivity(answerPending: Boolean) {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        if (answerPending) finishPermissionRequest()
    }

    override fun onNewIntent(intent: Intent): Boolean = FlarePush.handleLaunchIntent(intent)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = context
        val methods = methods
        if (context == null || methods == null) {
            result.error("unavailable", "plugin is detached", null)
            return
        }
        // 打开设置页尽量用当前页面：不用另起任务。
        val opener = activityBinding?.activity ?: context
        when (call.method) {
            "start" -> {
                install(context, call)
                result.success(null)
            }
            "attach" -> {
                FlutterPushHosts.attach(methods)
                // 补报权限与令牌，解析接上之前留下的点击。
                FlarePush.refresh()
                result.success(null)
            }
            "detach" -> {
                FlutterPushHosts.detach(methods)
                result.success(null)
            }
            "signOut" -> {
                // 登出不分是哪个引擎接上的宿主：账号已经退出。
                FlutterPushHosts.clear()
                FlarePush.signOut()
                result.success(null)
            }
            "setLocale" -> {
                FlarePush.setLocale(call.arguments as? String)
                result.success(null)
            }
            "permissionStatus" -> result.success(FlarePushPermission.status(context).wireValue)
            // 没有页面时 opener 是应用上下文，模块按弹不了框答 false。
            "canRequestPermission" -> result.success(FlarePushPermission.canRequest(opener))
            "requestPermission" -> requestPermission(context, result)
            "openNotificationSettings" -> result.success(FlarePushPermission.openSettings(opener))
            "installGetui" -> result.success(installGetui(context))
            "backgroundStatus" -> result.success(backgroundStatus(context))
            "openBatterySettings" ->
                result.success(FlareBackgroundRestrictions.openBatteryOptimizationSettings(opener))
            "openAutoStartSettings" -> result.success(FlareBackgroundRestrictions.openAutoStartSettings(opener))
            "clearNotifications" -> {
                val collapseIds = (call.argument<List<Any?>>("collapseIds")).orEmpty()
                    .mapNotNull { (it as? String)?.takeIf(String::isNotBlank) }
                FlarePush.clearNotifications(collapseIds)
                if (collapseIds.isNotEmpty()) {
                    FlutterPushHosts.attachedTo(methods)?.correct(PlatformNotificationCorrection.Clear(collapseIds))
                }
                result.success(null)
            }
            "clearAllNotifications" -> {
                FlarePush.clearAllNotifications()
                // 经宿主再走一遍：模块在会话结束时换掉本模块通知的点击凭据。
                FlutterPushHosts.attachedTo(methods)?.correct(PlatformNotificationCorrection.ClearAll)
                result.success(null)
            }
            "setBadge" -> {
                // 桌面图标的角标由模块按启动器的能力写（只有接上宿主时）。
                val count = PlatformPushWire.int(call.argument<Any>("count"))?.coerceAtLeast(0)
                if (count != null) {
                    FlutterPushHosts.attachedTo(methods)?.correct(PlatformNotificationCorrection.Badge(count))
                }
                result.success(null)
            }
            "presentNotification" -> {
                // 链路在线时引擎出的通知：交给宿主，后台展示器接上时模块发出，没接上时丢掉。
                val presentation = (call.arguments as? Map<*, *>)?.let(PlatformPushWire::presentation)
                if (presentation != null) FlutterPushHosts.attachedTo(methods)?.deliver(presentation)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** 装上推送模块；再装一次什么都不做（模块自己保证）。 */
    @SuppressLint("DiscouragedApi")
    private fun install(context: Context, call: MethodCall) {
        val application = context.applicationContext as? Application ?: return
        // 图标按资源名给：Dart 拿不到资源 id。
        val smallIcon = call.argument<String>("smallIcon")
            ?.takeIf { it.isNotBlank() }
            ?.let { context.resources.getIdentifier(it, "drawable", context.packageName) }
            ?: 0
        FlarePush.install(
            application,
            hostProvider = { FlutterPushHosts.current() },
            options = FlarePushOptions(
                fcm = call.argument<Boolean>("fcm") ?: true,
                smallIcon = smallIcon,
                color = (call.argument<Any>("color") as? Number)?.toInt(),
                // 只记错误类型：不带令牌与载荷。
                onError = { error -> Log.w(TAG, "push: ${error.javaClass.simpleName}") },
            ),
        )
    }

    /**
     * 经模块弹系统授权框（模块记下问过，三态才分得清没问过与拒绝过），答复之后的三态权限。系统不会弹框时
     * （Android 13 以前、已经授权、拒绝到不再弹框）或没有页面可弹时不申请：不发一次没有框的空申请，照报权限、
     * 答复现状，由应用决定是否引导去设置。
     */
    private fun requestPermission(context: Context, result: MethodChannel.Result) {
        // 先看有没有框正开着：开着时模块已记下问过，再判断能不能弹会误答成拒绝。
        if (pendingPermission != null) {
            result.error("busy", "a permission request is showing", null)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null || !FlarePushPermission.canRequest(activity)) {
            FlarePush.refresh()
            result.success(FlarePushPermission.status(context).wireValue)
            return
        }
        pendingPermission = result
        FlarePushPermission.request(activity, REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        finishPermissionRequest()
        return true
    }

    private fun finishPermissionRequest() {
        val result = pendingPermission ?: return
        pendingPermission = null
        // 结果（包括拒绝）报给引擎，三态权限随之更新并转给 Dart。
        FlarePush.refresh()
        val context = context
        result.success(
            context?.let { FlarePushPermission.status(it).wireValue }
                ?: FlarePushPermissionStatus.DENIED.wireValue,
        )
    }

    /**
     * 个推是可选模块：插件不依赖它，按类名反射调 `FlareGetuiPush.install`。应用自己把
     * `flare-core-android-push-getui` 加进依赖并配好个推参数；没加时返回 false。
     */
    private fun installGetui(context: Context): Boolean = try {
        val type = Class.forName(GETUI_CLASS)
        val instance = type.getField("INSTANCE").get(null)
        type.getMethod("install", Context::class.java).invoke(instance, context.applicationContext ?: context)
        true
    } catch (missing: ClassNotFoundException) {
        false
    } catch (failed: InvocationTargetException) {
        // 只记错误类型：个推的异常消息里可能带设备标识。
        Log.w(TAG, "Getui install failed: ${failed.targetException?.javaClass?.simpleName}")
        false
    } catch (error: ReflectiveOperationException) {
        Log.w(TAG, "Getui install unavailable: ${error.javaClass.simpleName}")
        false
    }

    /** 后台限制的现状，形状与 Dart 的 `FlarePushBackgroundStatus` 一致。 */
    private fun backgroundStatus(context: Context): Map<String, Any> {
        val vendor = FlareBackgroundRestrictions.vendor()
        return mapOf(
            "delivery" to FlareBackgroundRestrictions.delivery(context).wireValue,
            "ignoringBatteryOptimizations" to FlareBackgroundRestrictions.isIgnoringBatteryOptimizations(context),
            "backgroundRestricted" to FlareBackgroundRestrictions.isBackgroundRestricted(context),
            "vendor" to vendor.wireValue,
            "hasAutoStartSettings" to vendor.hasAutoStartSettings,
        )
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        val scope = scope ?: return
        routeJob?.cancel()
        // 模块只缓存最新一条去向，没人收集时也不丢；同一时间只该有一个收集者。
        routeJob = scope.launch {
            FlarePush.routes.collect { route -> sink.success(PlatformPushWire.tapResult(route)) }
        }
    }

    override fun onCancel(arguments: Any?) {
        routeJob?.cancel()
        routeJob = null
    }

    private companion object {
        const val METHOD_CHANNEL = "im.flare.push"
        const val ROUTES_CHANNEL = "im.flare.push/routes"
        const val PERMISSION_CHANGED = "permissionChanged"
        const val BACKGROUND_CHANGED = "backgroundChanged"
        const val GETUI_CLASS = "com.flare.im.push.getui.FlareGetuiPush"

        /** 通知权限的申请码，与应用自己的申请错开。 */
        const val REQUEST_CODE = 0x4650
        const val TAG = "FlarePush"
    }
}
