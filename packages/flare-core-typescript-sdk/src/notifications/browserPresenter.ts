import type { NotificationPresentation } from "../model/notification_presentation";
import { FLARE_NOTIFICATION_CLICK, type FlareNotificationClickMessage } from "./serviceWorkerClicks";
import type { NotificationPermissionState, NotificationPresenter, NotificationTarget } from "./systemNotifier";

/** The options of one browser notification this presenter sets. */
export interface BrowserNotificationOptions {
  body?: string;
  tag?: string;
  /** Ring and show again although a notification with the same tag is shown (needs a tag). */
  renotify?: boolean;
  silent?: boolean;
  icon?: string;
  data?: unknown;
}

/** One shown browser notification, as far as the presenter touches it. */
export interface BrowserNotificationInstance {
  onclick: ((event: any) => void) | null;
  onclose: ((event: any) => void) | null;
  close(): void;
}

/** The browser's `Notification` constructor and its permission, as far as the presenter uses them. */
export interface BrowserNotificationApi {
  readonly permission: string;
  requestPermission(): Promise<string>;
  new (title: string, options?: BrowserNotificationOptions): BrowserNotificationInstance;
}

/** The parts of `ServiceWorkerRegistration` the presenter uses. */
export interface BrowserNotificationRegistration {
  showNotification(title: string, options?: BrowserNotificationOptions): Promise<void>;
  getNotifications(filter?: { tag?: string }): Promise<ReadonlyArray<{ close(): void }>>;
}

/** The parts of `ServiceWorkerContainer` the presenter uses: whether a worker controls the page, and its messages. */
export interface BrowserServiceWorkerContainer {
  readonly controller: unknown;
  readonly ready: Promise<BrowserNotificationRegistration>;
  addEventListener(type: "message", listener: (event: { readonly data: unknown }) => void): void;
}

export interface BrowserNotificationPresenterOptions {
  /** The `Notification` constructor; defaults to the page's. `null` means the runtime has none. */
  notification?: BrowserNotificationApi | null;
  /**
   * The Service Worker registration that shows the notifications. Defaults to the page's while a worker controls the
   * page (`navigator.serviceWorker.ready`), and to the `Notification` constructor while none does. `null` keeps to the
   * constructor.
   */
  registration?: BrowserNotificationRegistration | null;
  /** Where the worker's click messages arrive; defaults to `navigator.serviceWorker`. `null` hears none. */
  serviceWorker?: BrowserServiceWorkerContainer | null;
  /** The window to bring to the front on a click; defaults to the page's. */
  window?: { focus(): void } | null;
  /** Icon shown with every notification (an app icon URL). */
  icon?: string;
}

function globalNotification(): BrowserNotificationApi | null {
  const value = (globalThis as Record<string, unknown>).Notification;
  return typeof value === "function" ? value as unknown as BrowserNotificationApi : null;
}

function globalWindow(): { focus(): void } | null {
  const value = (globalThis as Record<string, unknown>).window;
  return value && typeof (value as { focus?: unknown }).focus === "function" ? value as { focus(): void } : null;
}

function globalServiceWorker(): BrowserServiceWorkerContainer | null {
  const page = globalThis as unknown as { navigator?: { serviceWorker?: BrowserServiceWorkerContainer } };
  return page.navigator?.serviceWorker ?? null;
}

function permissionState(api: BrowserNotificationApi | null): NotificationPermissionState {
  if (!api) return "unsupported";
  switch (api.permission) {
    case "granted":
      return "granted";
    case "denied":
      return "denied";
    default:
      return "prompt";
  }
}

/** The click a worker posted; null for any other message. */
function clickOf(data: unknown): FlareNotificationClickMessage | null {
  const message = data as Partial<FlareNotificationClickMessage> | null | undefined;
  if (!message || message.type !== FLARE_NOTIFICATION_CLICK || typeof message.conversationId !== "string") return null;
  return {
    type: FLARE_NOTIFICATION_CLICK,
    collapseId: typeof message.collapseId === "string" ? message.collapseId : "",
    conversationId: message.conversationId,
    ...(typeof message.messageId === "string" && message.messageId ? { messageId: message.messageId } : {}),
  };
}

/**
 * The browser's notifications (web pages and webviews that have them). While a Service Worker controls the page they
 * go through its registration (`showNotification`), the only way Android Chrome takes; otherwise through the
 * `Notification` constructor. One notification per conversation: the tag is the collapse id, so a newer notification
 * for the conversation replaces the shown one, and it rings again only when the engine asked for a sound. A click
 * closes it, brings the window to the front and opens the conversation; a click on a worker's notification reaches the
 * page through the worker (`handleFlareNotificationClick` in the app's `sw.ts`), also for one an earlier page showed.
 * Nothing shows before the user granted the permission; runtimes without the API (React Native, some mobile browsers)
 * show nothing either.
 */
export function browserNotificationPresenter(
  options: BrowserNotificationPresenterOptions = {},
): NotificationPresenter {
  const api = options.notification === undefined ? globalNotification() : options.notification;
  const target = options.window === undefined ? globalWindow() : options.window;
  const container = options.serviceWorker === undefined ? globalServiceWorker() : options.serviceWorker;
  /** What the constructor showed, by tag. */
  const shown = new Map<string, BrowserNotificationInstance>();
  /** The `activate` of what the worker showed, by tag. */
  const activations = new Map<string, () => void>();
  /** Who hears the worker's clicks on notifications this page did not show. */
  const listeners = new Set<(target: NotificationTarget) => void>();
  let queue: Promise<unknown> = Promise.resolve();

  /** The registration that shows notifications now: the given one, or the page's while a worker controls it. */
  const worker = (): BrowserNotificationRegistration | Promise<BrowserNotificationRegistration> | null => {
    if (options.registration !== undefined) return options.registration;
    return container?.controller ? container.ready : null;
  };

  /** Runs `task` after the worker calls before it, so a close never overtakes the show it takes down. */
  const inOrder = (task: () => Promise<void>): Promise<void> => {
    const run = queue.then(task);
    queue = run.catch(() => undefined);
    return run;
  };

  if (container && options.registration !== null) {
    container.addEventListener("message", (event) => {
      const click = clickOf(event.data);
      if (!click) return;
      const activate = click.collapseId ? activations.get(click.collapseId) : undefined;
      if (activate) {
        activations.delete(click.collapseId);
        activate();
        return;
      }
      const clicked: NotificationTarget = {
        conversationId: click.conversationId,
        ...(click.messageId ? { messageId: click.messageId } : {}),
      };
      for (const listener of listeners) listener(clicked);
    });
  }

  return {
    permission: () => permissionState(api),

    async requestPermission() {
      if (api && api.permission === "default") {
        await api.requestPermission();
      }
      return permissionState(api);
    },

    show(presentation: NotificationPresentation, activate: () => void) {
      if (!api || api.permission !== "granted") return;
      const title = presentation.title || presentation.body;
      const tag = presentation.collapseId;
      const settings: BrowserNotificationOptions = {
        body: presentation.title ? presentation.body : "",
        silent: !presentation.sound,
        data: { conversationId: presentation.conversationId, messageId: presentation.messageId },
      };
      if (tag) {
        settings.tag = tag;
        // A silent replacement only updates the text; renotify together with silent is rejected by browsers.
        settings.renotify = presentation.sound;
      }
      if (options.icon) settings.icon = options.icon;

      const registration = worker();
      if (registration) {
        // The worker hears the click and posts it back here.
        if (tag) activations.set(tag, activate);
        return inOrder(async () => (await registration).showNotification(title, settings));
      }

      const notification = new api(title, settings);
      notification.onclick = () => {
        notification.close();
        activate();
      };
      if (!tag) return;
      shown.set(tag, notification);
      notification.onclose = () => {
        // A replacement closes the older one; only forget the tag when it is still the shown one.
        if (shown.get(tag) === notification) shown.delete(tag);
      };
    },

    close(collapseIds: readonly string[]) {
      for (const collapseId of collapseIds) {
        const notification = shown.get(collapseId);
        shown.delete(collapseId);
        activations.delete(collapseId);
        notification?.close();
      }
      const registration = worker();
      if (!registration) return;
      return inOrder(async () => {
        const showing = await registration;
        for (const tag of collapseIds) {
          for (const notification of await showing.getNotifications({ tag })) notification.close();
        }
      });
    },

    closeAll() {
      const all = [...shown.values()];
      shown.clear();
      activations.clear();
      for (const notification of all) notification.close();
      const registration = worker();
      if (!registration) return;
      // The worker's notifications outlive the page: those an earlier page showed go too.
      return inOrder(async () => {
        for (const notification of await (await registration).getNotifications()) notification.close();
      });
    },

    focus() {
      target?.focus();
    },

    onActivate(listener: (clicked: NotificationTarget) => void) {
      listeners.add(listener);
      return () => void listeners.delete(listener);
    },
  };
}
