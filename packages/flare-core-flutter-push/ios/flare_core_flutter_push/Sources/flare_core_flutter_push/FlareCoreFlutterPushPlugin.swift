import FlarePlatformPush
import Flutter
import UIKit

/// 系统推送的 Flutter 桥（iOS）。通知权限、APNs 令牌、静默推送、前台展示、点击、角标、登出清理与宿主调用的上限
/// 都由 `FlarePlatformPush` 处理；这里把它的宿主调用转给 Dart（`FlutterChannelPushHost`），把点击去向与权限交回 Dart。
///
/// - 方法通道 `im.flare.push`：Dart 调 `start`、`attach`、`detach`、`signOut`、`setLocale`、`permissionStatus`、
///   `canRequestPermission`、`requestPermission`、`openNotificationSettings`，以及引擎更正的落地
///   `clearNotifications`（`{collapseIds}`）、`clearAllNotifications`、`setBadge`（`{count}`）；原生调 Dart 的是宿主的
///   五个方法与 `permissionChanged`。个推与后台限制只在 Android 上有，Dart 在 iOS 上不调，也收不到 `backgroundChanged`。
/// - 事件通道 `im.flare.push/routes`：点击去向 `{conversationId, messageId?, seq?}`。
///
/// 通知中心的代理由平台模块自己装（`PlatformPush.start()`），应用不要再设别的代理。
public final class FlareCoreFlutterPushPlugin: NSObject, FlutterPlugin {
    private static let methodChannelName = "im.flare.push"
    private static let routesChannelName = "im.flare.push/routes"

    /// 在 `application(_:didFinishLaunchingWithOptions:)` 里、`super` 之前调用。用 UIScene 的应用，插件在场景连接时
    /// 才注册，晚于启动结束：冷启动的点击要在那之前装好通知中心代理，推送把应用拉起到后台时（没有场景、没有引擎）
    /// APNs 回调也要有人接。没调时插件注册时补上，只对不用 UIScene 的应用够用。
    public static func prepare() {
        PushBridge.shared.prepare()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = PushBridge.shared
        bridge.prepare()
        let messenger = registrar.messenger()
        let channel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        let plugin = FlareCoreFlutterPushPlugin(bridge: bridge, channel: channel)
        registrar.addMethodCallDelegate(plugin, channel: channel)
        FlutterEventChannel(name: routesChannelName, binaryMessenger: messenger).setStreamHandler(plugin.routes)
        if bridge.takeApplicationCallbacks() {
            registrar.addApplicationDelegate(plugin)
        }
        registrar.publish(plugin)
    }

    private let bridge: PushBridge
    private let channel: FlutterMethodChannel
    private let routes: PushRouteStream
    private let permissions: PushPermissionForwarder

    init(bridge: PushBridge, channel: FlutterMethodChannel) {
        self.bridge = bridge
        self.channel = channel
        self.routes = PushRouteStream(push: bridge.push)
        self.permissions = PushPermissionForwarder(push: bridge.push, channel: channel)
        super.init()
    }

    /// 引擎没了，经它转给 Dart 的宿主也就没了：之后的推送按载荷提示，点击留到下次接上。
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        routes.cancel()
        permissions.cancel()
        bridge.detach(channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let push = bridge.push
        switch call.method {
        case "start":
            // 平台模块在应用启动时已经开始；这里只是确认
            bridge.prepare()
            result(nil)
        case "attach":
            bridge.attach(channel: channel)
            result(nil)
        case "detach":
            bridge.detach(channel: channel)
            result(nil)
        case "signOut":
            let bridge = self.bridge
            Task {
                await bridge.signOut()
                await MainActor.run { result(nil) }
            }
        case "setLocale":
            push.setLocale(call.arguments as? String)
            result(nil)
        case "permissionStatus":
            Task {
                // 插件注册时平台模块已经启动，读得到；万一没有按拒绝答，Dart 只会引导去设置
                let status = await push.permissionStatus() ?? .denied
                await MainActor.run { result(status.rawValue) }
            }
        case "canRequestPermission":
            Task {
                // 系统授权框一个应用只弹一次：还没决定时才弹得出来
                let status = await push.permissionStatus()
                await MainActor.run { result(status == .notDetermined) }
            }
        case "requestPermission":
            Task {
                // 已经决定过时系统不会再弹框：不申请，直接答现状，由应用决定是否引导去设置；
                // 申请的结果（包括拒绝）平台模块自己报给宿主，权限变化也经 `permissionChanged` 回到 Dart
                var status = await push.permissionStatus() ?? .denied
                if status == .notDetermined {
                    await push.requestAuthorization()
                    status = await push.permissionStatus() ?? .denied
                }
                let answer = status.rawValue
                await MainActor.run { result(answer) }
            }
        case "openNotificationSettings":
            Task {
                let opened = await push.openNotificationSettings()
                await MainActor.run { result(opened) }
            }
        case "clearNotifications":
            let arguments = call.arguments as? [String: Any]
            let collapseIds = (arguments?["collapseIds"] as? [Any] ?? []).compactMap { $0 as? String }
            Task {
                await push.clearNotifications(collapseIds: collapseIds)
                await MainActor.run { result(nil) }
            }
        case "clearAllNotifications":
            Task {
                await push.clearAllNotifications()
                await MainActor.run { result(nil) }
            }
        case "setBadge":
            let count = ((call.arguments as? [String: Any])?["count"] as? NSNumber)?.intValue ?? 0
            Task {
                await push.setBadge(count)
                await MainActor.run { result(nil) }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 应用代理回调：只在应用代理没直接接上时注册（见 `PushBridge.takeApplicationCallbacks()`）

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        bridge.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        bridge.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Bool {
        bridge.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
}
