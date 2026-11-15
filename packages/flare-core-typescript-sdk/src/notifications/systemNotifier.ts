import type { NotificationClearEvent } from "../model/notification_clear_event";
import type { NotificationPresentation } from "../model/notification_presentation";
import { browserNotificationPresenter } from "./browserPresenter";

/**
 * System notifications for desktop and web hosts.
 *
 * The engine decides every alert itself (mute, quiet hours, the conversation on screen, one notification per
 * conversation, the ring budget) and renders its text; it hands each one over as `notification.present`. Desktop and
 * web alert by themselves, so the notifier shows the presentations whose surface is `system` as OS notifications and
 * takes them down on `notification.clear`. Presentations with surface `inApp` belong to the in-app banner of the
 * design kit, not to the notifier.
 *
 * Free of the wasm runtime and of every bridge: the core client's `client.events` is an event source as it is, and
 * SDKs with their own runtime (the social SDK's `notification` module) hand in theirs.
 */

/** A listener registration: the core client's `EventSubscription`, or a plain removal function. */
export type NotificationListenerHandle = { unsubscribe(): void } | (() => void);

/** Where the notifier hears the engine's notification events. `client.events` is one. */
export interface NotificationEventSource {
  onNotificationPresent(
    listener: (presentation: NotificationPresentation) => void,
  ): NotificationListenerHandle | Promise<NotificationListenerHandle>;
  onNotificationClear(
    listener: (event: NotificationClearEvent) => void,
  ): NotificationListenerHandle | Promise<NotificationListenerHandle>;
}

/** Whether the host may show notifications: `prompt` until the user decided, `unsupported` without the API. */
export type NotificationPermissionState = "granted" | "denied" | "prompt" | "unsupported";

/** What a click opens: the conversation and the newest message the notification stands for, when there is one. */
export interface NotificationTarget {
  conversationId: string;
  messageId?: string;
}

/**
 * Puts notifications on screen. The browser's `Notification` is the default ({@link browserNotificationPresenter});
 * a Tauri host passes one built on its notification plugin. Every method may be asynchronous; failures are reported
 * through {@link SystemNotificationsOptions.onError} and never thrown at the host.
 */
export interface NotificationPresenter {
  /** The current permission. Never asks. */
  permission(): NotificationPermissionState | Promise<NotificationPermissionState>;
  /** Asks the user when the platform still can, then answers the permission as it is afterwards. */
  requestPermission(): Promise<NotificationPermissionState>;
  /**
   * Shows `notification`, replacing the shown one with the same `collapseId` (one notification per conversation).
   * Rings only when `notification.sound` is true. Calls `activate` when the user clicks it; a platform that reports
   * no clicks never calls it.
   */
  show(notification: NotificationPresentation, activate: () => void): void | Promise<void>;
  /** Takes down the notifications with these collapse ids. */
  close(collapseIds: readonly string[]): void | Promise<void>;
  /** Takes down every notification it showed. */
  closeAll(): void | Promise<void>;
  /** Brings the app's window to the front; called on a click before `onOpen`. */
  focus?(): void | Promise<void>;
  /**
   * Clicks the presenter hears apart from `show`'s `activate`: a Service Worker reports clicks also on notifications an
   * earlier page showed. Returns the function that stops listening.
   */
  onActivate?(listener: (target: NotificationTarget) => void): () => void;
}

export interface SystemNotificationsOptions {
  /** A click, after the window came to the front: open the conversation. */
  onOpen?: (target: NotificationTarget) => void;
  /** Defaults to the browser's `Notification` ({@link browserNotificationPresenter}). */
  presenter?: NotificationPresenter;
  /** A presenter or event source failure; nothing is thrown. */
  onError?: (error: unknown) => void;
}

/** A running notifier. */
export interface SystemNotifications {
  /** The presenter's permission. */
  permission(): Promise<NotificationPermissionState>;
  /** Asks for the permission; call it from a user gesture (browsers ignore it otherwise). */
  requestPermission(): Promise<NotificationPermissionState>;
  /** Stops listening and takes down the notifications it showed. A second call does nothing. */
  stop(): void;
}

/**
 * Shows the engine's system notifications until `stop()`; apps make this one call once the client exists:
 *
 * ```ts
 * const notifications = startSystemNotifications(client.events, {
 *   onOpen: ({ conversationId }) => router.push(`/chat/${conversationId}`),
 * });
 * ```
 *
 * The permission is the host's to ask for at a moment the user understands (`requestPermission`); without it
 * nothing shows and nothing fails.
 */
export function startSystemNotifications(
  events: NotificationEventSource,
  options: SystemNotificationsOptions = {},
): SystemNotifications {
  const report = (error: unknown) => {
    try {
      options.onError?.(error);
    } catch {
      // A failing error handler has nowhere left to report to.
    }
  };
  let presenter: NotificationPresenter;
  try {
    presenter = options.presenter ?? browserNotificationPresenter();
  } catch (error) {
    report(error);
    presenter = inertPresenter;
  }
  let stopped = false;
  const handles: NotificationListenerHandle[] = [];

  const run = (call: () => void | Promise<void>) => {
    try {
      const result = call();
      if (result instanceof Promise) result.catch(report);
    } catch (error) {
      report(error);
    }
  };

  const open = async ({ conversationId, messageId }: NotificationTarget) => {
    if (stopped) return;
    try {
      await presenter.focus?.();
    } catch (error) {
      report(error);
    }
    // The digest notification belongs to no conversation: bringing the app forward is all it does.
    if (!conversationId) return;
    options.onOpen?.({ conversationId, ...(messageId ? { messageId } : {}) });
  };

  const present = (presentation: NotificationPresentation) => {
    if (stopped || presentation.surface !== "system") return;
    if (!presentation.title && !presentation.body) return;
    run(() => presenter.show(presentation, () => void open(presentation).catch(report)));
  };

  const clear = (event: NotificationClearEvent) => {
    if (stopped) return;
    if (event.all) {
      run(() => presenter.closeAll());
    } else if (event.collapseIds.length > 0) {
      run(() => presenter.close(event.collapseIds));
    }
  };

  const release = (handle: NotificationListenerHandle) => {
    try {
      if (typeof handle === "function") handle();
      else handle.unsubscribe();
    } catch (error) {
      report(error);
    }
  };

  const keep = (registration: () => NotificationListenerHandle | Promise<NotificationListenerHandle>) => {
    try {
      const handle = registration();
      if (handle instanceof Promise) {
        handle.then((resolved) => {
          // Stopped while the registration was on its way: let it go at once.
          if (stopped) release(resolved);
          else handles.push(resolved);
        }, report);
      } else {
        handles.push(handle);
      }
    } catch (error) {
      report(error);
    }
  };
  keep(() => events.onNotificationPresent(present));
  keep(() => events.onNotificationClear(clear));
  // Clicks the presenter hears on its own (a Service Worker's) take the same way as `activate`.
  if (presenter.onActivate) keep(() => presenter.onActivate!((target) => void open(target).catch(report)));

  return {
    async permission() {
      try {
        return await presenter.permission();
      } catch (error) {
        report(error);
        return "unsupported";
      }
    },
    async requestPermission() {
      try {
        return await presenter.requestPermission();
      } catch (error) {
        report(error);
        return "unsupported";
      }
    },
    stop() {
      if (stopped) return;
      stopped = true;
      for (const handle of handles.splice(0)) release(handle);
      run(() => presenter.closeAll());
    },
  };
}

/** A runtime without a notification API: nothing shows. */
const inertPresenter: NotificationPresenter = {
  permission: () => "unsupported",
  requestPermission: async () => "unsupported",
  show: () => undefined,
  close: () => undefined,
  closeAll: () => undefined,
};
