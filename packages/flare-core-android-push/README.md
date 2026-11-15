# flare-core-android-push

English · [中文](README.zh-CN.md)

Android platform push for Flare IM: the FCM messaging service, the notification presenter
with its four channels, notification taps, the notification permission, and guidance for
background restrictions.

The module depends on no engine package. It reaches the engine through a host adapter,
`FlarePushHost`, so the core SDK and the social SDK reuse the same platform code:

| App built on | Host adapter |
|---|---|
| Core SDK (`flare-core-android-sdk`) | `com.flare.im.push.CorePushHost(client)` |
| Social SDK (the social Android app's binding) | `com.flare.social.app.ffi.FlareSocialPushHost(imDispatch)`, next to `ffi/FlareSocialSdk.kt` in the social Android app |

China builds add [`flare-core-android-push-getui`](../flare-core-android-push-getui/README.md)
for Getui and the vendor channels. Deployments without any push channel can add
[`flare-core-android-keepalive`](../flare-core-android-keepalive/README.md) (resident connection mode, off by
default).

## What the app adds

### 1. Gradle

Include the module next to the others in `settings.gradle.kts`:

```kotlin
include(":flare-core-android-push")
project(":flare-core-android-push").projectDir = file("<workspace>/flare-core-sdk/packages/flare-core-android-push")
```

`flare-core-android-sdk` already exposes it (`api`), so a core app needs only the `include`. A social
app adds `implementation(project(":flare-core-android-push"))` and the social SDK sources.

### 2. Firebase (optional)

Firebase Messaging is always compiled in; whether FCM works is decided at run time.

- With FCM: put the Firebase client configuration at `app/google-services.json` and apply the
  Google services plugin in the app module (`id("com.google.gms.google-services")`). The server's
  FCM credentials must belong to the same Firebase project.
- Without it (no GMS, private deployments, China builds): ship no `google-services.json`. Firebase
  does not initialise, `FlarePush.isFcmAvailable(context)` is `false`, and everything else works.
  `FlarePushOptions(fcm = false)` also stops FCM token registration where Firebase is configured.

The module declares its own `FirebaseMessagingService` (`FlareFirebaseMessagingService`, not
exported). An app must not declare a second service for `com.google.firebase.MESSAGING_EVENT`.

### 3. Notification permission

`POST_NOTIFICATIONS` is declared in the module manifest and merges into the app. Ask for it at a
moment that makes sense to the user, not at launch, and always through `FlarePushPermission.request`:
the module records that it asked, which is how it tells "not asked yet" from "denied" (Android itself
does not), so the app keeps no flag of its own.

```kotlin
private val notifications = registerForActivityResult(ActivityResultContracts.RequestPermission()) {
    FlarePush.refresh() // reports the result, denial included, and updates FlarePush.permission
}

fun askForNotifications() {
    if (FlarePushPermission.canRequest(this)) {
        FlarePushPermission.request(this, notifications)
    } else if (!FlarePushPermission.isGranted(this)) {
        FlarePushPermission.openSettings(this) // the system will not show the prompt again
    }
}

// Settings row and first-run prompt:
FlarePush.permission.collect { status -> showPermission(status) } // null until install
```

In Compose, `FlarePushPermission.canRequest(LocalContext.current)` finds the hosting activity itself.

| Member | What it does |
|---|---|
| `FlarePushPermission.status(context)` | `NOT_DETERMINED` (Android 13+, never asked through the module), `DENIED` (asked and refused, or turned off in settings), `GRANTED`. `wireValue` is `notDetermined` / `denied` / `granted`, the same as iOS and Dart. |
| `FlarePush.permission: StateFlow<FlarePushPermissionStatus?>` | Read on install, on `refresh()` and on every return to the foreground; changes only. |
| `FlarePushPermission.request(context, launcher)` / `request(activity, requestCode)` | Shows the system prompt when one is needed and records that it asked. The second form is for hosts without an `ActivityResultLauncher` (the Flutter plugin). |
| `FlarePushPermission.canRequest(activity)` / `canRequest(context)` | The prompt would still appear: never asked, or refused once and the system suggests a rationale. When it is `false` and notifications are off, only the settings page helps. The `Context` form unwraps `ContextWrapper` to the hosting activity and is `false` without one. |
| `FlarePushPermission.openSettings(context)` | The app's notification settings, falling back to the app details page. |

The module reports the current state on install and on every return to the foreground, so a change
made in system settings reaches the engine without app code.

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

`hostProvider` is called when the module needs the engine. It may suspend while the app finishes
initialising (a process cold-started by FCM runs `onCreate` first) and returns `null` while nobody is
signed in or the session is not restored. Without a host, a push is still shown from its payload.

After sign-in or session restore call `FlarePush.refresh()`: it reports the permission, re-reads the
background level, registers the tokens and resolves a queued tap.

Keep one host per session (create it when the session is ready and answer the same instance until sign-out): the
module tells hosts apart by instance, and a new instance registers the tokens again and restarts the corrections.

On sign-out call `FlarePush.signOut()` (and let `hostProvider` answer `null` from then on): it removes
every notification this module posted, drops a queued tap (also one being resolved and a route nobody
collected yet) and forgets the tokens and permission it reported, so the next account's host, even the
same instance, registers fresh.

An app with its own language switch calls `FlarePush.setLocale("en-US")` (`null` returns to the device
language). The tag replaces the system locale in the token registration and the tokens are sent again at
once. `FlarePush.isInstalled` tells whether `install` ran.

### 5. Launcher activity

Notification taps open the launcher activity (or `FlarePushOptions.launchActivity`) with the payload
in the `flare_push` extra. Hand every intent to the module and navigate on its routes:

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

The engine checks that the payload belongs to the signed-in account before it becomes a route; a tap
that arrives before sign-in waits for the next `refresh()`. `routes` keeps the latest route until it
is collected; collect it in one place.

## Behaviour

**Remote messages.** FCM to Android is data-only. The service hands the payload to
`handleRemoteMessage` (provider `fcm`, wake budget 8 s) and waits at most about 3 s
(`FlarePushOptions.hostTimeoutMs`, the same bound as iOS). The engine's answer decides what happens:
`present` posts a notification that may sound, `update` replaces it silently, `clear` removes it,
`badgeOnly` and `ignore` post nothing, and `surface = inApp` (app in the foreground) leaves the alert to
the in-app banner. When the engine cannot answer in time, has no session, or fails, the payload is shown
as is.

**Host calls.** Every other host call (token, permission, reconcile, tap) is bounded by
`FlarePushOptions.resolveTimeoutMs` (15 s) and retried on the next refresh. A timed-out call is cancelled
and reported to `onError` as `FlarePushHostTimeoutException` (method name and limit only).

**Notifications.** One notification per conversation: tag = `collapse_id`, a fixed id, group =
`thread_id`, `setNumber(count)`. Quiet updates use `setOnlyAlertOnce` without sound. The four channels:

| Channel id | Name (en / zh) | Importance |
|---|---|---|
| `flare.messages` | Chat messages / 聊天消息 | high, sound |
| `flare.quiet` | Silent chat updates / 聊天消息静默更新 | low, no sound or vibration |
| `flare.mentions` | Mentions in chats / 聊天中@我的消息 | high, sound |
| `flare.urgent` | Urgent chat messages / 紧急聊天消息 | high, sound |

Channel names follow the device language; importance and sound belong to the user once created. Each name
names a chat scenario on purpose: vivo rejects broad names such as 「消息」 or 「推送」 when channels are
registered (see [Registering the channels](#registering-the-channels-operator)), and the specific names read
the same way in the notification settings of other makers.

**Corrections.** While a host is the current one (from the first `refresh` or foreground that gets it until a
different host or `signOut`), the module collects `FlarePushHost.notificationCorrections()` and applies each
`PlatformNotificationCorrection`: `Clear(collapseIds)` cancels by tag (a conversation read on this or another
device), `ClearAll` removes every notification of the module (the session ended), `Badge(count)` sets the launcher
badge where the launcher has an interface for it (Huawei and Honor, through their launcher badge provider; the module
declares the permissions and the provider queries) and does nothing elsewhere, where the count comes from the
notifications themselves. A known `badge` in a push outcome is applied the same way, and `signOut` sets it to 0.
`CorePushHost` turns the client's `notification.clear` and
`notification.badge` events into that flow; the client's native event subscription (`client.events.subscribeEvents`,
which the app opens for its own events) has to be open. The host interface has an empty default, so hosts without
events need nothing. `FlarePush.clearNotifications(collapseIds)` and `FlarePush.clearAllNotifications()` apply a
correction by hand; apps do not need them. `PlatformPushWire.clearCorrection` and `badgeCorrection` read the event
payloads for hosts that pass JSON.

**Tokens.** Each token is registered with `platform = android`, `appBundle` (applicationId), `locale`,
`timeZone`, `appVersion`; FCM adds `capabilities = ["dataMessages"]`. A token is sent again when one
of these changes (checked on every return to the foreground, and at once after `setLocale`), to every new
host and after `signOut`.

**Background presenter.** While the app is in the background the live link stays up on Android. With the
background presenter attached, the engine reports `STANDBY`, acknowledges as usual and decides the alerts itself;
the module posts them as system notifications. A push still covers a process that was frozen or killed.

```kotlin
// after the notification permission was granted (and in resident connection mode)
FlareBackgroundPresenter.attach()
FlareBackgroundPresenter.attached.collect { attached -> /* the engine has been told */ }
FlareBackgroundPresenter.detach()
```

- Attached means three things hold: the app asked for it (`attach`), a host is ready (signed in or restored),
  and notifications may be shown. Then the module calls the host's `setBackgroundPresenter(true)`; when any of
  them goes away it calls `false`. A revoked notification permission detaches (read on every return to the
  foreground and when an alert arrives without it); granting it again attaches again while the app still wants
  it. Every new host is told again; `signOut` keeps the app's wish.
- The host's `notificationPresentations()` (the engine's `notification.present`) is collected while the host is
  the current one. Presentations with surface `system` become notifications through the same presenter as pushes:
  the channel of the presentation, tag = `collapseId`, `setNumber(count)`; one without sound is a quiet update
  (`setOnlyAlertOnce`, silent). Surface `inApp` is left to the app's in-app banner.
- A tap on such a notification does not go through `resolveNotificationTap` (it carries no account): the
  notification carries a module token instead, and the route comes straight from its conversation. The token is
  replaced on `signOut` and when the engine clears everything (session end), so an old notification then only
  opens the app.

**Push bindings.** `FlarePush.setPushBindingsEnabled(false)` (resident connection mode) stops token registration
and calls the host's `clearPushToken` once per provider (`fcm`, `getui` and any provider a token arrived for), again
for each new host. `true` registers every token again. It is not stored; the app sets it at every start.

**Host additions.** `notificationPresentations()` (default: empty flow), `setBackgroundPresenter(attached)` and
`clearPushToken(provider)` (defaults throw `UnsupportedOperationException`; the module then treats the feature as
unavailable for that host and does not retry). `CorePushHost` maps them to `client.events.onNotificationPresent`,
`client.notification.setBackgroundPresenter` and `client.clearPushToken`; the social host passes
`notification.set_background_presenter`, `sdk.clear_push_token` and event 3503 through the social SDK.

**Vendor notification taps.** A notification the OS rendered for a vendor channel opens
`com.flare.im.push.FlarePushOpenActivity` (also reachable as `flarepush://open`) with the payload as a
JSON string in the `flare_push` extra; it forwards to the launcher activity. Payload keys spread as
string extras are accepted too.

## Registering the channels (operator)

Notifications this module posts itself (FCM data messages, Getui pass-through, the background presenter) are local
notifications. vivo treats a local notification channel that is not registered as operational messages: silent,
shown only when the user pulls down the shade, with no heads-up, lock screen, sound or vibration. Before release
the operator registers the four channels in the vivo push operations platform (「本地通知分类管理」, 「新增渠道」)
with exactly these values:

| 通知渠道 id | 通知渠道名称 | 一级分类 / 二级分类 |
|---|---|---|
| `flare.messages` | 聊天消息 | 系统消息 / 即时消息 |
| `flare.mentions` | 聊天中@我的消息 | 系统消息 / 即时消息 |
| `flare.urgent` | 紧急聊天消息 | 系统消息 / 即时消息 |
| `flare.quiet` | 聊天消息静默更新 | 系统消息 / 即时消息 |

- The id and the name must match what the app creates. vivo registers one name per id, the Chinese one; the
  English name of the same id needs no registration of its own.
- Registration needs a vivo push app. Review takes about 7 working days and takes effect within about 24 hours.
  A channel keeps the treatment it got when the device first created it, so devices that created it earlier change
  only after a reinstall.
- An app version that still ships an older name (such as 「消息」 for `flare.messages`) is registered with that name
  and the new one as the backup name (「备用渠道名称」) with the date the new version ships.
- vivo recommends one channel per secondary category and does not say whether four channels may share 即时消息;
  the usage descriptions should explain that the four differ only in sound and importance.
- OPPO's old private channel (`getui.android_vendor.oppo_channel_id`) registers one of these ids, normally
  `flare.messages`, with the same name. OPPO's new message classification needs no client channel.

What to apply for with each maker, the server credential fields and how to check the result are in the
[vendor instant messaging category handbook](https://github.com/flare-im/flare-knowledge-base/blob/main/docs/operations/push-vendor-im-category.md)
of the Flare knowledge base.

## Background restrictions

Guidance only, nothing is automated. `FlareBackgroundRestrictions` reports
`isIgnoringBatteryOptimizations`, `isBackgroundRestricted`, their combination as the three battery
settings levels (`delivery(context)`: `FlarePushBackgroundDelivery.UNRESTRICTED`, `OPTIMIZED`,
`RESTRICTED`) and the vendor (`FlarePushVendor`, with `hasAutoStartSettings`), and opens the battery
optimisation list (`openBatteryOptimizationSettings`) or the auto-start page of Huawei, Honor, Xiaomi,
OPPO and vivo (`openAutoStartSettings`). Those pages are private system screens that change between
releases: every attempt is guarded and falls back to the app's details page.

`FlarePush.backgroundDelivery: StateFlow<FlarePushBackgroundDelivery?>` follows the level the way
`FlarePush.permission` follows the permission: read on install, on `refresh()` and on every return to
the foreground, changes only, `null` until install. A settings row that collects it updates when the
user comes back from the battery settings.

## Tests

JVM unit tests with fakes, from a host that includes the module:

```bash
./gradlew :flare-core-android-push:testDebugUnitTest
```
