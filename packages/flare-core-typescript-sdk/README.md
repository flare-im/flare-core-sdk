# @flare-im/sdk

English · [中文](README.zh-CN.md)

The TypeScript client SDK for Flare IM — a typed wrapper over the Rust core (`flare-im-core-sdk`).

All the real IM logic (connection, sync, storage, timeline) lives in the Rust
core; this package wires it onto the various JS runtimes and provides complete
TypeScript types.

## Install

```bash
npm install @flare-im/sdk
```

> **This package ships TypeScript sources, not compiled JavaScript.**
>
> Every entry point resolves to a `.ts` file, so **your bundler has to transpile it**.
> Most setups already do the right thing (Vite, Next.js with `transpilePackages`,
> Nuxt, Expo). Two cases need one line of config:
>
> - **Webpack**: `node_modules` is excluded from `ts-loader`/`babel-loader` by default —
>   add an include rule for `@flare-im/sdk`.
> - **Plain Node.js**: run it through a TS-aware loader (`tsx`, `ts-node`), or import it
>   from a bundled app rather than directly.
>
> Shipping sources is deliberate: the runtime entry points differ per platform and the
> types stay exact. If your toolchain cannot transpile dependencies, tell us in an issue —
> that is the signal we need to publish a build.

## Pick an entry point by runtime

Transport and storage capabilities differ per runtime, so the entry points are
split — import from the matching subpath:

| Runtime | Import path | Transport / storage |
|---|---|---|
| Browser / H5 | `@flare-im/sdk/web` | WebSocket (WASM) + IndexedDB |
| Tauri desktop | `@flare-im/sdk/tauri` | QUIC + SQLite |
| uni-app | `@flare-im/sdk/uni-app` | native core |
| React Native | `@flare-im/sdk/react-native` | native core |

```ts
import { FlareCoreSdk } from "@flare-im/sdk/uni-app";
```

Swap `/uni-app` for `/web` in the browser or `/tauri` for Tauri; the rest of
your code is unchanged.

> The Tauri entry point requires the peer dependency `@tauri-apps/api ^2.0.0`.

## Other subpaths

```ts
import { SdkOperations, SdkEvents } from "@flare-im/sdk/contract";
```

`api` / `listener` / `model` / `callback` / `contract` / `media` / `lifecycle` /
`notifications` export operations, event listeners, data models, callbacks, the
protocol contract, media, lifecycle and system notifications respectively.

## System notifications (desktop and web)

The engine decides every alert itself (mute, quiet hours, the conversation on screen, one notification per
conversation, the ring budget) and renders its text. Desktop and web alert by themselves, so they show the engine's
`notification.present` with surface `system` as OS notifications, and take them down on `notification.clear`. One call
does it:

```ts
import { startSystemNotifications } from "@flare-im/sdk/notifications";

const notifications = startSystemNotifications(client.events, {
  onOpen: ({ conversationId, messageId }) => openConversation(conversationId, messageId),
});

// From a user gesture (a settings switch, an onboarding step): browsers ignore it otherwise.
await notifications.requestPermission();   // "granted" | "denied" | "prompt" | "unsupported"

// On sign-out or teardown: stops listening and takes down what it showed.
notifications.stop();
```

- The default presenter is the browser's notifications: the tag is the collapse id, so a newer notification for the
  conversation replaces the shown one; it rings again only when the engine set `sound`; a click closes it, focuses the
  window and calls `onOpen` (the digest notification has no conversation and only focuses).
- While a Service Worker controls the page, the presenter shows through its registration (`showNotification`), the
  only way Android Chrome takes, and through the `Notification` constructor otherwise; the `registration` option (or
  `null`) overrides that. Those notifications report their clicks to the worker, so the app's `sw.ts` hands them on
  (see below). `closeAll()` then takes down every notification of the registration, those an earlier page showed too.
- Nothing shows before the permission is granted, and nothing fails without it. `permission()` reads it.
- Presentations with surface `inApp` are the in-app banner's (the design kit), not the notifier's.
- The event source is anything with `onNotificationPresent` and `onNotificationClear` returning a subscription, a
  removal function or a promise of one: `client.events` as it is, or the social SDK's `notification` module.
- The app still reports the conversation on screen with `client.notification.setFocus({ conversationId })`; desktop
  and web never call `setBackgroundPresenter`.

The click on a notification the worker showed arrives in the worker. One line in the app's `sw.ts` hands it to the
page, which opens the conversation as for any other click (also for a notification an earlier page showed):

```ts
import { handleFlareNotificationClick } from "@flare-im/sdk/notifications";

self.addEventListener("notificationclick", (event) => handleFlareNotificationClick(event));
```

It closes the notification, posts a `FlareNotificationClickMessage` (`type: FLARE_NOTIFICATION_CLICK`, the collapse id,
the conversation and message ids) to the app's most recently focused window and brings it to the front. With no
window open it opens the app at the worker's scope, or at `url`; a page that starts that way comes up without the
conversation. It returns false, and leaves the click alone, for notifications the presenter did not show.

A Tauri host passes its own presenter, built on its notification plugin:

```ts
import {
  isPermissionGranted, requestPermission, sendNotification, removeActive,
} from "@tauri-apps/plugin-notification";
import { getCurrentWindow } from "@tauri-apps/api/window";
import type { NotificationPresenter } from "@flare-im/sdk/notifications";

const ids = new Map<string, number>(); // collapse id -> the plugin's numeric id
const idOf = (collapseId: string) => {
  let id = ids.get(collapseId);
  if (id === undefined) ids.set(collapseId, (id = ids.size + 1));
  return id;
};

const tauriPresenter: NotificationPresenter = {
  permission: async () => ((await isPermissionGranted()) ? "granted" : "prompt"),
  requestPermission: async () => ((await requestPermission()) === "granted" ? "granted" : "denied"),
  show: (n) => sendNotification({ id: idOf(n.collapseId), title: n.title, body: n.body, group: n.threadId, silent: !n.sound }),
  close: (collapseIds) => removeActive(collapseIds.filter((c) => ids.has(c)).map((c) => ({ id: ids.get(c)! }))),
  closeAll: async () => removeActive([...ids.values()].map((id) => ({ id }))),
  focus: async () => { await getCurrentWindow().show(); await getCurrentWindow().setFocus(); },
};

startSystemNotifications(client.events, { presenter: tauriPresenter, onOpen });
```

The presenter's `show` gets an `activate` callback for the click; a platform that reports no clicks never calls it. A
presenter that hears clicks apart from `show` (the browser one, through the worker) offers `onActivate(listener)`,
which the notifier follows the same way. The subpath pulls in neither the wasm runtime nor a bridge.

## Keeping earlier web builds

A rollback or a staged rollout goes back to an older web build, so that build's
`builds/<buildId>/` and hashed files must outlive later deployments. A deployment
that replaces the site drops them. Between the build and the deployment, carry them
over from what is deployed now:

```bash
npx flare-web-retain-builds --previous /srv/site --out dist --keep 3
```

`--keep` counts earlier builds and defaults to 3; the build in `--out` is not one of
them. `--out` defaults to `dist`. The order is kept in `builds/history.json`, which
has to deploy with the rest. A build that lost a file is dropped, with a warning, and
the next older one takes its place. A first deployment passes `--first-deployment` instead of `--previous`;
a `--previous` that does not exist is an error, so a wrong path cannot drop the earlier builds.

## A complete, runnable example

This package is the SDK layer; running it needs the matching runtime bridge and
a server. For complete, runnable apps see [`examples/`](../../examples/) in the
repository — `flare-core-uni-app` is the most fully wired one.

For how to start the server, see `QUICKSTART.md` in the flare-im-core repository
(up and running in five minutes, no self-built user system required).

## For contributors

**Do not add IM business logic here.** Behavior belongs in `flare-im-core-sdk`
(Rust), exposed through `bindings/c`, then reflected in `sdk-spec/manifest.json`.
This package only does typed forwarding — pushing logic down into the core is
what lets all seven platforms share one implementation.

- Contract status: `contract-synced`
- Async model: Promise + event subscription
- FFI contract: `flare-im-ffi/v1`

## License

Apache-2.0
