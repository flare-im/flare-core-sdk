# flare-core-android-push

[English](README.md) · 中文

Flare IM 的 Android 平台推送：FCM 消息服务、通知展示器与四个通知渠道、通知点击、通知权限，
以及后台限制的引导。

模块不依赖任何引擎包，经宿主适配器 `FlarePushHost` 调引擎，核心 SDK 与社交 SDK 复用同一份平台代码：

| 应用基于 | 宿主适配器 |
|---|---|
| 核心 SDK（`flare-core-android-sdk`） | `com.flare.im.push.CorePushHost(client)` |
| 社交 SDK（社交 Android 应用里的绑定） | `com.flare.social.app.ffi.FlareSocialPushHost(imDispatch)`，在社交 Android 应用里，与 `ffi/FlareSocialSdk.kt` 并列 |

国内渠道的构建再加 [`flare-core-android-push-getui`](../flare-core-android-push-getui/README.zh-CN.md)，
接个推与厂商通道。没有任何推送通道的部署可以加
[`flare-core-android-keepalive`](../flare-core-android-keepalive/README.zh-CN.md)（常驻连接模式，默认关）。

## 应用要加的

### 1. Gradle

在 `settings.gradle.kts` 里和其它模块并列登记：

```kotlin
include(":flare-core-android-push")
project(":flare-core-android-push").projectDir = file("<workspace>/flare-core-sdk/packages/flare-core-android-push")
```

`flare-core-android-sdk` 已经以 `api` 带上它，核心应用只需要 `include`。社交应用加
`implementation(project(":flare-core-android-push"))` 和社交 SDK 的源码。

### 2. Firebase（可选）

Firebase Messaging 总是编译进来，FCM 能不能用在运行期决定。

- 要 FCM：把 Firebase 客户端配置放在 `app/google-services.json`，应用模块加 Google 服务插件
  （`id("com.google.gms.google-services")`）。服务端的 FCM 凭据要属于同一个 Firebase 项目。
- 不要 FCM（没有 GMS、私有化部署、国内渠道）：不打包 `google-services.json`。Firebase 不会初始化，
  `FlarePush.isFcmAvailable(context)` 为 `false`，其余照常。已配置 Firebase 的构建也可以用
  `FlarePushOptions(fcm = false)` 不登记 FCM 令牌。

模块自己声明了 `FirebaseMessagingService`（`FlareFirebaseMessagingService`，不导出），应用不能再声明
第二个接收 `com.google.firebase.MESSAGING_EVENT` 的服务。

### 3. 通知权限

`POST_NOTIFICATIONS` 已在模块清单里声明，会并入应用。在用户能理解的时机申请，不要启动就弹，而且一律经
`FlarePushPermission.request`：模块记下自己问过，才分得清「还没问过」与「拒绝过」（Android 自己不给这个区分），
应用不用另记。

```kotlin
private val notifications = registerForActivityResult(ActivityResultContracts.RequestPermission()) {
    FlarePush.refresh() // 结果（包括拒绝）报给引擎，FlarePush.permission 随之更新
}

fun askForNotifications() {
    if (FlarePushPermission.canRequest(this)) {
        FlarePushPermission.request(this, notifications)
    } else if (!FlarePushPermission.isGranted(this)) {
        FlarePushPermission.openSettings(this) // 系统不会再弹授权框
    }
}

// 设置页那一行与首次提示：
FlarePush.permission.collect { status -> showPermission(status) } // install 之前为 null
```

Compose 里 `FlarePushPermission.canRequest(LocalContext.current)` 自己找到所在的页面。

| 成员 | 作用 |
|---|---|
| `FlarePushPermission.status(context)` | `NOT_DETERMINED`（Android 13 起、还没经模块问过）、`DENIED`（问过被拒，或在设置里关了）、`GRANTED`。`wireValue` 是 `notDetermined` / `denied` / `granted`，与 iOS、Dart 相同。 |
| `FlarePush.permission: StateFlow<FlarePushPermissionStatus?>` | 安装时、`refresh()` 时与每次回前台重读，变了才更新。 |
| `FlarePushPermission.request(context, launcher)` / `request(activity, requestCode)` | 需要时弹系统授权框，并记下问过。后一种给没有 `ActivityResultLauncher` 的宿主（Flutter 插件）。 |
| `FlarePushPermission.canRequest(activity)` / `canRequest(context)` | 授权框现在还会弹：还没问过，或只拒绝过一次、系统建议先解释。为 `false` 而通知没开时只能去设置页。`Context` 版沿 `ContextWrapper` 找到所在的页面，找不到为 `false`。 |
| `FlarePushPermission.openSettings(context)` | 本应用的通知设置，打不开退到应用详情页。 |

模块在安装时和每次回前台都会报当前状态，用户在系统设置里的改动不需要应用代码就能到引擎。

### 4. `Application.onCreate`

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        FlarePush.install(
            this,
            hostProvider = { signedInClient()?.let(::CorePushHost) },
            options = FlarePushOptions(smallIcon = R.drawable.ic_notification),
        )
    }
}
```

模块需要引擎时才调 `hostProvider`。它可以挂起等应用初始化完（被 FCM 冷启动的进程先跑 `onCreate`），
没人登录或会话还没恢复时返回 `null`。没有宿主时推送照样按载荷展示。

登录或恢复会话之后调 `FlarePush.refresh()`：报权限、重读后台档位、登记令牌、解析排队的点击。

一次会话用一个宿主（会话就绪时建好，登出之前一直给同一个实例）：模块按实例区分宿主，新实例会重新登记令牌、重新开始收集更正。

登出时调 `FlarePush.signOut()`（此后 `hostProvider` 给 `null`）：移除本模块发出的全部通知，丢掉排队的点击
（包括正在解析的、还没人收的去向），忘掉报过的令牌与权限，下一个账号的宿主（哪怕还是同一个实例）重新登记。

应用自己有语言开关时调 `FlarePush.setLocale("en-US")`（`null` 回到设备语言）：令牌登记用它代替系统语言，
令牌立刻重报。`FlarePush.isInstalled` 表示 `install` 是否调过。

### 5. 启动页

点击通知打开启动页（或 `FlarePushOptions.launchActivity`），载荷在 `flare_push` 附加数据里。
把每个意图交给模块，按它给出的去向导航：

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    FlarePush.handleLaunchIntent(intent)
    lifecycleScope.launch {
        repeatOnLifecycle(Lifecycle.State.STARTED) {
            FlarePush.routes.collect { route -> openConversation(route.conversationId, route.messageId) }
        }
    }
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    FlarePush.handleLaunchIntent(intent)
}
```

引擎核对载荷属于当前登录的账号后才给出去向；登录前到达的点击等下一次 `refresh()`。`routes`
只缓存最新一条，在收集前不丢；只在一处收集。

## 行为

**远程消息。** 发给 Android 的 FCM 是纯数据消息。消息服务把载荷交给 `handleRemoteMessage`（provider
为 `fcm`，唤醒预算 8 秒），最多等约 3 秒（`FlarePushOptions.hostTimeoutMs`，与 iOS 相同）。引擎的答复
决定怎么做：`present` 发一条可以响铃的通知，`update` 静默替换，`clear` 移除，`badgeOnly` 与 `ignore` 不发，
`surface = inApp`（应用在前台）时由应用内横幅提示。引擎来不及答复、没有会话或出错时，按载荷原样展示。

**宿主调用。** 其余宿主调用（令牌、权限、对账、点击）每次不超过 `FlarePushOptions.resolveTimeoutMs`（15 秒），
超时的留到下次 refresh。超时的调用被取消，以 `FlarePushHostTimeoutException`（只带方法名与上限）报给 `onError`。

**通知。** 一个会话一条通知：tag 取 `collapse_id`，id 固定，分组取 `thread_id`，`setNumber(count)`。
静默更新用 `setOnlyAlertOnce` 且不响铃。四个渠道：

| 渠道标识 | 名称（英 / 中） | 重要级 |
|---|---|---|
| `flare.messages` | Chat messages / 聊天消息 | 高，有声音 |
| `flare.quiet` | Silent chat updates / 聊天消息静默更新 | 低，无声音无振动 |
| `flare.mentions` | Mentions in chats / 聊天中@我的消息 | 高，有声音 |
| `flare.urgent` | Urgent chat messages / 紧急聊天消息 | 高，有声音 |

渠道名称跟随设备语言；渠道建好后重要级与声音归用户管。名称有意写成具体的聊天场景：vivo 备案渠道时驳回「消息」「推送」
这类宽泛名称（见[渠道备案](#渠道备案运营方)），具体的名称在其它厂商的通知设置里也一样好懂。

**更正。** 一个宿主成为当前宿主期间（从第一次拿到它的 refresh 或回前台起，到换了宿主或 `signOut`），模块收集
`FlarePushHost.notificationCorrections()` 并照办每条 `PlatformNotificationCorrection`：`Clear(collapseIds)` 按 tag
撤通知（会话在本机或别的设备上读了），`ClearAll` 撤掉本模块的全部通知（会话结束），`Badge(count)` 在有角标接口的桌面上
设角标（华为、荣耀，经它们桌面的角标提供者；权限与包可见性声明在模块清单里），其它桌面不做事，计数来自通知本身。推送答复
里已知的 `badge` 同样处理，`signOut` 把它归零。`CorePushHost` 把客户端的 `notification.clear` 与 `notification.badge` 事件转成这个流；客户端的
原生事件订阅（`client.events.subscribeEvents`，应用为自己的事件本来就会打开）要开着。宿主接口给了空的默认实现，不经
事件的宿主什么都不用写。`FlarePush.clearNotifications(collapseIds)` 与 `FlarePush.clearAllNotifications()` 可以手动落
一条更正，应用用不着。`PlatformPushWire.clearCorrection`、`badgeCorrection` 给经 JSON 透传的宿主读事件载荷。

**令牌。** 每个令牌登记时带 `platform = android`、`appBundle`（applicationId）、`locale`、`timeZone`、
`appVersion`；FCM 另带 `capabilities = ["dataMessages"]`。这些信息变了（每次回前台检查，`setLocale`
之后立刻检查）、换了宿主或登出后重新登记。

**后台展示器。** Android 上应用退到后台后链路仍在。接上后台展示器后，引擎上报 `STANDBY`、照常确认，自己决定提示，
由本模块发成系统通知；进程被冻结或回收时由推送补上。

```kotlin
// 通知权限授予之后（常驻连接模式下也是）
FlareBackgroundPresenter.attach()
FlareBackgroundPresenter.attached.collect { attached -> /* 引擎已经知道 */ }
FlareBackgroundPresenter.detach()
```

- 「接上」要三样都有：应用要（`attach`）、有宿主（登录或恢复了会话）、能展示通知。齐了模块调宿主的
  `setBackgroundPresenter(true)`，少了任何一样调 `false`。撤销通知权限会断开（每次回前台重读，没有权限时来了提示也会
  重读），重新授权后只要应用还要就自动接回。每个新宿主都重报一次；`signOut` 保留应用的意愿。
- 宿主是当前宿主期间，模块收集它的 `notificationPresentations()`（引擎的 `notification.present`）。展示面为 `system` 的
  经推送用的同一个展示器发成通知：渠道按展示意图，tag 取 `collapseId`，`setNumber(count)`；没有声音的是静默更新
  （`setOnlyAlertOnce`、不响）。展示面为 `inApp` 的归应用内横幅。
- 这类通知点开时不经 `resolveNotificationTap`（通知里没有账号），而是带一个模块的凭据，去向直接取自通知里的会话。
  凭据在 `signOut` 和引擎全部清除（会话结束）时换掉，之后旧通知点开只打开应用。

**推送绑定。** `FlarePush.setPushBindingsEnabled(false)`（常驻连接模式）停止登记令牌，并对每个通道（`fcm`、`getui` 和
拿到过令牌的）调一次宿主的 `clearPushToken`，换了宿主再清一次；`true` 重新登记全部令牌。不持久化，应用每次启动按自己的
设置调。

**宿主新增。** `notificationPresentations()`（默认空流）、`setBackgroundPresenter(attached)` 与 `clearPushToken(provider)`
（默认抛 `UnsupportedOperationException`，模块据此认为这个宿主不支持，不再重试）。`CorePushHost` 分别接到
`client.events.onNotificationPresent`、`client.notification.setBackgroundPresenter` 与 `client.clearPushToken`；社交宿主经社交
SDK 透传 `notification.set_background_presenter`、`sdk.clear_push_token` 与事件 3503。

**厂商通知的点击。** 系统代厂商通道展示的通知，点击打开 `com.flare.im.push.FlarePushOpenActivity`
（也可以用 `flarepush://open`），载荷是 `flare_push` 附加数据里的 JSON 字符串；它转给启动页。
载荷各键逐个铺成字符串附加数据的意图也认。

## 渠道备案（运营方）

本模块自己发的通知（FCM 数据消息、个推透传、后台展示器）都是本地通知。vivo 把未备案渠道上的本地通知按运营消息处理：
静默，只在用户下拉通知栏时展示，没有悬浮、锁屏、响铃和振动。上线前运营方在 vivo 推送运营平台（「本地通知分类管理」→
「新增渠道」）按下表备案四个渠道：

| 通知渠道 id | 通知渠道名称 | 一级分类 / 二级分类 |
|---|---|---|
| `flare.messages` | 聊天消息 | 系统消息 / 即时消息 |
| `flare.mentions` | 聊天中@我的消息 | 系统消息 / 即时消息 |
| `flare.urgent` | 紧急聊天消息 | 系统消息 / 即时消息 |
| `flare.quiet` | 聊天消息静默更新 | 系统消息 / 即时消息 |

- 渠道 id 与名称要和应用创建的一致。同一个 id 只按中文名称备案一次，英文名称不用另备。
- 备案要先有 vivo 推送应用。审核通常 7 个工作日，通过后一般 24 小时内生效。渠道的展示方式在设备上首次创建时就定了，
  备案前已经建过渠道的设备要重装应用才按新状态处理。
- 仍在发行旧名称（如 `flare.messages` 叫「消息」）的版本，备案时「通知渠道名称」填旧名称，「备用渠道名称」填新名称，
  并填新版本上线的启用时间。
- vivo 建议一个二级分类申请一个渠道，没说四个渠道能否都挂在「即时消息」下；使用场景里要写明四者只是声音与重要级不同。
- OPPO 旧私信通道（`getui.android_vendor.oppo_channel_id`）登记其中一个渠道，通常是 `flare.messages`，名称相同。
  OPPO 新消息分类不需要客户端渠道。

各厂商要申请什么、服务端凭据字段与怎样确认生效，见 Flare 知识库的
[厂商即时通讯类目申请手册](https://github.com/flare-im/flare-knowledge-base/blob/main/docs/operations/push-vendor-im-category.md)。

## 后台限制

只做引导，不做任何自动化。`FlareBackgroundRestrictions` 给出 `isIgnoringBatteryOptimizations`、
`isBackgroundRestricted`、两者合成的电池设置三档（`delivery(context)`：`FlarePushBackgroundDelivery.UNRESTRICTED`、
`OPTIMIZED`、`RESTRICTED`）与厂商（`FlarePushVendor`，带 `hasAutoStartSettings`），能打开电池优化列表
（`openBatteryOptimizationSettings`），以及华为、荣耀、小米、OPPO、vivo 的自启动管理页（`openAutoStartSettings`）。
这些页面是系统应用的内部页面，会随系统更新改名：每次尝试都有兜底，打不开就退到应用详情页。

`FlarePush.backgroundDelivery: StateFlow<FlarePushBackgroundDelivery?>` 跟踪这个档位，做法与 `FlarePush.permission`
跟踪权限相同：安装时、`refresh()` 时与每次回前台重读，变了才更新，安装之前为 `null`。设置页那一行收集它，用户从电池
设置回来就会更新。

## 测试

JVM 单测，用假的宿主与展示器，在登记了这个模块的宿主工程里跑：

```bash
./gradlew :flare-core-android-push:testDebugUnitTest
```
