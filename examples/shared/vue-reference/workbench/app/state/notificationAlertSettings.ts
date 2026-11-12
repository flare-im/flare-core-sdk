/**
 * Quiet hours, notification preview and the multi-device policy of the settings sheet: the core's user notification
 * settings (`client.notification.getSettings` / `updateSettings`), one copy for all of the user's devices, with a
 * version. The rows show only once the settings were read. A change shows at once and is saved behind it: one save at
 * a time, carrying only what differs from the core's last answer and based on that answer's version; a change made
 * while a save is on its way goes out after that answer, and only the newest one does (the rows stay usable and an
 * open picker stays open). A save that fails (another device changed the settings first and the version no longer
 * matches, among others) reads the core's value again, goes back to it and is reported through `onSaveFailed`.
 *
 * The protocol has quiet hours or none; the kit has a switch and times. Turning the switch off clears the quiet hours
 * in the core (`clearQuietHours`) and the page keeps the times it showed, so turning it on again starts from them.
 */
import { onScopeDispose, ref, shallowRef } from "vue";
import type { FlareImClient } from "@flare-im/sdk/api";
import {
  MultiDeviceAlertPolicy,
  NotificationPreview,
  type UpdateUserNotificationSettingsRequest,
  type UserNotificationSettings,
} from "@flare-im/sdk/model";
import {
  defaultNotificationAlertPreferences,
  type FlareMultiDeviceAlert,
  type FlareNotificationAlertPreferences,
  type FlareNotificationPreview,
} from "@flare-im/vue-ui/contracts";

function previewForKit(preview: NotificationPreview | undefined): FlareNotificationPreview {
  switch (preview) {
    case NotificationPreview.SenderOnly:
      return "senderOnly";
    case NotificationPreview.Hidden:
      return "hidden";
    default:
      return "full";
  }
}

function previewForCore(preview: FlareNotificationPreview): NotificationPreview {
  switch (preview) {
    case "senderOnly":
      return NotificationPreview.SenderOnly;
    case "hidden":
      return NotificationPreview.Hidden;
    default:
      return NotificationPreview.Full;
  }
}

function multiDeviceForKit(policy: MultiDeviceAlertPolicy | undefined): FlareMultiDeviceAlert {
  switch (policy) {
    case MultiDeviceAlertPolicy.Immediate:
      return "immediate";
    case MultiDeviceAlertPolicy.BadgeOnly:
      return "badgeOnly";
    default:
      return "delay";
  }
}

function multiDeviceForCore(policy: FlareMultiDeviceAlert): MultiDeviceAlertPolicy {
  switch (policy) {
    case "immediate":
      return MultiDeviceAlertPolicy.Immediate;
    case "badgeOnly":
      return MultiDeviceAlertPolicy.BadgeOnly;
    default:
      return MultiDeviceAlertPolicy.Delay;
  }
}

/** The version of the settings; 0 when they were never changed. The next write is based on it. */
export function settingsVersionOf(settings: UserNotificationSettings): number {
  return Number(settings.settingsVersion ?? 0) || 0;
}

/**
 * How the core's settings look on the page. Without quiet hours the switch is off and the times are those of `shown`
 * (the kit's default window when nothing was shown yet).
 */
export function alertPreferencesFromSettings(
  settings: UserNotificationSettings,
  shown: FlareNotificationAlertPreferences | null,
): FlareNotificationAlertPreferences {
  const quiet = settings.quietHours;
  const kept = shown?.quietHours ?? defaultNotificationAlertPreferences.quietHours;
  return {
    quietHours: quiet
      ? {
          enabled: true,
          startMinute: quiet.startMinute,
          endMinute: quiet.endMinute,
          weekdays: quiet.weekdays,
          allowMentions: quiet.allowMentions,
        }
      : { ...kept, enabled: false },
    preview: previewForKit(settings.preview),
    multiDevice: multiDeviceForKit(settings.multiDevice),
  };
}

/**
 * The partial update that turns the core's `stored` settings into the page's `target`: only the items that differ,
 * based on `stored`'s version (the core rejects the whole update when they changed elsewhere in the meantime); quiet
 * hours turned off clear them. Null when nothing differs.
 */
export function settingsUpdateFor(
  stored: UserNotificationSettings,
  target: FlareNotificationAlertPreferences,
): UpdateUserNotificationSettingsRequest | null {
  const request: UpdateUserNotificationSettingsRequest = {
    clearQuietHours: false,
    baseSettingsVersion: settingsVersionOf(stored),
  };
  let changed = false;
  const quiet = target.quietHours;
  const current = stored.quietHours;
  if (quiet.enabled) {
    const same = current !== undefined && current !== null
      && current.startMinute === quiet.startMinute && current.endMinute === quiet.endMinute
      && current.weekdays === quiet.weekdays && current.allowMentions === quiet.allowMentions;
    if (!same) {
      const { startMinute, endMinute, weekdays, allowMentions } = quiet;
      request.quietHours = { startMinute, endMinute, weekdays, allowMentions };
      changed = true;
    }
  } else if (current) {
    request.clearQuietHours = true;
    changed = true;
  }
  const preview = previewForCore(target.preview);
  if (preview !== (stored.preview ?? NotificationPreview.Full)) {
    request.preview = preview;
    changed = true;
  }
  const multiDevice = multiDeviceForCore(target.multiDevice);
  if (multiDevice !== (stored.multiDevice ?? MultiDeviceAlertPolicy.Delay)) {
    request.multiDevice = multiDevice;
    changed = true;
  }
  return changed ? request : null;
}

/** Call it in a component's setup: once the component goes (sign-out), saves on their way no longer land. */
export function useNotificationAlertSettings(
  client: Pick<FlareImClient, "notification">,
  onSaveFailed: () => void,
) {
  /** The value on the page; null until the settings were read. */
  const preferences = shallowRef<FlareNotificationAlertPreferences | null>(null);
  /** The read failed and there is no value to show: the page says so and offers to retry. */
  const loadFailed = ref(false);
  /** The core's last answer; the next save is based on its version. */
  let stored: UserNotificationSettings | null = null;
  /** The newest value not saved yet. */
  let wanted: FlareNotificationAlertPreferences | null = null;
  /** A save is on its way. */
  let saving = false;
  let reads = 0;
  /** Raised when the component goes: late answers are dropped. */
  let generation = 0;
  onScopeDispose(() => {
    generation += 1;
  });

  function show(settings: UserNotificationSettings): void {
    preferences.value = alertPreferencesFromSettings(settings, preferences.value);
  }

  /** Reads the settings. Not while a save is on its way: its answer is newer, and an older read never wins. */
  async function load(): Promise<void> {
    if (saving) return;
    const read = ++reads;
    const started = generation;
    loadFailed.value = false;
    try {
      const settings = await client.notification.getSettings();
      if (read !== reads || started !== generation || saving) return;
      if (stored && settingsVersionOf(settings) < settingsVersionOf(stored)) return;
      stored = settings;
      show(settings);
    } catch (error) {
      if (read !== reads || started !== generation) return;
      console.warn("[notification settings] read failed", error);
      loadFailed.value = preferences.value === null;
    }
  }

  /** The page changed a row: show it, then save it. Nothing is taken before the settings were read. */
  function change(next: FlareNotificationAlertPreferences): void {
    if (!stored) return;
    preferences.value = next;
    wanted = next;
    if (saving) return;
    saving = true;
    const started = generation;
    void save(started).finally(() => {
      if (started === generation) saving = false;
    });
  }

  async function save(started: number): Promise<void> {
    while (started === generation) {
      const base = stored;
      const target = wanted;
      if (!base || !target) return;
      const request = settingsUpdateFor(base, target);
      if (!request) {
        wanted = null;
        return;
      }
      let saved: UserNotificationSettings | null = null;
      try {
        saved = await client.notification.updateSettings(request);
      } catch (error) {
        console.warn("[notification settings] update failed", error);
      }
      if (started !== generation) return;
      if (saved) {
        stored = saved;
        // A newer change came in meanwhile: save it on top of this answer.
        if (wanted !== target) continue;
        wanted = null;
        show(saved);
        return;
      }
      // Back to the core's value as it is now; a row changed while reading it is saved on the version read.
      wanted = null;
      try {
        const current = await client.notification.getSettings();
        if (started === generation) stored = current;
      } catch (error) {
        console.warn("[notification settings] read after a failed update failed", error);
      }
      if (started !== generation) return;
      onSaveFailed();
      if (wanted === null) {
        if (stored) show(stored);
        return;
      }
    }
  }

  return { preferences, loadFailed, load, change };
}
