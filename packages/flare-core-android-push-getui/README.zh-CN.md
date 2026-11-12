# flare-core-android-push-getui

[English](README.md) · 中文

[`flare-core-android-push`](../flare-core-android-push/README.zh-CN.md) 的个推接入。面向没有 Google
服务的 Android 设备（国内渠道的构建），是可选依赖。

- 个推的 clientid 作为推送令牌登记，provider 为 `getui`。
- 个推连接在线时，服务端发透传消息：载荷各键组成的 JSON 对象。它和 FCM 数据消息走同一条路
  （先问引擎，问不到按载荷原样展示）。
- 应用被杀后只有厂商通道（华为、荣耀、小米、OPPO、vivo）能到达设备。这些通知由系统代为展示，
  点击打开 `com.flare.im.push.FlarePushOpenActivity`，载荷在 `flare_push` 附加数据里，
  `FlarePush.handleLaunchIntent` 照常路由。

上线前要向各厂商申请即时通讯类目。没有类目时厂商通知按运营消息处理：每日限额且静音。
这一点代码解决不了。

## 应用要加的

### 1. 仓库与模块

个推的制品不在 Maven Central，在 `settings.gradle.kts` 里加它的仓库：

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://mvn.getui.com/nexus/content/repositories/releases/")
    }
}

include(":flare-core-android-push-getui")
project(":flare-core-android-push-getui").projectDir = file("<workspace>/flare-core-sdk/packages/flare-core-android-push-getui")
```

再由国内渠道的变体依赖它：

```kotlin
"chinaImplementation"(project(":flare-core-android-push-getui"))
```

个推 SDK 的坐标与版本只写在本模块的 `build.gradle.kts` 里。

### 2. 个推应用标识

个推 SDK 的清单要读一个占位符：

```kotlin
android {
    defaultConfig {
        manifestPlaceholders["GETUI_APPID"] = "<个推 AppID>"
    }
}
```

### 3. 厂商通道

个推经厂商插件到达被杀的应用。插件由应用自己加，各有清单占位符（各厂商的应用标识与密钥），
华为与荣耀还要把厂商的配置文件放进应用模块。插件坐标与占位符名称以个推现行 Android 接入文档为准，
对应 `build.gradle.kts` 里的 SDK 版本；它们随各厂商 SDK 变化，本模块不固定。

### 4. 启动

在 `FlarePush.install` 之后，并且只在用户同意隐私政策之后（国内应用商店不允许更早初始化推送 SDK）：

```kotlin
FlarePush.install(this, hostProvider = { signedInClient()?.let(::CorePushHost) })
if (privacyAccepted()) FlareGetuiPush.install(this)
```

用户同意后马上再调一次 `FlareGetuiPush.install`；重复调用无害。

Flutter 应用照样做第 1 到第 3 步（加在 `android/` 工程里，应用模块依赖本模块），启动改在 Dart 里：
`FlarePush.instance.start()` 之后、用户同意隐私政策之后调 `FlarePush.instance.installGetui()`。插件不依赖本模块，
按类名反射调 `FlareGetuiPush.install`；没加本模块时返回 false。本模块随带混淆规则，应用开了混淆也找得到入口。

## 服务端的厂商点击约定

厂商通知的点击动作是一个打开本模块固定组件的意图，服务端只需要知道应用包名：

```
intent://open#Intent;scheme=flarepush;launchFlags=0x14000000;component=<applicationId>/com.flare.im.push.FlarePushOpenActivity;S.flare_push=<百分号编码的载荷 JSON>;end
```

JSON 里是和其它推送载荷相同的蛇形键（`conversation_id`、`collapse_id`、`seq` 等）。载荷各键逐个作为
字符串附加数据（`S.conversation_id=...`）发来也认。

## 测试

```bash
./gradlew :flare-core-android-push-getui:testDebugUnitTest
```
