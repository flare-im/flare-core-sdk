import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  browserNotificationPresenter,
  startSystemNotifications,
  type SystemNotifications,
} from "@flare-im/sdk/notifications";
import type { provideFlareSdk } from "@flare-im/vue-ui/app";

type ElectronDesktopBridge = {
  runtime?: string;
  setUnreadCount?(count: number): Promise<boolean>;
};

declare global {
  interface Window {
    flareDesktop?: ElectronDesktopBridge;
  }
}

type ReferenceSdk = ReturnType<typeof provideFlareSdk>;

function warn(error: unknown): void {
  console.warn("[notifications]", error);
}

/**
 * The engine's alerts in the Electron renderer. The engine decides every alert (mute, quiet hours, the conversation on
 * screen, one notification per conversation, the ring budget) and renders its text; this only shows what it hands
 * over: system notifications through the SDK notifier with the browser presenter (Electron gives the renderer the
 * HTML `Notification`, allowed by default), a click bringing the window forward and opening the conversation, and the
 * dock / taskbar badge and tray title from `notification.badge` through the preload bridge. The conversation on
 * screen (the chat page of a focused window) is reported to the engine. It starts with the session and stops on
 * sign-out. Call it in the root component's setup, after the SDK is provided.
 */
export function useElectronNotifications(sdk: ReferenceSdk): void {
  const router = useRouter();
  const route = useRoute();
  const bridge = window.flareDesktop?.runtime === "electron" ? window.flareDesktop : undefined;
  let notifier: SystemNotifications | null = null;
  let badge: { unsubscribe(): void } | null = null;

  async function openConversation(conversationId: string): Promise<void> {
    if (!conversationId || !sdk.loggedIn.value) return;
    try {
      const selecting = sdk.selectConversation(conversationId);
      await router.push({ name: "chat" });
      await selecting;
    } catch (error) {
      warn(error);
    }
  }

  function setBadge(count: number): void {
    void bridge?.setUnreadCount?.(count).catch(warn);
  }

  function start(): void {
    stop();
    notifier = startSystemNotifications(sdk.client.events, {
      presenter: browserNotificationPresenter(),
      onOpen: ({ conversationId }) => void openConversation(conversationId),
      onError: warn,
    });
    badge = sdk.client.events.onNotificationBadge((event) => setBadge(event.count));
  }

  function stop(): void {
    notifier?.stop();
    notifier = null;
    badge?.unsubscribe();
    badge = null;
  }

  watch(sdk.loggedIn, (loggedIn) => {
    if (loggedIn) {
      start();
    } else {
      stop();
      setBadge(0);
    }
  }, { immediate: true });

  // The conversation on screen: the chat page of a focused window. Its messages do not alert while it is there.
  const windowFocused = ref(true);
  const onWindowFocus = () => { windowFocused.value = true; };
  const onWindowBlur = () => { windowFocused.value = false; };
  onMounted(() => {
    windowFocused.value = document.hasFocus();
    window.addEventListener("focus", onWindowFocus);
    window.addEventListener("blur", onWindowBlur);
  });
  onBeforeUnmount(() => {
    window.removeEventListener("focus", onWindowFocus);
    window.removeEventListener("blur", onWindowBlur);
    stop();
  });

  const focusedConversation = computed(() => {
    if (!sdk.loggedIn.value || !windowFocused.value || route.name !== "chat") return "";
    return sdk.activeConversationId.value.trim();
  });
  /** Focus reports reach the engine in order: each waits for the one before. */
  let focusReport: Promise<void> = Promise.resolve();
  watch([focusedConversation, sdk.loggedIn], ([conversationId]) => {
    focusReport = focusReport
      .then(() => sdk.client.notification.setFocus(conversationId ? { conversationId } : {}))
      .catch(warn);
  }, { immediate: true });
}
