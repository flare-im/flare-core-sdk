import FlarePlatformPush
import Flutter
import Foundation

/// 把宿主调用转给 Dart（`FlarePush.attach` 接上的宿主）。线上形状是引擎契约的 JSON（驼峰键），读写用平台模块的
/// `PlatformPushWire`。
///
/// 等多久由平台模块定（远程推送约 3 秒，其余约 15 秒）：模块等不及时取消这次调用，这里随之按取消失败，
/// Dart 晚到的答复丢掉。
final class FlutterChannelPushHost: FlarePushHost, @unchecked Sendable {
    private let channel: FlutterMethodChannel

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func updatePushToken(_ token: PlatformPushToken) async throws {
        _ = try await invoke("updatePushToken", PlatformPushWire.tokenRequest(token))
    }

    func setPushPermission(allowed: Bool) async throws {
        _ = try await invoke("setPushPermission", ["allowed": allowed])
    }

    func reconcilePush() async throws {
        _ = try await invoke("reconcilePush", nil)
    }

    func handleRemoteMessage(
        provider: String,
        payload: [String: String],
        budgetMs: UInt32
    ) async throws -> PlatformPushOutcome {
        let answer = try await invoke(
            "handleRemoteMessage",
            ["provider": provider, "payload": payload, "budgetMs": Int(budgetMs)]
        )
        return try PlatformPushWire.outcome(answer)
    }

    func resolveNotificationTap(payload: [String: String]) async throws -> PlatformTapRoute? {
        let answer = try await invoke("resolveNotificationTap", ["payload": payload])
        return PlatformPushWire.tapRoute(answer)
    }

    /// 更正由 Dart 那边直接转给平台模块（`FlarePush.attach` 订阅宿主的更正，经方法通道调 `clearNotifications` 等），
    /// 不经这里：给一个已经结束的流。
    func notificationCorrections() -> AsyncStream<PlatformNotificationCorrection> {
        AsyncStream { $0.finish() }
    }

    /// 方法通道只能在主线程上用。Dart 的答复与取消谁先到算谁。
    private func invoke(_ method: String, _ arguments: Any?) async throws -> Any? {
        let reply = PushReply()
        let channel = self.channel
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
                guard reply.wait(continuation) else { return }
                DispatchQueue.main.async {
                    channel.invokeMethod(method, arguments: arguments) { result in
                        if let error = result as? FlutterError {
                            reply.fail(FlutterPushHostError.dart(method: method, code: error.code))
                        } else if let object = result as? NSObject, object === FlutterMethodNotImplemented {
                            reply.fail(FlutterPushHostError.dart(method: method, code: "notImplemented"))
                        } else {
                            reply.succeed(result)
                        }
                    }
                }
            }
        } onCancel: {
            reply.cancel()
        }
    }
}

/// Dart 侧的宿主调用失败。只带方法名与错误码：消息里可能有令牌或载荷。
enum FlutterPushHostError: Error, CustomStringConvertible {
    case dart(method: String, code: String)

    var description: String {
        switch self {
        case let .dart(method, code):
            return "push host \(method) failed: \(code)"
        }
    }
}

/// 一次调用的答复只交一次；取消可能早于开始等待，那时等待直接按取消结束。
private final class PushReply: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Any?, Error>?
    private var cancelled = false

    /// 返回是否开始等待；已经取消时立即以取消结束。
    func wait(_ continuation: CheckedContinuation<Any?, Error>) -> Bool {
        lock.lock()
        let alreadyCancelled = cancelled
        if !alreadyCancelled {
            self.continuation = continuation
        }
        lock.unlock()
        if alreadyCancelled {
            continuation.resume(throwing: CancellationError())
        }
        return !alreadyCancelled
    }

    func succeed(_ value: Any?) {
        take()?.resume(returning: value)
    }

    func fail(_ error: Error) {
        take()?.resume(throwing: error)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let current = continuation
        continuation = nil
        lock.unlock()
        current?.resume(throwing: CancellationError())
    }

    private func take() -> CheckedContinuation<Any?, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let current = continuation
        continuation = nil
        return current
    }
}
