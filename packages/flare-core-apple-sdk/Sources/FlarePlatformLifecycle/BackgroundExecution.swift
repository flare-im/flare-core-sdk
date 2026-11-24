import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// 系统给的一段后台执行时间。`end()` 可以重复调用，只有第一次生效；系统收回时间时它也会被结束。
public final class PlatformBackgroundTask: @unchecked Sendable {
    private let lock = NSLock()
    private var release: (() -> Void)?

    public init(release: @escaping () -> Void) {
        self.release = release
    }

    /// 已经结束（主动结束或被系统收回）。
    public var ended: Bool {
        lock.lock()
        defer { lock.unlock() }
        return release == nil
    }

    public func end() {
        lock.lock()
        let release = self.release
        self.release = nil
        lock.unlock()
        release?()
    }
}

/// 向系统申请后台执行时间的地方。
public protocol PlatformBackgroundExecution: AnyObject, Sendable {
    /// 在调用线程上同步申请；不在应用进程里（扩展、测试、命令行）或系统拒绝时返回 nil。
    func begin(name: String) -> PlatformBackgroundTask?
}

#if canImport(UIKit) && !os(watchOS)
enum SharedApplication {
    /// `UIApplication.shared` 对应用扩展不可用；运行时查找，包仍能链接进扩展（扩展里取到 nil）。
    static var current: UIApplication? {
        let selector = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: selector),
              let application = UIApplication.perform(selector)?.takeUnretainedValue() as? UIApplication else {
            return nil
        }
        return application
    }
}
#endif
