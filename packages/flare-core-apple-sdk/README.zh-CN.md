# Flare Core Apple SDK

[English](README.md) · 中文

本包是 `flare-core-sdk-engine/bindings/c` 之上的类型化适配层。

- 状态：`contract-synced`
- 异步模型：async/await + AsyncStream
- FFI 契约：`flare-im-ffi/v2`

不要在这里加 IM 业务逻辑。行为加到 `flare-im-core-sdk`，经 `bindings/c` 暴露，再更新 `sdk-spec/manifest.json`。

## 平台推送（`FlarePlatformPush`）

与 `FlarePlatformLifecycle` 一样不依赖引擎：通知权限、APNs 登记、静默推送、前台展示、点击与角标。所有决定都归引擎，
模块问宿主（`FlarePushHost`）再照做。核心客户端的宿主是 `CorePushHost`，社交 SDK 的宿主是
`FlareSocialSdk.makePushHost()`。模块能链接进应用扩展，不做方法交换。

### 应用要加的

- **Push Notifications** 能力（`aps-environment` 授权）。APNs 环境取自内嵌的描述文件：`development` 登记为
  `sandbox`；没有描述文件的构建（App Store）登记为 `production`。
- **Background Modes → Remote notifications**（`UIBackgroundModes` 里的 `remote-notification`），静默推送才会运行
  应用代码。
- 下面的接线：在 `didFinishLaunching` 里启动，转发 App Delegate 的三个回调，会话恢复后接上宿主，登出交给模块，
  在用户明白缘由时申请权限，从 `routes()` 读点击。

```swift
import FlareCoreAppleSDK
import FlarePlatformPush

final class AppDelegate: NSObject, UIApplicationDelegate {
    let push = PlatformPush()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 在这里返回之前装上通知中心代理，冷启动的点击才送得到
        push.start()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        push.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        push.didFailToRegisterForRemoteNotifications(error: error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        push.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
}

// 会话恢复或用户登录之后：
appDelegate.push.attach(CorePushHost(client: client))
// 登出：摘下宿主，清掉本 SDK 的通知与角标，丢掉留着的点击，忘掉已登记的令牌，下一个账号重新登记。
await appDelegate.push.signOut()
// 应用自己有语言开关时，给应用内的语言：
appDelegate.push.setLocale("en-US")
// 设置页与提示：三态权限及其变化。
let status = await appDelegate.push.permissionStatus() // start() 之前为 nil
for await status in appDelegate.push.permissionChanges() { showPermission(status) }
// 用户明确操作时（引导页、设置开关）：
let granted = await appDelegate.push.requestAuthorization()
_ = await appDelegate.push.openNotificationSettings()
// 导航：
for await route in appDelegate.push.routes() {
    openConversation(route.conversationId, messageId: route.messageId)
}
```

### 接口

| 成员 | 作用 |
|---|---|
| `start(installDelegate:)` / `stop()` / `isStarted` | 启停；`isStarted` 表示能不能碰系统通知中心（测试与没有应用包的进程里为 false）。 |
| `attach(_:)` / `detach()` | 接上或摘下宿主。`detach` 把留着的点击留给下一个宿主。 |
| `signOut() async` | 摘下宿主，移除本 SDK 已展示与等待展示的通知（应用自己的不动），角标归零，丢掉留着的点击，忘掉已登记的令牌。 |
| `clearNotifications(collapseIds:) async` / `clearAllNotifications() async` / `setBadge(_:) async` | 手动落一条更正：按合并键撤（请求标识与载荷里的 `collapse_id`）、撤掉本 SDK 的全部通知、写角标。接着的宿主报来的更正不用它们也会照办。`start()` 之前什么也不做。 |
| `permissionStatus() async -> PlatformPushPermissionStatus?` | `notDetermined`、`denied` 或 `granted`；临时授权与短期授权算 `granted`。`start()` 之前为 nil。 |
| `permissionChanges() -> AsyncStream<PlatformPushPermissionStatus>` | 先给当前值，之后在启动、申请之后、每次回到前台重读，变了才发。 |
| `requestAuthorization(options:) async -> Bool` | 弹系统授权框；`start()` 之前返回 false。 |
| `openNotificationSettings() async -> Bool` | 本应用的通知设置（iOS 16 起），更早的系统是本应用的设置页。 |
| `setLocale(_:)` | 应用内的语言（BCP 47），令牌登记用它代替系统语言；变了立刻重新登记。nil 或空白回到系统语言。 |
| `routes()` | 点击去向，已经核对属于当前账号。 |
| `PlatformPushConfiguration` | `appGroupIdentifier`、`hasNotificationServiceExtension`、`backgroundRefreshTaskIdentifier`；见下文。 |
| `PlatformPushWire` | 契约 JSON（驼峰键）与值类型之间的转换，给经 JSON 透传的宿主用（社交 SDK、Flutter 桥）；`clearCorrection(_:)`、`badgeCorrection(_:)` 读 `notification.clear` 与 `notification.badge` 的载荷。 |
| `FlarePushHost.notificationCorrections()` | 宿主的更正流（`PlatformNotificationCorrection`：`clear(collapseIds:)`、`clearAll`、`badge(_:)`）。模块在接着宿主期间读它，`detach`、再次 `attach`、`signOut`、`stop` 时取消读取，宿主在流结束时退掉事件订阅。`CorePushHost` 把客户端的 `notification.clear` 与 `notification.badge` 事件转成它。 |

### 行为

- 权限（包括拒绝）在启动、`attach` 和每次回到前台时报给宿主。引擎每个进程都从未授权开始。
- 令牌连同包名、APNs 环境、语言、时区、应用版本一起登记，其中任一项变了（回到前台时检查，`setLocale` 之后立刻检查）
  就重新登记。
- 宿主调用的上限在模块里：远程推送约 3 秒（`remoteMessageTimeoutMs`），超时按载荷提示；其余调用约 15 秒
  （`hostCallTimeoutMs`），超时的留到下次同步。超时的调用被取消，以 `PlatformPushHostTimeout` 报给 `onError`，卡住的
  宿主拖不住系统回调。
- 前台收到本 SDK 的推送时问宿主：核心在应用内提示时不展示，否则出横幅；静默更新只进通知列表。
- 静默推送交给引擎，唤醒预算 20 秒。按结果处理：补一条以合并键为标识的本地通知（替换带同一 `apns-collapse-id` 的
  APNs 通知），静默更新用 passive；清除时按标识、也按每条已展示通知里的 `collapse_id` 移除；写角标。唤醒和托管交接
  结束后才回调系统。
- 宿主接上之前（推送把进程冷启动起来、会话还没恢复），静默推送按载荷原样提示，提示不丢；最近一次点击留着，接上宿主后
  再路由。解析到一半时账号登出，结果作废。
- 接着宿主期间，引擎的更正直接落到通知中心：会话在本机或别的设备上读了就撤掉它的通知，会话结束撤掉本 SDK 的全部通知，
  每次 `notification.badge` 都写角标。应用运行时角标因此始终是引擎报的未读总数；进了后台用推送带的角标。离开应用时
  模块不再自己写角标。
- `FlarePlatformLifecycle` 在进后台的通知回调里申请后台执行，`lifecycle.setAppState(background)` 返回后结束；iOS 上
  它在托管交接完成后才返回。
- macOS：展示、点击、角标可用；不登记 APNs（桌面端没有推送绑定）。

### 通知扩展与后台刷新

两样都由 `PlatformPushConfiguration` 打开，经 `PlatformPush(configuration:)` 传入：

```swift
let push = PlatformPush(configuration: PlatformPushConfiguration(
    appGroupIdentifier: "group.com.example.app",
    hasNotificationServiceExtension: true,
    backgroundRefreshTaskIdentifier: "com.example.app.refresh"
))
```

- **App Group。** `attach` 时模块建好 `<App Group 容器>/flare-notify` 并交给宿主
  （`FlarePushHost.setNotificationSnapshotDirectory`，即引擎的 `notification.setSnapshotDirectory`）。引擎在那里写
  `snapshot.json`（会话标题、显示名、预览设置、按语言渲染好的兜底文案），并读走扩展记下的 `receipts.log`。应用没有权限的
  App Group 以 `PlatformPushConfigurationError.appGroupUnavailable` 报给 `onError`。
- **通知扩展。** 加一个 Notification Service Extension 目标，只链接 `FlareNotificationService` 这个 product（不带引擎、
  不带 FFI），与应用共用 App Group：

  ```swift
  import FlareNotificationService

  final class NotificationService: FlareNotificationServiceBase {
      override var appGroupIdentifier: String { "group.com.example.app" }
  }
  ```

  它的 `Info.plist` 里 `NSExtensionPointIdentifier` 为 `com.apple.usernotifications.service`，`NSExtensionPrincipalClass`
  指向这个类。声明了 `hasNotificationServiceExtension` 且 App Group 可用时，令牌登记带 `serviceExtension`，服务端给提示
  推送加 `mutable-content`。扩展只读一次快照（典型 50ms、8 MiB 以内）：标题取本地的会话标题，按预览设置处理正文
  （`hidden` 用通用标题与正文；`sender_only` 用「发来一条消息」，群聊前面接发送者；`full` 用服务端正文并把发送者换成本地
  名字），追加一行到达回执（带推送发给的用户与租户，引擎只收当前会话这个账号的），不写任何日志。快照不在、或属于别的
  用户或租户时，推送按服务端文案原样展示，回执照记。摘要原样不动。
- **后台刷新。** 标识要列在 `BGTaskSchedulerPermittedIdentifiers` 里，`UIBackgroundModes` 要有 `fetch`。`start()` 登记
  `BGAppRefreshTask`（所以要在 `didFinishLaunching` 里调；标识不在列表里时以
  `PlatformPushConfigurationError.backgroundRefreshNotPermitted` 报出，不登记）。接着宿主期间每次进后台排下一次，不早于
  15 分钟后；运行时最多等 3 秒宿主（冷启动时会话正在恢复），先排好下一次，再调
  `FlarePushHost.backgroundRefresh(budgetMs: 25000)`（引擎的 `notification.backgroundRefresh`：一次唤醒加增量同步），按结果
  结束任务。系统提前收回时间时按未完成结束；`signOut()` 撤掉排着的那次。
- 只转发令牌、推送与点击的宿主不用实现这两个宿主方法：缺省不写快照，后台刷新按未完成结束。`CorePushHost` 与社交 SDK
  的宿主两个都实现。

### 应用不要做的

- 启动时申请通知权限。模块自己从不弹窗。
- 在 `start()` 之后另设 `UNUserNotificationCenter` 代理。自己当代理的应用调 `start(installDelegate: false)`，在
  `PlatformPushPayload.isFlare(userInfo:)` 为真时把两个代理方法转进来。
- 自己调 `updatePushToken`、`setPushPermission`、`handleRemoteMessage`，加会交换 App Delegate 方法的厂商 SDK，或者
  记录、保存令牌。
- 自己读 `UNUserNotificationCenter` 的权限，或在登出时自己清通知、清角标：用 `permissionStatus()`、
  `permissionChanges()` 与 `signOut()`。
- 自己撤已读会话的通知，或按自己算的未读数写角标：接着的宿主报来的更正会做。`CorePushHost` 要听得到事件，核心客户端的
  原生事件订阅（`client.events.subscribeEvents`，应用为自己的事件本来就会打开）要开着。
- 自己为本 SDK 的推送展示通知，或者赶在模块之前回调静默推送的完成处理。
- 释放 `PlatformPush` 对象：通知中心对代理是弱引用。
