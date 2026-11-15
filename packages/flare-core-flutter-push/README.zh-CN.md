# flare_core_flutter_push

[English](README.md) · 中文

Flare 平台推送模块的 Flutter 桥：iOS 是 `FlarePlatformPush`，Android 是 `flare-core-android-push`。通知权限（三态）、
系统令牌、远程推送、通知渠道与展示、点击、角标、登出清理和宿主调用的上限都在原生模块里，提示怎么出由引擎决定。
这个插件把原生模块的宿主调用转给 Dart 侧接上的 `FlarePushHost`，再把点击去向和权限交回 Dart；Android 上另桥接可选的
个推模块与后台限制引导。

没有 Firebase 的 Dart 插件，也没有 Dart 后台入口。推送在 Flutter 起来之前把进程拉起，或者还没接上宿主时，
原生模块按载荷原样展示，提示不丢。

链路在线时提示由引擎自己决定并渲染（`notification.present`）。`FlareNotificationPresenter` 把其中展示面为 `system`
的弹出来：Android 上经推送模块的后台展示器，macOS、Linux、Windows 上经桌面的通知中心。

| 应用基于 | 宿主 |
|---|---|
| 核心客户端（`flare_core_flutter_sdk`） | `CorePushHost(client)` |
| 社交 SDK（`flare_social_flutter_sdk`） | `sdk.makePushHost()`（`FlareSocialPushHost`） |

宿主接口和它传的值（`FlarePushHost`、`PlatformPushToken`、`PlatformPushOutcome`、`PlatformTapRoute`……）在纯 Dart
的 `flare_core_flutter_sdk` 里，核心适配器才能实现它；本包原样导出。

## Dart 接口

```dart
final push = FlarePush.instance;

await push.start();                       // 启动时；从不弹框
await push.attach(CorePushHost(client));  // 登录或会话恢复之后
await push.setLocale('en-US');            // 应用自己有语言开关时，给应用内的语言
push.routes.listen((route) => openConversation(route.conversationId, route.messageId));

push.permissionChanges.listen(showPermission);  // 先给当前值，之后变了才发
final status = await push.permissionStatus();   // notDetermined、granted、denied

// 在用户能理解的时机：
if (await push.canRequestPermission()) {
  await push.requestPermission();               // 返回弹框之后的权限
} else if (status != FlarePushPermissionStatus.granted) {
  await push.openNotificationSettings();        // 系统不会再问
}

push.backgroundChanges.listen(showBackground);  // Android：先给当前值，之后变了才发

await push.signOut();                     // 登出时
```

| 成员 | 做什么 |
|---|---|
| `start({FlarePushOptions options})` | Android：装上原生模块（通知渠道、FCM 令牌、每次回前台重报权限、重读后台档位）。iOS：确认 `AppDelegate` 里已经开始。读一次权限，Android 上再读一次后台限制。可重复调用。 |
| `isStarted` | `start` 已经完成。 |
| `attach(FlarePushHost host)` | 宿主调用转给 `host`；重报令牌与权限，解析排队的点击。换了宿主令牌会重新登记。接着期间宿主的 `notificationCorrections()` 转给原生模块：已读会话的通知撤掉，会话结束全部撤掉，iOS 上每次 `notification.badge` 写角标。 |
| `detach()` | 客户端释放、账号没有退出时：推送又按载荷原样展示；点击等下一个宿主；更正不再转。 |
| `signOut()` | 摘下宿主，移除本 SDK 已展示与等待展示的通知（iOS 同时把角标清零），丢掉排队的点击，忘掉已登记的令牌，下一个账号重新登记。 |
| `setLocale(String? languageTag)` | 应用内的语言（BCP 47）代替系统语言用于令牌登记；变了立刻重新登记。null 回到系统语言。 |
| `permissionStatus()` | `FlarePushPermissionStatus.notDetermined`、`granted`（含 iOS 临时授权与短期授权）或 `denied`。 |
| `permissionChanges` | 已知时先给当前值，之后每次变化；原生模块在启动、申请之后与每次回到前台重读。 |
| `canRequestPermission()` | 现在申请会不会弹出系统授权框。Android：还没问过，或只拒绝过一次、系统建议先解释，而且有页面可弹；iOS：还没决定。为 `false` 而权限不是允许时，只能去设置页。 |
| `requestPermission()` | 系统会弹框时弹出系统授权框，返回之后的 `FlarePushPermissionStatus`；结果（包括拒绝）会报给引擎，`permissionChanges` 也会收到。系统不会弹框时（Android 上拒绝到不再弹框、iOS 上已经决定过）不申请，直接返回现状，由应用在申请与去设置页之间选。 |
| `openNotificationSettings()` | 本应用的系统通知设置。 |
| `clearNotifications(collapseIds)` / `clearAllNotifications()` / `setBadge(count)` | 手动落一条更正（iOS 按通知标识与载荷里的合并键撤，Android 按 tag 撤；角标只有 iOS）。接着的宿主报来的更正不用它们也会照办。 |
| `routes` | 引擎为当前账号解析出的点击去向。没人监听时原生模块留着最近一条。 |
| `installGetui()` | Android：应用带了个推模块时启用它（见下文）；没带或在 iOS 上返回 false。 |
| `backgroundStatus()` | Android：`FlarePushBackgroundStatus`（`delivery` 为 `FlarePushBackgroundDelivery.unrestricted` / `optimized` / `restricted`，以及 `ignoringBatteryOptimizations`、`backgroundRestricted`、`vendor`、`hasAutoStartSettings`）；iOS 上为 null。 |
| `backgroundChanges` | Android：已知时先给当前的 `FlarePushBackgroundStatus`，之后电池设置的档位每变一次给一份新的；原生模块在启动、接上宿主、申请权限之后与每次回到前台重读。iOS 上什么也不发。 |
| `openBatterySettings()` / `openAutoStartSettings()` | Android：电池优化列表与厂商的自启动管理页，打不开都退到应用详情页；iOS 上返回 false。 |
| `isSupported` | Android 与 iOS；其余平台上每个成员都什么也不做。 |

`FlarePushOptions`（只对 Android 有效）：`fcm`（登记 FCM 令牌，默认 true）、`smallIcon`（drawable 资源名，单色透明底）、
`color`（ARGB）。

更正由 Dart 这边转：原生那边自己的宿主不报更正，宿主的流只被监听一次。应用不用自己撤已读会话的通知、写角标。

通道：方法通道 `im.flare.push` 双向（Dart 调原生：上面这些成员，`clearNotifications` 带 `{collapseIds}`，`setBadge`
带 `{count}`，Android 上另有带展示面为 `system` 的 `NotificationPresentation` 的 `presentNotification`；原生调 Dart：
宿主的方法，形状是引擎契约的 JSON（`totalUnread` 与带 `{attached}` 的 `setBackgroundPresenter` 只有 Android 调），
带权限状态的 `permissionChanged`，以及 Android 上带后台限制现状对象的 `backgroundChanged`），事件通道
`im.flare.push/routes`（`{conversationId, messageId?, seq?}`）。

## 链路在线时的系统通知

```dart
final presenter = FlareNotificationPresenter.instance;

// 登录或会话恢复之后，宿主与 FlarePush.attach 的同一个。
await presenter.attach(host,
    options: const FlareNotificationPresenterOptions(
      windowsAppUserModelId: 'com.example.app', // 只有没打包的 Windows 应用要给
    ));
await presenter.requestPermission();      // macOS 只问一次；其余平台直接答现状
presenter.routes.listen((route) => openConversation(route.conversationId, route.messageId));

await presenter.signOut();                // 登出时
```

| 成员 | 做什么 |
|---|---|
| `kind` | `androidBackground`、`desktop`（macOS、Linux、Windows）或 `none`（iOS、Web 与其余平台）。 |
| `attach(host, {options})` | Android：告诉原生的后台展示器「要」（见下文）。桌面：把宿主的 `notificationPresentations()` 里展示面为 `system` 的与 `notificationCorrections()` 转给原生展示方。原生实际用的后端从 `backend` 读。 |
| `detach()` | 停下；已经出的通知留着。Android 上先直接告诉引擎 `setBackgroundPresenter(false)`，再告诉原生。 |
| `signOut()` | `detach()`，桌面上再撤掉本插件出的全部通知、角标清零（Android 由 `FlarePush.signOut()` 做）。 |
| `permissionStatus()` / `requestPermission()` | macOS：通知中心的授权，只在还没决定时弹框。Android：就是 `FlarePush` 的。Linux 与 Windows 没有授权这一步：答 `granted`，Windows 上用户在系统设置里关掉了本应用的通知时答 `denied`。 |
| `routes` | 桌面通知的点击 `{conversationId, messageId?, seq?}`；没人监听时原生留着最近一条。摘要通知不属于哪个会话，点了只把窗口带到前面。Android 的点击从 `FlarePush.routes` 出来。 |
| `backend` | 诊断用：`android`、`userNotificationCenter`、`freedesktop`、`toast`、`tray` 或 `none`。 |

宿主为此多了两个成员：`notificationPresentations()`（每一条 `notification.present`）与
`setBackgroundPresenter({attached})`（`notification.set_background_presenter`）。`CorePushHost` 与 `FlareSocialPushHost`
都实现了。

通道：方法通道 `im.flare.push/presenter`（Dart 调原生：带 `{windowsAppUserModelId?}` 的 `attach`，答
`{attached, backend}`；`detach`；桌面上另有带 `NotificationPresentation` 的 `present`、带 `{collapseIds}` 的 `clear`、
`clearAll`、带 `{count}` 的 `setBadge`、`permissionStatus`、`requestPermission`），事件通道
`im.flare.push/presenter/taps`（`{conversationId, messageId?, seq?}`）。

**Android。** `attach` 调 `FlareBackgroundPresenter.attach()`，由模块决定：应用要、接着宿主（`FlarePush.attach`）、
通知权限也允许时，模块经 `im.flare.push` 调宿主的 `setBackgroundPresenter(true)`，Dart 转给引擎，引擎在后台上报
`STANDBY`、照常确认、出系统展示面的通知。`FlarePush` 把这些通知（`presentNotification`）与更正转进 Kotlin 通道宿主的
流里，模块用推送的通知渠道发出：tag 是合并键，没有声音的静默替换，点击带模块自己的凭据。关掉通知权限会断开（模块报
`false`），重新授权自动接回。Flutter 的页面没了（`AppLifecycleState.detached`）时展示方摘下，插件离开引擎时撤回「要」。

**桌面。** 一个会话一条通知：合并键是通知的标识，新的替换旧的；没有声音的、`quiet` 渠道的安静送达（不弹横幅、不出声）。
点击把窗口带到前面，会话去向交回 Dart。桌面本来就自己提示：展示方从不调 `setBackgroundPresenter`。

- **macOS**（`UNUserNotificationCenter`，macOS 10.15 起）：请求标识 = 合并键，thread identifier = threadId，安静的用
  被动级 `interruptionLevel`（macOS 12 起），按标识撤除，角标写在 Dock 图标上。通知中心的代理在插件注册时装上（早于
  启动结束，点通知把应用拉起来的那一下也收得到）；之前已经有代理时，不是本插件的通知交还给它。SwiftPM 与 CocoaPods
  都能构建，runner 不用加东西。
- **Linux**（会话总线上的 `org.freedesktop.Notifications`，经 GDBus）：按合并键记住通知服务给的标识，作
  `replaces_id` 发出；`Notify` 还在途时下一条排着；`CloseNotification` 撤除；动作 `default` 是点击；安静的低紧急度，
  `urgent` 渠道紧急；通知服务支持 `body-markup` 时正文转义；`desktop-entry` 提示取 GApplication 的 id。没有角标。
- **Windows**（WinRT ABI 上的 toast，不用 C++/WinRT）：tag = 合并键，group 是 `flare`，同一会话的新 toast 替换通知中心里
  的旧的；安静的用 `SuppressPopup` 与静音；经 toast 历史撤除。toast 要有身份：打包（MSIX）的应用自带；没打包的应用把
  注册过的 AppUserModelID（带着它的开始菜单快捷方式，或 `HKCU\Software\Classes\AppUserModelId\<id>`）作为
  `windowsAppUserModelId` 传进来，或者给进程设一个。没有注册过的身份时退回托盘图标的气泡（`Shell_NotifyIconW`）。
  没有任务栏角标。

## Android

插件依赖 Gradle 工程 `:flare-core-android-push`。`flare-core-sdk` 没有根工程，由宿主的
`android/settings.gradle.kts` 登记：

```kotlin
include(":flare-core-android-push")
project(":flare-core-android-push").projectDir =
    file("<workspace>/flare-core-sdk/packages/flare-core-android-push")
```

FCM 要 `android/app/google-services.json` 里的 Firebase 客户端配置，以及只在这个文件存在时才应用的 Google 服务插件：

```kotlin
// settings.gradle.kts 的 plugins { }
id("com.google.gms.google-services") version "4.4.2" apply false

// app/build.gradle.kts
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
```

没有这个文件时 Firebase 不初始化，不登记 FCM 令牌，其余照常。`POST_NOTIFICATIONS`、FCM 服务与厂商通知的中转页都由
模块声明，应用不用声明，也不能再声明一个 `com.google.firebase.MESSAGING_EVENT` 服务。

个推（国内渠道）要应用自己选择启用：在模块旁边登记 `:flare-core-android-push-getui`，应用模块加
`implementation(project(":flare-core-android-push-getui"))`、个推的仓库与 `GETUI_APPID`（见那个模块的 README），
然后在 `start()` 之后、用户同意隐私政策之后调 `installGetui()`。插件本身不依赖个推模块，按类名启用它。

行为：

- `start` 调 `FlarePush.install(application, hostProvider, options)`。宿主经当前引擎接上时给出它，否则给 null。
  FCM 在后台冷启动的进程没有 Flutter 引擎：插件不在，模块按载荷展示。
- 启动页的意图在插件接上页面时和每次新意图时交给 `FlarePush.handleLaunchIntent`，去向从事件通道回来。
- `requestPermission` 只在 `FlarePushPermission.canRequest(activity)` 成立时经
  `FlarePushPermission.request(activity, requestCode)` 申请 `POST_NOTIFICATIONS`，由模块记下问过，否则答复现状；
  `canRequestPermission` 就是当前页面的 `FlarePushPermission.canRequest`。三态来自 `FlarePushPermission.status`，
  变化来自 `FlarePush.permission`。
- `backgroundStatus` 读 `FlareBackgroundRestrictions`，`backgroundChanged` 跟着 `FlarePush.backgroundDelivery`。
- `signOut` 调 `FlarePush.signOut()`，`setLocale` 调 `FlarePush.setLocale`。
- 宿主调用的上限由模块定：远程推送约 3 秒（之后按载荷展示），令牌、权限与点击 15 秒。

## iOS

插件用 Swift Package Manager 或 CocoaPods 构建，要 iOS 15（`FlarePlatformPush` 的下限）。

`FlarePlatformPush` 与 `FlarePlatformLifecycle` 不拷代码：源码是指向 `flare-core-apple-sdk` 的符号链接
（`ios/flare_core_flutter_push/Sources/`），按同名目标编译，推送模块里的 `import FlarePlatformLifecycle` 原样成立。
不能作包依赖：Flutter 把插件包经符号链接放进生成的包里，相对路径的包依赖在那里解析不到；podspec 也不能依赖 SwiftPM 产品。
`FlarePlatformPush` 新加源文件时，这里要补一条对应的链接。

- **SwiftPM**（Flutter 的 Swift Package Manager 集成）：什么都不用加。
- **CocoaPods**：这两个模块是插件 podspec 旁边的两个 pod，在 `Podfile` 的 `Runner` 目标里列出：

  ```ruby
  pod 'FlarePlatformLifecycle', :path => '.symlinks/plugins/flare_core_flutter_push/ios'
  pod 'FlarePlatformPush', :path => '.symlinks/plugins/flare_core_flutter_push/ios'
  ```

应用要加的：

- **Push Notifications** 能力（`Runner.entitlements` 里的 `aps-environment`；开发签名是 `development`，发行描述文件会换成
  production），以及 `Info.plist` 里的后台模式 `remote-notification`。
- `AppDelegate` 里、`super` 之前：

  ```swift
  import flare_core_flutter_push

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlareCoreFlutterPushPlugin.prepare()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  ```

  `prepare()` 启动 `PlatformPush`（通知中心代理、APNs 登记、前后台跟踪），并挂上 `FlutterAppDelegate` 的三个推送回调。
  用 UIScene 生命周期时插件在场景连接时才注册，晚于启动结束：冷启动的点击要更早装好代理，推送把应用拉起到后台时
  根本没有场景和引擎。不用场景的应用可以不调，插件注册时会做同样的事。

模块自己当通知中心的代理，应用不要再设别的代理。其余都是模块的：`permissionStatus` 与 `permissionChanged` 来自
`PlatformPush.permissionStatus()` 与 `permissionChanges()`。iOS 的授权框只弹一次：`canRequestPermission` 只在状态是
`notDetermined` 时为 true，`requestPermission` 也只在那时调 `PlatformPush.requestAuthorization()`，答复之后读到的状态。
`signOut` 就是 `PlatformPush.signOut()`，`setLocale` 就是
`PlatformPush.setLocale(_:)`，宿主调用的上限也在模块里（远程推送 3 秒，其余 15 秒），模块取消调用时插件的通道宿主随之放弃。
JSON 形状经 `PlatformPushWire` 读写。

## 已知限制

- **Flutter 的 iOS runner 没有通知扩展。** 原生 iOS 应用各加了一个（`flare-core-apple-sdk` 的
  `FlareNotificationService`），Flutter runner 这里没有：推送显示服务端渲染的文案，扩展那一路的到达回执也没有。
- **Android 后台展示器跟着 Flutter 引擎。** 只在 Dart isolate 还在跑时出通知。页面没了（`AppLifecycleState.detached`）
  时展示方摘下；要是这一下没在 Flutter 引擎拆掉之前到达引擎、进程又还活着，引擎会一直确认消息却没人提示，直到进程结束。
  要与页面无关的应用持有一个进程级的 Flutter 引擎。
- **Windows 没有注册 AppUserModelID** 时是托盘气泡：同一时间只有一个（新的不分会话顶掉旧的），撤除只收得走当前这个，
  点击只认当前这个，接着期间托盘图标一直在。toast 的点击只在应用运行时回来（没有 COM 激活器），上一次运行留下的 toast
  点了不会带回会话。
- **Linux 与 Windows 没有角标**；macOS 用 Dock 图标。
- **上一次运行留在通知中心里的桌面通知**（macOS、Windows）点击时不核对账号：登出会撤掉，登录着直接退出时留着。

## 测试

```bash
flutter test
```

测试在模拟通道上跑 Dart 侧。原生两侧由原生模块自己的测试覆盖；真机送达要签名、凭据和设备。
