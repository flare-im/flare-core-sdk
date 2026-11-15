# flare-core-android-keepalive

English · [中文](README.zh-CN.md)

Resident connection mode for Flare IM on Android: a foreground service with an ongoing notification
keeps the process, and with it the live link, running while the app is in the background. It is an
optional dependency and off by default.

Use it only for deployments without any push channel (no FCM, no Getui, no vendor channels). While it
is on, the app registers no push binding and the server sees a device that stays in `Standby`; alerts
come from the live link through the background presenter of
[`flare-core-android-push`](../flare-core-android-push/README.md). Apps published in an app store should
not turn it on: store policies restrict `specialUse` foreground services and battery optimisation
exemptions.

The module depends on no engine package. The app connects it to its session through
`FlareKeepAliveHost`.

## What the app adds

### 1. Gradle

```kotlin
// settings.gradle.kts
include(":flare-core-android-keepalive")
project(":flare-core-android-keepalive").projectDir = file("<workspace>/flare-core-sdk/packages/flare-core-android-keepalive")

// app/build.gradle.kts
implementation(project(":flare-core-android-keepalive"))
```

The module manifest brings everything the service needs: `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_SPECIAL_USE`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`, the service
(`foregroundServiceType="specialUse"`, subtype property `im-persistent-connection`) and the restart
receiver. It does not declare `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.

### 2. `Application.onCreate`

Install it in the main process. Boot and package-replaced restarts run `Application.onCreate` first,
so the host is there when the service starts.

```kotlin
FlareKeepAlive.install(
    this,
    options = FlareKeepAliveOptions(smallIcon = R.drawable.ic_notification, launchActivity = MainActivity::class.java),
    host = object : FlareKeepAliveHost {
        override fun onKeepAliveStarted() {
            FlarePush.setPushBindingsEnabled(false) // clearPushToken for every provider, no new registrations
            FlareBackgroundPresenter.attach()
            resumeSessionInTheBackground()          // the process-level client keeps the link up
        }

        override fun onKeepAliveStopped() {
            if (!FlareKeepAlive.isEnabled(this@App)) FlarePush.setPushBindingsEnabled(true)
        }
    },
)
```

The client has to live at process level (owned by the `Application`), not by a screen: the service only
keeps the process alive, the link is the client's.

### 3. The switch

Show it only in builds without a push provider. The Compose kit's `NotificationDeliverySettings` has the
row (`residentMode`, `onResidentModeChange`) and the battery guidance row.

```kotlin
if (on) FlareKeepAlive.start(context) else FlareKeepAlive.stop(context)
```

## API

| Member | What it does |
|---|---|
| `FlareKeepAlive.install(application, options, host)` | Remembers options and host; starts the service when the switch is on. Calling it again replaces options and host. |
| `FlareKeepAlive.start(context)` | Turns the switch on (stored by the module) and starts the service. Returns whether the system accepted the start; in the background it may not, and the module tries again on the next return to the foreground. |
| `FlareKeepAlive.stop(context)` | Turns the switch off and stops the service; the ongoing notification goes away. |
| `FlareKeepAlive.isEnabled(context)` | The stored switch, off by default. |
| `FlareKeepAlive.running: StateFlow<Boolean>` | Whether the service is in the foreground. |
| `FlareKeepAlive.setHost(host)` | Replaces the host; a new host hears `onKeepAliveStarted` at once when the service runs. |
| `FlareKeepAliveHost` | `onKeepAliveStarted()` when the service starts (switched on, after boot, after an update, after the system recreated it), `onKeepAliveStopped()` when it stops. Main thread. |
| `FlareKeepAliveBattery.isIgnoringBatteryOptimizations(context)` | Whether the user exempted the app from battery optimisation. |
| `FlareKeepAliveBattery.openSettings(context)` | Opens the battery optimisation list (falls back to the app details page). The module never requests the exemption itself. |

`FlareKeepAliveOptions`: `smallIcon` (monochrome; 0 uses the module's), `color`, `title` (default: the
app name), `text` (default: the module's string, English or Chinese), `launchActivity` (default: the
launcher activity), `onError` (a refused start or foreground entry; carries no account or message data).

## Behaviour

- **Service.** `FlareKeepAliveService`, not exported, in the app's main process, type `specialUse` with
  subtype `im-persistent-connection` on Android 14 and later (no type before that). `START_STICKY`: when
  the system kills it, it comes back while the switch is on. It does no network work of its own.
- **Notification.** Channel `flare.keepalive`, named "Stay connected in the background" / 「后台保持连接」
  after the switch that turns the mode on, low importance, no sound, vibration or badge, ongoing, category
  `service`. A tap opens the app.
- **vivo.** The channel is not registered with vivo: none of vivo's secondary categories fits a connection
  notice, and vivo shows an unregistered channel silently in the shade only, which is what this channel asks
  for anyway. The alerts in this mode come from the four channels of `flare-core-android-push`; on vivo they
  ring only when those channels are registered (see that module's README), which needs a vivo push app.
- **Restarts.** `FlareKeepAliveRestartReceiver` handles `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED` and
  starts the service only when the switch is on. Both broadcasts are allowed to start a foreground service
  from the background. `install` and every return to the foreground start it again when it should run
  but does not.
- **Battery optimisation.** With optimisation on, the system can still stop the service or cut the
  network in Doze. The app shows the guidance row and opens the settings page when the user asks.

## Tests

```bash
./gradlew :flare-core-android-keepalive:testDebugUnitTest
```
