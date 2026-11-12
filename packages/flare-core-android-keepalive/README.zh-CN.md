# flare-core-android-keepalive

[English](README.md) · 中文

Flare IM 在 Android 上的常驻连接模式：一个前台服务加一条常驻通知，让应用退到后台后进程一直在，链路也就一直在。
可选依赖，默认关。

只面向没有任何推送通道（没有 FCM、个推和厂商通道）的部署。开着时应用不登记推送绑定，服务端看到的是一台一直处于
`Standby` 的设备；提示来自链路，由 [`flare-core-android-push`](../flare-core-android-push/README.zh-CN.md) 的后台展示器
发出。上架应用商店的应用不应打开它：商店政策限制 `specialUse` 前台服务和电池优化豁免。

模块不依赖任何引擎包，应用经 `FlareKeepAliveHost` 把它接到自己的会话上。

## 应用要加的

### 1. Gradle

```kotlin
// settings.gradle.kts
include(":flare-core-android-keepalive")
project(":flare-core-android-keepalive").projectDir = file("<workspace>/flare-core-sdk/packages/flare-core-android-keepalive")

// app/build.gradle.kts
implementation(project(":flare-core-android-keepalive"))
```

服务要的东西都在模块清单里：`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE`、`RECEIVE_BOOT_COMPLETED`、
`POST_NOTIFICATIONS`，服务本身（`foregroundServiceType="specialUse"`，子类型属性 `im-persistent-connection`）和重启接收器。
不声明 `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`。

### 2. `Application.onCreate`

在主进程里装上。开机与应用更新后的自启都先跑 `Application.onCreate`，服务启动时宿主已经在。

```kotlin
FlareKeepAlive.install(
    this,
    options = FlareKeepAliveOptions(smallIcon = R.drawable.ic_notification, launchActivity = MainActivity::class.java),
    host = object : FlareKeepAliveHost {
        override fun onKeepAliveStarted() {
            FlarePush.setPushBindingsEnabled(false) // 每个通道调一次 clearPushToken，不再登记
            FlareBackgroundPresenter.attach()
            resumeSessionInTheBackground()          // 进程级的客户端维持链路
        }

        override fun onKeepAliveStopped() {
            if (!FlareKeepAlive.isEnabled(this@App)) FlarePush.setPushBindingsEnabled(true)
        }
    },
)
```

客户端要由进程持有（`Application` 那一级），不能跟着某个页面：服务只保住进程，链路是客户端的。

### 3. 开关

只在没有配置推送通道的构建里显示。Compose Kit 的 `NotificationDeliverySettings` 里有这一行（`residentMode`、
`onResidentModeChange`）和电池优化的引导行。

```kotlin
if (on) FlareKeepAlive.start(context) else FlareKeepAlive.stop(context)
```

## 接口

| 成员 | 作用 |
|---|---|
| `FlareKeepAlive.install(application, options, host)` | 记下选项与宿主；开关开着就启动服务。再调一次只换选项与宿主。 |
| `FlareKeepAlive.start(context)` | 打开开关（模块记下）并启动服务。返回系统有没有接受启动；在后台时可能不接受，模块在下次回到前台时再试。 |
| `FlareKeepAlive.stop(context)` | 关掉开关并停掉服务，常驻通知随之消失。 |
| `FlareKeepAlive.isEnabled(context)` | 记下的开关，默认关。 |
| `FlareKeepAlive.running: StateFlow<Boolean>` | 服务是否在前台运行。 |
| `FlareKeepAlive.setHost(host)` | 换宿主；服务在运行时新宿主马上收到 `onKeepAliveStarted`。 |
| `FlareKeepAliveHost` | 服务开始时（刚打开、开机后、更新后、被系统重建后）`onKeepAliveStarted()`，停了 `onKeepAliveStopped()`。在主线程上。 |
| `FlareKeepAliveBattery.isIgnoringBatteryOptimizations(context)` | 用户是否已经把应用放出电池优化。 |
| `FlareKeepAliveBattery.openSettings(context)` | 打开电池优化的应用列表（打不开时退到应用详情页）。模块从不自己申请豁免。 |

`FlareKeepAliveOptions`：`smallIcon`（单色图；0 用模块自带的）、`color`、`title`（默认应用名）、`text`（默认用模块的文案，
中英随系统）、`launchActivity`（默认启动页）、`onError`（系统不让启动或进入前台时报出，不含账号与消息内容）。

## 行为

- **服务。** `FlareKeepAliveService`，不导出，在应用的主进程里；Android 14 起类型为 `specialUse`、子类型
  `im-persistent-connection`（更早的系统不带类型）。`START_STICKY`：被系统杀掉后，开关开着就会回来。它自己不做任何网络的事。
- **通知。** 渠道 `flare.keepalive`，名称「后台保持连接」/ "Stay connected in the background"，与打开这个模式的开关同名；
  低重要级，不响、不振、不进角标，常驻，类别 `service`。点开打开应用。
- **vivo。** 这个渠道不在 vivo 备案：vivo 的二级分类里没有对应连接状态提示的；未备案渠道按运营消息静默、只在下拉通知栏
  展示，正是这个渠道本来的样子。这个模式下的提示来自 `flare-core-android-push` 的四个渠道，在 vivo 上要那四个渠道备案后
  才响铃（见该模块的 README），而备案要先有 vivo 推送应用。
- **重启。** `FlareKeepAliveRestartReceiver` 接 `BOOT_COMPLETED` 与 `MY_PACKAGE_REPLACED`，开关开着才启动服务；这两个广播
  允许在后台启动前台服务。该跑却没跑起来时，`install` 与每次回到前台都会再启动一次。
- **电池优化。** 优化开着时系统仍可能停掉服务，或在低电耗模式下断网。应用显示引导行，用户点了才打开设置页。

## 测试

```bash
./gradlew :flare-core-android-keepalive:testDebugUnitTest
```
