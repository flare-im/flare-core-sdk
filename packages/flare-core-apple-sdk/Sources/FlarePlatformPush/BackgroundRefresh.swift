import Foundation
#if os(iOS) && canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// 系统交来的一次后台刷新（iOS 的 `BGAppRefreshTask`）。
public protocol PlatformBackgroundRefreshTask: AnyObject, Sendable {
    /// 系统要提前收回时间时调用。
    func setExpirationHandler(_ handler: @escaping @Sendable () -> Void)
    /// 告诉系统做完了；只有第一次算数。
    func complete(success: Bool)
}

/// 系统后台任务调度里本模块用到的部分。
public protocol PlatformBackgroundRefreshScheduler: AnyObject, Sendable {
    /// 登记 `identifier` 的处理函数。iOS 只在应用启动返回之前接受登记，标识还要列在 Info.plist 的
    /// `BGTaskSchedulerPermittedIdentifiers` 里，不在时抛 `PlatformPushConfigurationError.backgroundRefreshNotPermitted`。
    /// 没有后台刷新的平台什么也不做。
    func register(
        identifier: String,
        launchHandler: @escaping @Sendable (any PlatformBackgroundRefreshTask) -> Void
    ) throws
    /// 提交一次不早于 `earliest` 的刷新；同一标识只留最后提交的那次。
    func schedule(identifier: String, earliest: Date) throws
    /// 撤掉还没运行的那次。
    func cancel(identifier: String)
}

/// iOS 的 `BGTaskScheduler`；其余平台什么也不做。
public final class SystemBackgroundRefreshScheduler: PlatformBackgroundRefreshScheduler, @unchecked Sendable {
    public init() {}

    public func register(
        identifier: String,
        launchHandler: @escaping @Sendable (any PlatformBackgroundRefreshTask) -> Void
    ) throws {
        #if os(iOS) && canImport(BackgroundTasks)
        // 不在许可列表里的标识，系统登记时直接抛异常终止进程：先查
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        guard permitted.contains(identifier) else {
            throw PlatformPushConfigurationError.backgroundRefreshNotPermitted(identifier)
        }
        LaunchHandlers.shared.install(identifier, launchHandler) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
                LaunchHandlers.shared.run(identifier, SystemBackgroundRefreshTask(task))
            }
        }
        #endif
    }

    public func schedule(identifier: String, earliest: Date) throws {
        #if os(iOS) && canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliest
        try BGTaskScheduler.shared.submit(request)
        #endif
    }

    public func cancel(identifier: String) {
        #if os(iOS) && canImport(BackgroundTasks)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        #endif
    }
}

#if os(iOS) && canImport(BackgroundTasks)
/// 进程里每个标识只向系统登记一次（重复登记系统直接抛异常）；之后再登记只换处理函数。
/// 系统交来任务时没有处理函数（推送模块已经释放），任务按失败结束。
private final class LaunchHandlers: @unchecked Sendable {
    static let shared = LaunchHandlers()

    private let lock = NSLock()
    private var handlers: [String: @Sendable (any PlatformBackgroundRefreshTask) -> Void] = [:]
    private var registered: Set<String> = []

    func install(
        _ identifier: String,
        _ handler: @escaping @Sendable (any PlatformBackgroundRefreshTask) -> Void,
        register: () -> Bool
    ) {
        lock.lock()
        handlers[identifier] = handler
        let first = registered.insert(identifier).inserted
        lock.unlock()
        if first, !register() {
            lock.lock()
            registered.remove(identifier)
            lock.unlock()
        }
    }

    func run(_ identifier: String, _ task: any PlatformBackgroundRefreshTask) {
        lock.lock()
        let handler = handlers[identifier]
        lock.unlock()
        guard let handler else {
            task.complete(success: false)
            return
        }
        handler(task)
    }
}

/// `BGTask` 的包装：完成只报一次。
private final class SystemBackgroundRefreshTask: PlatformBackgroundRefreshTask, @unchecked Sendable {
    private let task: BGTask
    private let lock = NSLock()
    private var completed = false

    init(_ task: BGTask) {
        self.task = task
    }

    func setExpirationHandler(_ handler: @escaping @Sendable () -> Void) {
        task.expirationHandler = handler
    }

    func complete(success: Bool) {
        lock.lock()
        let first = !completed
        completed = true
        lock.unlock()
        if first {
            task.setTaskCompleted(success: success)
        }
    }
}
#endif
