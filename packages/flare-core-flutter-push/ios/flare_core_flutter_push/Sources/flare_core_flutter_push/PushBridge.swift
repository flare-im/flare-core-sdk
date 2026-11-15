import FlarePlatformPush
import Flutter
import UIKit

/// 进程里唯一的推送接入。通知中心的代理、APNs 令牌与静默推送都是进程级的：引擎可以有几个，也可以
/// 一个都没有（推送把应用拉起到后台时没有场景，也就没有引擎和插件）。
///
/// 权限、清通知、宿主调用的上限都在 `PlatformPush` 里，这里只做 Flutter 这一侧的接线。
final class PushBridge: NSObject, FlutterApplicationLifeCycleDelegate, @unchecked Sendable {
    static let shared = PushBridge()

    let push = PlatformPush(onError: { error in
        // 推送接入尽力而为；只记错误类型，不带令牌与载荷
        NSLog("FlarePush: %@", String(describing: type(of: error)))
    })

    private let lock = NSLock()
    private var prepared = false
    private var receivesApplicationCallbacks = false
    private var hostChannel: FlutterMethodChannel?

    /// 开始：装上通知中心代理、向 APNs 要令牌、开始跟踪前后台，再接上应用代理的三个推送回调。
    /// 在主线程上调用，越早越好：冷启动的点击只送给 `didFinishLaunching` 返回之前装好的代理。再调一次什么也不做。
    func prepare() {
        let first: Bool = locked {
            guard !prepared else { return false }
            prepared = true
            return true
        }
        guard first else { return }
        push.start()
        // 推送把应用拉起到后台时插件不会注册：直接挂到 FlutterAppDelegate 的生命周期回调上。
        // 按选择子调用，不依赖它导入 Swift 后被缩短的名字。
        let selector = NSSelectorFromString("addApplicationLifeCycleDelegate:")
        if let delegate = UIApplication.shared.delegate as? NSObject, delegate.responds(to: selector) {
            _ = delegate.perform(selector, with: self)
            locked { receivesApplicationCallbacks = true }
        }
    }

    /// 应用代理没接上（不是 FlutterAppDelegate）时，第一个注册的插件改用插件自己的应用代理回调。
    /// 只给一个，免得同一条推送处理两遍。
    func takeApplicationCallbacks() -> Bool {
        locked {
            guard !receivesApplicationCallbacks else { return false }
            receivesApplicationCallbacks = true
            return true
        }
    }

    // MARK: - 宿主

    /// Dart 接上宿主：之后的宿主调用经这个通道转给 Dart。每次都是新的宿主，令牌会重新登记。
    func attach(channel: FlutterMethodChannel) {
        locked { hostChannel = channel }
        push.attach(FlutterChannelPushHost(channel: channel))
    }

    /// 只摘这个通道接上的宿主：另一个引擎接上的不动。
    func detach(channel: FlutterMethodChannel) {
        let current: Bool = locked {
            guard hostChannel === channel else { return false }
            hostChannel = nil
            return true
        }
        if current {
            push.detach()
        }
    }

    /// 登出：不管是哪个引擎接上的宿主一律摘下，其余交给平台模块（清通知、角标归零、丢掉留着的点击、忘掉令牌）。
    func signOut() async {
        locked { hostChannel = nil }
        await push.signOut()
    }

    // MARK: - 应用代理回调

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        push.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        push.didFailToRegisterForRemoteNotifications(error: error)
    }

    /// 不是本 SDK 的推送不接，留给别的插件。
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Bool {
        guard PlatformPushPayload.isFlare(userInfo: userInfo) else { return false }
        push.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
        return true
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// 点击去向的事件流：Dart 监听时订阅平台模块的 `routes()`，取消时退订。没人订阅时模块留着最近一条。
final class PushRouteStream: NSObject, FlutterStreamHandler {
    private let push: PlatformPush
    private var task: Task<Void, Never>?

    init(push: PlatformPush) {
        self.push = push
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        task?.cancel()
        let routes = push.routes()
        task = Task {
            for await route in routes {
                let event = PlatformPushWire.tapResult(route)
                await MainActor.run { events(event) }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        cancel()
        return nil
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// 权限变化转给 Dart（方法通道上的 `permissionChanged`）。每个引擎一份，引擎没了就停。
final class PushPermissionForwarder {
    private var task: Task<Void, Never>?

    init(push: PlatformPush, channel: FlutterMethodChannel) {
        let changes = push.permissionChanges()
        task = Task {
            for await status in changes {
                await MainActor.run {
                    channel.invokeMethod("permissionChanged", arguments: status.rawValue)
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
