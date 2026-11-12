# flare-core-android-push-getui

English · [中文](README.zh-CN.md)

Getui for [`flare-core-android-push`](../flare-core-android-push/README.md). Add it to builds for
Android devices without Google services (China builds); it is an optional dependency.

- The Getui client id is registered as a push token with provider `getui`.
- While the Getui connection is up, the server sends transmission messages: a JSON object with the
  payload keys. They take the same path as FCM data messages (engine first, payload as-is otherwise).
- After the app is killed only the vendor channels (Huawei, Honor, Xiaomi, OPPO, vivo) reach the
  device. The OS renders those notifications itself; a tap opens
  `com.flare.im.push.FlarePushOpenActivity` with the payload in the `flare_push` extra, and
  `FlarePush.handleLaunchIntent` routes it like any other tap.

Before release, apply for the instant messaging category with every vendor. Without it vendor
notifications count as marketing: daily limits and no sound. No code works around this.

## What the app adds

### 1. Repository and module

Getui's artifacts are not on Maven Central. Add its repository in `settings.gradle.kts`:

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

and depend on it from the flavor that ships in China:

```kotlin
"chinaImplementation"(project(":flare-core-android-push-getui"))
```

The Getui SDK coordinates and versions are pinned in this module's `build.gradle.kts` only.

### 2. Getui app id

The Getui SDK's manifest reads a placeholder:

```kotlin
android {
    defaultConfig {
        manifestPlaceholders["GETUI_APPID"] = "<your Getui app id>"
    }
}
```

### 3. Vendor channels

Getui reaches killed apps through vendor plugins that the app adds itself, each with its own
manifest placeholders (app ids and keys per vendor) and, for Huawei and Honor, the vendor's
configuration file in the app module. Take the plugin coordinates and placeholder names from
Getui's current Android integration guide for the SDK version in `build.gradle.kts`; this module
does not pin them because they change with the vendors' own SDKs.

### 4. Start it

After `FlarePush.install`, and only after the user has accepted the privacy policy (Chinese app
stores reject apps that start a push SDK earlier):

```kotlin
FlarePush.install(this, hostProvider = { signedInClient()?.let(::CorePushHost) })
if (privacyAccepted()) FlareGetuiPush.install(this)
```

Call `FlareGetuiPush.install` again right after the user accepts; repeating it is harmless.

A Flutter app does steps 1 to 3 the same way (in its `android/` project, with the app module depending on
this module) and starts it from Dart: `FlarePush.instance.installGetui()` after
`FlarePush.instance.start()` and after the privacy consent. The plugin does not depend on this module; it
calls `FlareGetuiPush.install` by class name and answers `false` when the module is absent. This module
ships a consumer ProGuard rule so the entry point survives minification.

## Server contract for the vendor click

The vendor notification's click action is an intent that opens the module's fixed component, so the
server needs only the application id:

```
intent://open#Intent;scheme=flarepush;launchFlags=0x14000000;component=<applicationId>/com.flare.im.push.FlarePushOpenActivity;S.flare_push=<percent-encoded payload JSON>;end
```

The JSON carries the same snake_case keys as every other push payload (`conversation_id`,
`collapse_id`, `seq`, ...). Payload keys sent as individual string extras (`S.conversation_id=...`)
are accepted as well.

## Tests

```bash
./gradlew :flare-core-android-push-getui:testDebugUnitTest
```
