import FlutterMacOS
import Foundation

/// 桌面系统通知的 Flutter 桥（macOS）。展示、替换、撤除、Dock 角标与点击都在 [DesktopNotificationPresenter]；
/// 这里只接方法通道与点击的事件通道。macOS 上没有推送绑定：桌面自己提示，Dart 的 `FlarePush` 在这里什么也不调。
///
/// - 方法通道 `im.flare.push/presenter`：Dart 调 `attach`（答 `{attached, backend}`）、`detach`、
///   `present`（引擎 `NotificationPresentation` 的形状）、`clear`（`{collapseIds}`）、`clearAll`、`setBadge`（`{count}`）、
///   `permissionStatus`、`requestPermission`。
/// - 事件通道 `im.flare.push/presenter/taps`：点击去向 `{conversationId, messageId?, seq?}`；没人监听时留着最近一条。
///
/// 通知中心的代理在注册时装上，应用不要再设别的代理（设了也行：本插件的通知以外的交还给原来那个）。
public final class FlareCoreFlutterPushPlugin: NSObject, FlutterPlugin {
    private static let methodChannelName = "im.flare.push/presenter"
    private static let tapsChannelName = "im.flare.push/presenter/taps"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let presenter = DesktopNotificationPresenter.shared
        let plugin = FlareCoreFlutterPushPlugin(presenter: presenter)
        presenter.onTap = { [weak plugin] route in plugin?.taps.emit(route) }
        presenter.prepare()
        let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(plugin, channel: methods)
        FlutterEventChannel(name: tapsChannelName, binaryMessenger: registrar.messenger).setStreamHandler(plugin.taps)
    }

    private let presenter: DesktopNotificationPresenter
    private let taps = PresenterTapStream()

    init(presenter: DesktopNotificationPresenter) {
        self.presenter = presenter
        super.init()
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        presenter.onTap = nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        case "attach":
            presenter.prepare()
            result(["attached": true, "backend": "userNotificationCenter"])
        case "detach":
            // 已经出的通知留着；登出时 Dart 另调 clearAll
            result(nil)
        case "present":
            if let arguments, let presentation = DesktopPresentation(wire: arguments) {
                presenter.present(presentation)
            }
            result(nil)
        case "clear":
            let collapseIds = (arguments?["collapseIds"] as? [Any] ?? []).compactMap { $0 as? String }
            presenter.clear(collapseIds)
            result(nil)
        case "clearAll":
            presenter.clearAll()
            result(nil)
        case "setBadge":
            presenter.setBadge((arguments?["count"] as? NSNumber)?.intValue ?? 0)
            result(nil)
        case "permissionStatus":
            presenter.permissionStatus { result($0) }
        case "requestPermission":
            presenter.requestPermission { result($0) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

/// 点击的事件通道。没人监听时只留最近一条（点通知把应用拉起来、Dart 还没登录监听），监听时补发。
final class PresenterTapStream: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink?
    private var pending: [String: Any]?

    /// 在主线程上调。
    func emit(_ route: [String: Any]) {
        if let sink {
            sink(route)
        } else {
            pending = route
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        if let route = pending {
            pending = nil
            events(route)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}
