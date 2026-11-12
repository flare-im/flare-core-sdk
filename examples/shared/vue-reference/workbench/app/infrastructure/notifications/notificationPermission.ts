import { inject, provide, readonly, ref, type InjectionKey, type Ref } from "vue";
import type { NotificationPermissionState, NotificationPresenter } from "@flare-im/sdk/notifications";

/**
 * The host's system notification permission, one state for everything that shows it or asks for it: the soft-ask
 * after sign-in and the "New message notifications" row of the settings sheet. The host builds it once on the
 * presenter its notifier uses (the browser's `Notification` on the web, the notification plugin in Tauri) and hands it
 * to `ReferenceApp`; whoever asks updates the state the other one shows.
 */
export interface NotificationPermission {
  /** The permission as last read; `unsupported` until the first read. */
  readonly state: Readonly<Ref<NotificationPermissionState>>;
  /** Reads the permission again. Never asks. */
  refresh(): Promise<NotificationPermissionState>;
  /** Asks the user where the platform still can. Call it inside a click: browsers ask only from a user gesture. */
  request(): Promise<NotificationPermissionState>;
}

export function createNotificationPermission(
  presenter: Pick<NotificationPresenter, "permission" | "requestPermission">,
): NotificationPermission {
  const state = ref<NotificationPermissionState>("unsupported");

  async function refresh(): Promise<NotificationPermissionState> {
    try {
      state.value = await presenter.permission();
    } catch (error) {
      console.warn("[notifications] reading the permission failed", error);
    }
    return state.value;
  }

  async function request(): Promise<NotificationPermissionState> {
    try {
      // The presenter is called before anything is awaited, so the click that got here still counts as the gesture.
      state.value = await presenter.requestPermission();
    } catch (error) {
      console.warn("[notifications] asking for the permission failed", error);
      return refresh();
    }
    return state.value;
  }

  return { state: readonly(state), refresh, request };
}

const notificationPermissionKey: InjectionKey<NotificationPermission | null> = Symbol("flare-notification-permission");

/** Makes the host's permission available to the screens below (the settings sheet); `ReferenceApp` calls it. */
export function provideNotificationPermission(permission: NotificationPermission | null): void {
  provide(notificationPermissionKey, permission);
}

/** The host's permission, or null when the host shows no system notifications. */
export function useNotificationPermission(): NotificationPermission | null {
  return inject(notificationPermissionKey, null);
}
