import { computed, ref, shallowRef, watch, type ComputedRef, type Ref, type ShallowRef } from "vue";
import type { FlarePluginUpgradeStatus } from "@flare-im/vue-ui";
import type { CorePluginHost } from "./context";

/** What a view says about upgrading: only `upgrade_required` asks, with the plugin's floor when it names one. */
export interface CorePluginUpgradeSubject {
  unavailableReason?: string;
  minBuild?: number;
}

/** The key that decides whether to ask again: null when the view needs no update, the floor (or "") otherwise. */
export function corePluginUpgradeKey(view: CorePluginUpgradeSubject | null | undefined): string | null {
  if (view?.unavailableReason !== "upgrade_required") return null;
  return typeof view.minBuild === "number" ? String(view.minBuild) : "";
}

/**
 * An upgrade notice's host side (D-18): asks `upgradeStatus` for the view's `minBuild` whenever the view turns into an
 * upgrade placeholder, and opens the update flow on the notice's key, `busy` while it opens. A failed status read
 * leaves `status` null, so the notice shows its description without a key.
 */
export function useCorePluginUpgrade(view: () => CorePluginUpgradeSubject | null | undefined, host: () => CorePluginHost | undefined): {
  status: ShallowRef<FlarePluginUpgradeStatus | null>;
  busy: Ref<boolean>;
  update: ComputedRef<(() => void) | undefined>;
} {
  const status = shallowRef<FlarePluginUpgradeStatus | null>(null);
  const busy = ref(false);
  let ticket = 0;
  watch(() => corePluginUpgradeKey(view()), async (key) => {
    const mine = ++ticket;
    status.value = null;
    const ask = host()?.upgradeStatus;
    if (key === null || !ask) return;
    try {
      const answer = await ask(key === "" ? undefined : Number(key));
      if (mine === ticket) status.value = answer;
    } catch { /* No answer: the notice keeps its description. */ }
  }, { immediate: true });
  async function open(): Promise<void> {
    const run = host()?.openUpdate;
    if (!run || busy.value) return;
    busy.value = true;
    try { await run(); } catch { /* The update center reports its own failures. */ } finally { busy.value = false; }
  }
  const update = computed(() => (host()?.openUpdate ? () => { void open(); } : undefined));
  return { status, busy, update };
}
