/**
 * Notification clicks inside the app's Service Worker.
 *
 * A notification shown through `ServiceWorkerRegistration.showNotification`, which the browser presenter uses whenever
 * a worker controls the page (Android Chrome offers nothing else), reports its click to the worker, not to the page.
 * One line in the app's `sw.ts` hands it on:
 *
 * ```ts
 * import { handleFlareNotificationClick } from "@flare-im/sdk/notifications";
 *
 * self.addEventListener("notificationclick", (event) => handleFlareNotificationClick(event));
 * ```
 *
 * The helper closes the notification, posts a {@link FlareNotificationClickMessage} to the app's window and brings it
 * to the front, opening one when none is open. The presenter in the page runs the click as it runs a click on a
 * notification it showed by itself.
 */

/** The `type` of {@link FlareNotificationClickMessage}. */
export const FLARE_NOTIFICATION_CLICK = "flare-notification:click";

/** What the worker posts to the page on a click. */
export interface FlareNotificationClickMessage {
  readonly type: typeof FLARE_NOTIFICATION_CLICK;
  /** The notification's tag: the presentation's collapse id, empty when it had none. */
  readonly collapseId: string;
  /** Empty for the digest notification, which belongs to no conversation. */
  readonly conversationId: string;
  readonly messageId?: string;
}

/** The parts of a shown `Notification` the helper uses. */
export interface FlareWorkerNotification {
  readonly tag: string;
  readonly data: unknown;
  close(): void;
}

/** The parts of `NotificationEvent` the helper uses. */
export interface FlareNotificationClickEvent {
  readonly notification: FlareWorkerNotification;
  waitUntil(work: Promise<unknown>): void;
}

/** The parts of `WindowClient` the helper uses. */
export interface FlareNotificationWindowClient {
  readonly url: string;
  focus(): Promise<unknown>;
  postMessage(message: FlareNotificationClickMessage): void;
}

/** The parts of `ServiceWorkerGlobalScope` the helper uses. */
export interface FlareNotificationClickScope {
  readonly registration: { readonly scope: string };
  readonly clients: {
    matchAll(options: {
      type: "window";
      includeUncontrolled: boolean;
    }): Promise<readonly FlareNotificationWindowClient[]>;
    openWindow(url: string): Promise<FlareNotificationWindowClient | null>;
  };
}

export interface FlareNotificationClickOptions {
  /** The page to open when no window of the app is open. Default the worker's scope: the app's start. */
  url?: string;
  /** The worker's global scope; default `self`. */
  scope?: FlareNotificationClickScope;
}

/** The message for a click on `notification`; null when the presenter did not show it. */
function clickMessageOf(notification: FlareWorkerNotification): FlareNotificationClickMessage | null {
  const data = notification.data as { conversationId?: unknown; messageId?: unknown } | null | undefined;
  if (!data || typeof data !== "object" || typeof data.conversationId !== "string") return null;
  return {
    type: FLARE_NOTIFICATION_CLICK,
    collapseId: notification.tag,
    conversationId: data.conversationId,
    ...(typeof data.messageId === "string" && data.messageId ? { messageId: data.messageId } : {}),
  };
}

async function deliver(
  scope: FlareNotificationClickScope,
  url: string,
  message: FlareNotificationClickMessage,
): Promise<void> {
  const windows = await scope.clients.matchAll({ type: "window", includeUncontrolled: true });
  // Most recently focused first; pages of the origin outside the worker's scope are another app's.
  const open = windows.find((client) => client.url.startsWith(scope.registration.scope));
  if (open) {
    open.postMessage(message);
    await open.focus();
    return;
  }
  // A page that starts now hears the message only if it already listens; the app opens either way.
  const opened = await scope.clients.openWindow(url);
  opened?.postMessage(message);
}

/**
 * Handles a `notificationclick` whose notification the presenter showed and says whether it was one; a worker with
 * notifications of its own handles the clicks this returns false for.
 */
export function handleFlareNotificationClick(
  event: FlareNotificationClickEvent | Event,
  options: FlareNotificationClickOptions = {},
): boolean {
  const click = event as FlareNotificationClickEvent;
  const notification = click.notification as FlareWorkerNotification | undefined;
  const message = notification ? clickMessageOf(notification) : null;
  if (!notification || !message) return false;
  notification.close();
  const scope = options.scope ?? (globalThis as unknown as FlareNotificationClickScope);
  click.waitUntil(deliver(scope, options.url ?? scope.registration.scope, message));
  return true;
}
