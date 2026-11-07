# Optional native push host

This handwritten **runtime adapter**, not generated IM behavior, connects Android
and iOS OS callbacks to the existing Rust-owned conditional push lifecycle.
Core/Core SDK do not depend on Firebase, a Social service, a product application
or this package. It is optional; a normal Web/macOS/Linux/Windows IM client does
not become a fake mobile device. Direct APNs, Getui and other hosts can implement
`NativePushPort`; this Firebase adapter registers **FCM** tokens on both Android
and iOS, not APNs tokens disguised as FCM.

## Ownership and startup

```dart
final host = NativePushHost(
  port: FirebasePushPort(
    channelName: 'Messages', quietChannelName: 'Quiet messages'),
  binding: PushBindingCallbacks.core(client),
);
// After normal client init. No permission prompt at startup.
await host.setSessionActive(signedIn); // bool from the normal app auth flow
await host.start();
// Only from an explicit user action:
await host.refresh(requestPermission: true);
// Before normal logout/account switch:
await host.setSessionActive(false);
await client.logout();
// After the next normal successful login: setSessionActive(true).
// On shutdown: await host.stop(); host.dispose(); then dispose client.
```

See the real Social app's root/session wiring. An alternative
`PushBindingCallbacks.dispatch` uses the same core L1 operations
on an existing composite SDK handle. It does not create another handle/store.

The SDK remains the only owner of account/session epochs, token registration,
write-ahead revoke journal, CAS, unknown writes, logout and retry. The host only
fences stale OS callbacks and coalesces callback bursts (one in-flight token
callback, one follow-up read, no token queue). Permission withdrawal on resume
bypasses an unresolved write. A missing OS token invalidates the desired provider;
the host never re-enables permission before supplying the current token. Tokens
and vendor payloads are not logged or persisted by this adapter. SDK callback
completion and `listening` are **not** server registration or device delivery ACKs.

## Native app configuration

The real Social Flutter app composes this adapter behind the explicit build opt-in
`--dart-define=FLARE_NATIVE_PUSH=true`. Supply the matching local Firebase
**client configuration** at `android/app/google-services.json` or
`ios/Runner/GoogleService-Info.plist` (gitignored). These are never a
service-account key, APNs p8, platform key, API Key or bearer. The server's app FCM
credentials must target the same Firebase project. Android applies the standard
Google services plugin only for the opt-in build; iOS validates/copies the plist
before signing and initializes Firebase before Dart. Missing config fails the
enabled build; mismatched iOS bundle identity and stale disabled bundle config
also fail. There is deliberately no Dart-only options fallback: native vendor
services must be configured even when the OS starts a terminated process.

Android host requirements: POST_NOTIFICATIONS, auto-init/analytics disabled in
manifest until explicit opt-in, Java17/desugaring2.1.4, compile SDK36. The Social
app has these settings. Four stable channels reflect independent sound/badge
hints. The worker sends their exact IDs. Channels aren't recreated to override
user system settings; user choices still win. No foreground local alert is
duplicated over the SDK UI. Android background/terminated notification payloads
are displayed by the vendor's native service; no Flutter background service,
socket or privileged FFI session is started.

iOS host requirements: iOS15+, push entitlement matching signing environment
(development for Debug; production for Release/Profile), provisioned app identity,
remote-notification background mode, Firebase APNs configuration, and the UIScene
notification-center delegate established before didFinishLaunching returns. The
Social app has source wiring; signing/device installation is not proven by a
plist check. Never turn off Firebase delegate swizzling without supplying its
entire native replacement. FCM17 introduces FID direct-send; this package bounds
Firebase Messaging to 16.x for the server's existing HTTP-v1 registration-token
transport rather than silently registering a different vendor identity.

## Background and privacy semantics

`flareFirebaseBackgroundMessage` is an entry-point-preserved isolate handler.
It intentionally does not open SDK/store, accept chat history from vendor data,
mark read, perform business writes, run retries or navigate. Foreground/warm/cold
callbacks expose only one latest opaque `PushHint` through `hint` (a
ValueListenable, no paused-listener queue; cleared on logout/stop). A hint is not authorization:
an application must compare current app context and authorize/read through the
signed-in SDK before navigation. The Social app doesn't auto-navigate from hints;
normal OS resume feeds Rust's heartbeat/attention/sync API independently of push.

Logout removes already displayed notifications and retires SDK bindings; vendor
requests already in flight cannot be recalled. No promise of zero old-account
alerts after logout is made. OS force-stop/permission denial, Apple background
limits, absent Play Services, network and vendor throttling can prevent delivery;
foreground SDK sync is the recovery path. There is no silent background message
that can independently prove a business event or delivery.

## Validation scope

`flutter test` exercises the actual host/controller with controlled ports,
production channel definitions and the production background entry point.
`flutter analyze` checks actual adapter/plugin APIs. This does **not** establish
FCM/APNs device receipt, Android/iOS native linking, signing, final init, Flutter
visual regression or two-client communication. Those belong to final local R6;
vendor receipt additionally requires matching project credentials and a device.

Local follow-up: the actual Social reference app now builds an Android ARM64
APK and iOS Simulator Runner with push explicitly off, no vendor config, and
current target-specific composite FFI artifacts. The current library is packaged
on Android and linked/exported on Simulator. This does not establish OS loading,
permission/background behavior, device receipt, IM traffic or the standalone Core
client on every platform. Details are in the app's `docs/native-push-host.md` and
the workspace plan; no Firebase or Social dependency was added to Core/Core SDK.

Native configuration follows the [Android resources/plugin](https://firebase.google.com/docs/android/google-services-plugin-and-file)
and [Apple bundled configuration](https://firebase.google.com/docs/ios/setup) contracts.
