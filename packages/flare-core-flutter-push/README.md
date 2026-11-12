# flare_core_flutter_push

English · [中文](README.zh-CN.md)

Flutter bridge over the Flare platform push modules: `FlarePlatformPush` on iOS
and `flare-core-android-push` on Android. The native modules own the
notification permission (three states), the system tokens, remote messages,
notification channels and presentation, taps, the badge, the sign-out cleanup
and the bounds on host calls; the engine decides every alert. This plugin
forwards the modules' host calls to a `FlarePushHost` attached in Dart and hands
taps and the permission back to Dart. On Android it also bridges the optional
Getui module and the background-restriction guidance.

There is no Firebase Dart plugin and no Dart background isolate. When a push
starts the process before Flutter runs, or before a host is attached, the native
module presents the payload as it is, so an alert is never lost.

While the live link is up the engine decides and renders alerts itself
(`notification.present`). `FlareNotificationPresenter` puts those with surface
`system` on screen: on Android through the push module's background presenter,
on macOS, Linux and Windows through the desktop notification centre.

| App built on | Host |
|---|---|
| Core client (`flare_core_flutter_sdk`) | `CorePushHost(client)` |
| Social SDK (`flare_social_flutter_sdk`) | `sdk.makePushHost()` (`FlareSocialPushHost`) |

The host interface and its values (`FlarePushHost`, `PlatformPushToken`,
`PlatformPushOutcome`, `PlatformTapRoute`, …) live in `flare_core_flutter_sdk`,
which is pure Dart, so the core adapter can implement them; this package
re-exports them.

## Dart API

```dart
final push = FlarePush.instance;

await push.start();                       // at launch; never prompts
await push.attach(CorePushHost(client));  // after sign-in or session restore
await push.setLocale('en-US');            // the in-app language, if the app has its own
push.routes.listen((route) => openConversation(route.conversationId, route.messageId));

push.permissionChanges.listen(showPermission);  // current value first, then changes
final status = await push.permissionStatus();   // notDetermined, granted, denied

// At a moment the user understands:
if (await push.canRequestPermission()) {
  await push.requestPermission();               // the status after the dialog
} else if (status != FlarePushPermissionStatus.granted) {
  await push.openNotificationSettings();        // the system will not ask again
}

push.backgroundChanges.listen(showBackground);  // Android: current value first, then changes

await push.signOut();                     // on sign-out
```

| Member | Does |
|---|---|
| `start({FlarePushOptions options})` | Android: installs the native module (channels, FCM token, permission and background level on every return to the foreground). iOS: confirms the start made in `AppDelegate`. Reads the permission once, and on Android the background status. Idempotent. |
| `isStarted` | `start` has completed. |
| `attach(FlarePushHost host)` | Host calls go to `host`; tokens and the permission are reported again and a queued tap is resolved. A new host re-registers the tokens. While attached, the host's `notificationCorrections()` reach the native module: a read conversation's notification is removed, the end of the session removes them all, and on iOS every `notification.badge` writes the badge. |
| `detach()` | The client is released but the account stays: pushes are presented from the payload again; taps wait for the next host; corrections stop. |
| `signOut()` | Detaches the host, removes this SDK's delivered and pending notifications (iOS also resets the badge), drops a queued tap and forgets the sent tokens, so the next account registers fresh. |
| `setLocale(String? languageTag)` | The in-app language (BCP 47) replaces the system locale in the token registration; a change registers again at once. `null` returns to the system locale. |
| `permissionStatus()` | `FlarePushPermissionStatus.notDetermined`, `granted` (iOS provisional and ephemeral included) or `denied`. |
| `permissionChanges` | The current status when known, then every change; the native module re-reads on start, after a request and on every return to the foreground. |
| `canRequestPermission()` | Whether a request would show the system dialog. Android: never asked, or refused once and the system suggests a rationale, with an activity to show it on. iOS: not determined yet. When it is `false` and notifications are not granted, only the settings page helps. |
| `requestPermission()` | Shows the system dialog when the system would show one and returns the resulting `FlarePushPermissionStatus`; the result, denial included, reaches the engine and `permissionChanges`. When the system would not show a dialog (permanently denied on Android, already decided on iOS) it requests nothing and returns the current status, so the app chooses between asking and the settings page. |
| `openNotificationSettings()` | The app's notification settings. |
| `clearNotifications(collapseIds)` / `clearAllNotifications()` / `setBadge(count)` | Apply a correction by hand (iOS removes by identifier and by the payload's collapse id, Android by tag; the badge is iOS only). The attached host's corrections are applied without them. |
| `routes` | Taps the engine resolved for the signed-in account. The native module keeps the latest one until someone listens. |
| `installGetui()` | Android: starts the Getui module when the app ships it (see below); `false` otherwise and on iOS. |
| `backgroundStatus()` | Android: `FlarePushBackgroundStatus` (`delivery` as `FlarePushBackgroundDelivery.unrestricted` / `optimized` / `restricted`, `ignoringBatteryOptimizations`, `backgroundRestricted`, `vendor`, `hasAutoStartSettings`); `null` on iOS. |
| `backgroundChanges` | Android: the current `FlarePushBackgroundStatus` when known, then a new one each time the battery level changes; the native module re-reads on start, when a host attaches, after a permission request and on every return to the foreground. Emits nothing on iOS. |
| `openBatterySettings()` / `openAutoStartSettings()` | Android: the battery optimisation list and the vendor's auto-start page, each falling back to the app details page; `false` on iOS. |
| `isSupported` | Android and iOS; on other platforms every member does nothing. |

`FlarePushOptions` (Android only): `fcm` (register the FCM token, default true),
`smallIcon` (a drawable resource name, monochrome on transparent), `color` (ARGB).

Corrections are forwarded from Dart: the native side's own host returns no
corrections, so a host's stream is listened to exactly once. Apps do not remove
read notifications or write the badge themselves.

Channels: method channel `im.flare.push` both ways (Dart → native: the members
above, `clearNotifications` with `{collapseIds}` and `setBadge` with `{count}`,
and on Android `presentNotification` with a `NotificationPresentation` of surface
`system`; native → Dart: the host calls in the engine's JSON shapes (`totalUnread`
and `setBackgroundPresenter` with `{attached}` only from Android),
`permissionChanged` with the status and, on Android, `backgroundChanged` with the
background status object), event channel `im.flare.push/routes`
(`{conversationId, messageId?, seq?}`).

## System notifications while the link is up

```dart
final presenter = FlareNotificationPresenter.instance;

// After sign-in or session restore, with the same host as FlarePush.attach.
await presenter.attach(host,
    options: const FlareNotificationPresenterOptions(
      windowsAppUserModelId: 'com.example.app', // Windows, unpackaged apps only
    ));
await presenter.requestPermission();      // macOS asks once; elsewhere it answers the status
presenter.routes.listen((route) => openConversation(route.conversationId, route.messageId));

await presenter.signOut();                // on sign-out
```

| Member | Does |
|---|---|
| `kind` | `androidBackground`, `desktop` (macOS, Linux, Windows) or `none` (iOS, web, others). |
| `attach(host, {options})` | Android: asks the native background presenter for itself (see below). Desktop: forwards the host's `notificationPresentations()` with surface `system` and its `notificationCorrections()` to the native presenter. Answers which native backend is in use in `backend`. |
| `detach()` | Stops; notifications already shown stay. Android tells the engine `setBackgroundPresenter(false)` straight away, then the native side. |
| `signOut()` | `detach()`, then on the desktop removes this plugin's notifications and clears the badge (Android: `FlarePush.signOut()` does it). |
| `permissionStatus()` / `requestPermission()` | macOS: the notification centre authorisation, the dialog only while undecided. Android: `FlarePush`'s. Linux and Windows have no authorisation step: `granted`, or `denied` on Windows when the user turned the app's notifications off. |
| `routes` | Desktop clicks `{conversationId, messageId?, seq?}`; the native side keeps the latest until someone listens. A digest notification has no conversation: its click only brings the window forward. Android taps arrive on `FlarePush.routes`. |
| `backend` | Diagnostics: `android`, `userNotificationCenter`, `freedesktop`, `toast`, `tray` or `none`. |

The host gains two members for this: `notificationPresentations()` (every
`notification.present`) and `setBackgroundPresenter({attached})`
(`notification.set_background_presenter`). `CorePushHost` and
`FlareSocialPushHost` implement both.

Channels: method channel `im.flare.push/presenter` (Dart → native: `attach` with
`{windowsAppUserModelId?}` answering `{attached, backend}`, `detach`; desktop
also `present` with a `NotificationPresentation`, `clear` with `{collapseIds}`,
`clearAll`, `setBadge` with `{count}`, `permissionStatus`, `requestPermission`),
event channel `im.flare.push/presenter/taps` (`{conversationId, messageId?, seq?}`).

**Android.** `attach` calls `FlareBackgroundPresenter.attach()`; the module
decides. When the app wants it, a host is attached (`FlarePush.attach`) and
notifications are allowed, the module calls the host's `setBackgroundPresenter(true)`
over `im.flare.push`, Dart passes it to the engine, and the engine reports
`STANDBY` in the background, keeps acknowledging and emits system presentations.
`FlarePush` forwards those (`presentNotification`) and the corrections into the
Kotlin channel host's flows, and the module posts them with the push channels,
the collapse id as tag, quiet replacement for presentations without sound and a
tap credential of its own. Revoking the permission detaches (the module reports
`false`), granting it again re-attaches. When the Flutter view goes away
(`AppLifecycleState.detached`) the presenter detaches, and when the plugin leaves
its engine it withdraws the request.

**Desktop.** One notification per conversation: the collapse id identifies it
and a newer one replaces the older; presentations without sound, and the `quiet`
channel, are delivered quietly (no banner, no sound). A click brings the window
forward and routes the conversation back to Dart. The desktop alerts by itself:
the presenter never calls `setBackgroundPresenter`.

- **macOS** (`UNUserNotificationCenter`, macOS 10.15+): request identifier =
  collapse id, thread identifier = thread id, `interruptionLevel` passive for
  quiet ones (macOS 12+), removal by identifier, the dock tile carries the badge.
  The plugin installs the notification centre delegate when it registers (before
  launch finishes, so the click that launched the app arrives); a delegate set
  earlier keeps receiving the notifications that are not this plugin's. Builds
  with SwiftPM or CocoaPods; the runner adds nothing.
- **Linux** (`org.freedesktop.Notifications` over GDBus on the session bus): the
  server's id is remembered per collapse id and sent as `replaces_id`; a
  `Notify` still in flight queues the next one; `CloseNotification` removes;
  action `default` is the click; urgency low for quiet ones, critical for the
  `urgent` channel; the body is markup-escaped when the server supports
  `body-markup`; the `desktop-entry` hint is the GApplication id. No badge.
- **Windows** (toast notifications through the WinRT ABI, no C++/WinRT): tag =
  collapse id, group `flare`, so a newer toast replaces the older in the
  notification centre; quiet ones use `SuppressPopup` and silent audio; removal
  through the toast history. Toasts need an identity: a packaged (MSIX) app has
  one; an unpackaged app passes the AppUserModelID it registered (a Start menu
  shortcut carrying it, or `HKCU\Software\Classes\AppUserModelId\<id>`) as
  `windowsAppUserModelId`, or sets one for the process. Without a registered
  identity the presenter falls back to a tray icon balloon (`Shell_NotifyIconW`).
  No taskbar badge.

## Android

The plugin depends on the Gradle project `:flare-core-android-push`.
`flare-core-sdk` has no root project, so the host's `android/settings.gradle.kts`
includes it:

```kotlin
include(":flare-core-android-push")
project(":flare-core-android-push").projectDir =
    file("<workspace>/flare-core-sdk/packages/flare-core-android-push")
```

FCM needs the Firebase client configuration at `android/app/google-services.json`
and the Google services plugin, applied only when the file exists:

```kotlin
// settings.gradle.kts, plugins { }
id("com.google.gms.google-services") version "4.4.2" apply false

// app/build.gradle.kts
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
```

Without the file Firebase does not initialise, no FCM token is registered and
everything else works. The module declares `POST_NOTIFICATIONS`, its FCM service
and the vendor tap activity; the app declares none of them and must not declare a
second `com.google.firebase.MESSAGING_EVENT` service.

Getui (China builds) is opt-in: include `:flare-core-android-push-getui` next to
the module, add `implementation(project(":flare-core-android-push-getui"))`, the
Getui repository and `GETUI_APPID` to the app module (see that module's README),
then call `installGetui()` after `start()` and after the privacy consent. The
plugin itself does not depend on the Getui module; it starts it by class name.

How it behaves:

- `start` calls `FlarePush.install(application, hostProvider, options)`. The host
  provider returns the host attached through the current engine, or null. A
  process started by FCM in the background has no Flutter engine: the plugin is
  not attached and the module presents from the payload.
- The launcher activity's intents go to `FlarePush.handleLaunchIntent` when the
  plugin attaches to the activity and on every new intent; routes come back on
  the event channel.
- `requestPermission` asks for `POST_NOTIFICATIONS` through
  `FlarePushPermission.request(activity, requestCode)`, so the module records
  that it asked, and only when `FlarePushPermission.canRequest(activity)` holds;
  otherwise it answers the current status. `canRequestPermission` is
  `FlarePushPermission.canRequest` for the current activity. The three states
  come from `FlarePushPermission.status` and changes from `FlarePush.permission`.
- `backgroundStatus` reads `FlareBackgroundRestrictions`; `backgroundChanged`
  follows `FlarePush.backgroundDelivery`.
- `signOut` calls `FlarePush.signOut()`; `setLocale` calls `FlarePush.setLocale`.
- Host calls are bounded by the module: about 3 s for a remote message (then the
  payload is shown), 15 s for tokens, permission and taps.

## iOS

The plugin builds with Swift Package Manager or CocoaPods and needs iOS 15, the
floor of `FlarePlatformPush`.

`FlarePlatformPush` and `FlarePlatformLifecycle` are not copied: their sources are
symbolic links into `flare-core-apple-sdk` (`ios/flare_core_flutter_push/Sources/`),
compiled as targets of the same names, so `import FlarePlatformLifecycle` inside
the push module holds. A package dependency on the Apple SDK is not possible:
Flutter places plugin packages behind symbolic links where a relative package path
does not resolve, and a podspec cannot depend on a SwiftPM product. A new source
file in `FlarePlatformPush` needs a matching link here.

- **SwiftPM** (Flutter's Swift Package Manager integration): nothing to add.
- **CocoaPods**: the two modules are pods next to the plugin's podspec. List them
  in the `Podfile`, inside the `Runner` target:

  ```ruby
  pod 'FlarePlatformLifecycle', :path => '.symlinks/plugins/flare_core_flutter_push/ios'
  pod 'FlarePlatformPush', :path => '.symlinks/plugins/flare_core_flutter_push/ios'
  ```

What the app adds:

- The **Push Notifications** capability (`aps-environment` in
  `Runner.entitlements`; `development` for development signing, the distribution
  profile makes it production) and the `remote-notification` background mode in
  `Info.plist`.
- In `AppDelegate`, before `super`:

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

  `prepare()` starts `PlatformPush` (notification center delegate, APNs
  registration, foreground tracking) and hooks the three push callbacks of
  `FlutterAppDelegate`. With the UIScene life cycle the plugin registers when the
  scene connects, after launch: a cold-start tap needs the delegate earlier, and a
  push that launches the app in the background has no scene and no engine at all.
  Apps without scenes may skip it; plugin registration does the same.

The module installs itself as the notification center delegate; the app sets no
other one. Everything else is the module's: `permissionStatus` and
`permissionChanged` come from `PlatformPush.permissionStatus()` and
`permissionChanges()`. iOS shows the dialog once: `canRequestPermission` is true
only while the status is `notDetermined`, and only then does `requestPermission`
call `PlatformPush.requestAuthorization()`; it answers the status read
afterwards. `signOut` is `PlatformPush.signOut()`, `setLocale` is
`PlatformPush.setLocale(_:)`, and host calls are bounded inside the module (3 s
for a remote message, 15 s otherwise); the plugin's channel host gives up when
the module cancels a call. JSON shapes go through `PlatformPushWire`.

## Known limits

- **Flutter iOS runners have no notification service extension.** The native
  iOS apps add one (`FlareNotificationService` in `flare-core-apple-sdk`); a
  Flutter runner gets none here, so pushes show the server-rendered text and send
  no arrival receipt from the extension path.
- **Android background presenter lives with the Flutter engine.** It presents
  only while the Dart isolate runs. The presenter detaches when the view goes
  away (`AppLifecycleState.detached`); if that call does not reach the engine
  before the Flutter engine is torn down while the process stays alive, the
  engine keeps acknowledging without anyone presenting until the process ends.
  Apps that need it independent of the activity keep a process-level engine.
- **Windows without a registered AppUserModelID** gets tray balloons: one at a
  time (a new one replaces the shown one regardless of conversation), removal
  only takes down the current balloon, a click only routes the current one, and
  the tray icon stays while attached. Toast clicks only arrive while the app
  runs (no COM activator); a toast left from an earlier run brings nothing back.
- **Linux and Windows have no badge**; macOS uses the dock tile.
- **Desktop notifications left from an earlier run** (macOS notification centre,
  Windows notification centre) are not checked against the account on click:
  sign-out removes them, quitting while signed in leaves them.

## Tests

```bash
flutter test
```

The tests drive the Dart side against mock channels. The native sides are
covered by the native modules' own tests; device delivery needs signing,
credentials and a device.
