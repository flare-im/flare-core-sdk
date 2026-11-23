<script setup lang="ts">
/**
 * The plugin capabilities the viewer allowed "always" on this device (`capability.plugin_capability_consents`), as kit
 * settings rows: the plugin, then what it may use. Selecting a row asks to take it back (the kit's confirm); once
 * confirmed the consent is revoked (`capability.plugin_capability_consent_revoke`) and the plugin asks again next time.
 */
import { computed, onBeforeUnmount, ref, shallowRef, watch } from "vue";
import {
  FlareEmptyState,
  FlareSettingsList,
  FlareStatusBanner,
  flareCapabilityLabelKey,
  useFlareConfirm,
  useFlareI18n,
  type FlareSettingsItem,
  type FlareSettingsSection,
} from "@flare-im/vue-ui";

/** The consent calls of the social SDK's `plugins`. */
export interface CorePluginConsentPort {
  capabilityConsents(request?: { pluginId?: string }): Promise<Record<string, unknown>>;
  revokeCapabilityConsent(request: { pluginId: string; capability?: string }): Promise<Record<string, unknown>>;
}
interface Consent { pluginId: string; capability: string; level: number }

const props = defineProps<{
  port: CorePluginConsentPort | null;
  /** The plugin's name as the host knows it; the plugin id otherwise. */
  pluginName?: (pluginId: string) => string | undefined;
  /** The host's copy. */
  texts: { empty: string; revokeTitle: string; revokeDescription: string; revoke: string; failed: string; revokeFailed?: string };
}>();

const { t } = useFlareI18n();
const confirm = useFlareConfirm();
const consents = shallowRef<Consent[]>([]);
const loaded = ref(false);
const error = ref("");
const loading = ref(true);
let generation = 0;
let disposed = false;
onBeforeUnmount(() => { disposed = true; generation += 1; });

function read(value: unknown): Consent[] {
  const list = (value as { consents?: unknown } | null)?.consents;
  return Array.isArray(list) ? list.flatMap((entry) => {
    const c = entry as { pluginId?: unknown; capability?: unknown; level?: unknown };
    return typeof c.pluginId === "string" && typeof c.capability === "string"
      ? [{ pluginId: c.pluginId, capability: c.capability, level: typeof c.level === "number" ? c.level : 0 }] : [];
  }) : [];
}
async function load(): Promise<void> {
  const mine = ++generation;
  const port = props.port;
  error.value = "";
  loading.value = true;
  if (!port) return;
  try {
    const result = await port.capabilityConsents({});
    if (!disposed && mine === generation) consents.value = read(result);
  } catch {
    if (!disposed && mine === generation) error.value = props.texts.failed;
  } finally {
    if (!disposed && mine === generation) { loaded.value = true; loading.value = false; }
  }
}
watch(() => props.port, () => { consents.value = []; loaded.value = false; void load(); }, { immediate: true });

const key = (c: Consent) => `${c.pluginId}\u0000${c.capability}`;
/** What it may use: the kit's capability line (a level-1 location is the fine one). */
function capabilityText(c: Consent): string {
  const params = c.capability === "locationOnce" ? { precision: c.level >= 1 ? "fine" : "coarse" } : null;
  return t(`capability.label.${flareCapabilityLabelKey(c.capability, params)}`);
}
const sections = computed<FlareSettingsSection[]>(() => [{
  items: consents.value.map((c): FlareSettingsItem => ({
    key: key(c), label: props.pluginName?.(c.pluginId) ?? c.pluginId, detail: capabilityText(c), kind: "navigation", disabled: loading.value,
  })),
}]);
async function select(item: FlareSettingsItem): Promise<void> {
  const consent = consents.value.find((c) => key(c) === item.key);
  const port = props.port;
  if (!consent || !port || loading.value) return;
  await confirm({
    title: props.texts.revokeTitle,
    description: props.texts.revokeDescription,
    target: `${props.pluginName?.(consent.pluginId) ?? consent.pluginId} · ${capabilityText(consent)}`,
    confirmText: props.texts.revoke,
    action: async () => {
      if (disposed || port !== props.port) throw new Error(props.texts.revokeFailed ?? props.texts.failed);
      try {
        await port.revokeCapabilityConsent({ pluginId: consent.pluginId, capability: consent.capability });
      } catch {
        // The shared confirmation keeps a rejected action open, with retry/cancel.
        // Do not refresh away the error or disclose the transport diagnostic.
        throw new Error(props.texts.revokeFailed ?? props.texts.failed);
      }
      if (disposed || port !== props.port) return;
      consents.value = consents.value.filter(entry => key(entry) !== key(consent));
      await load();
    },
  });
}
</script>

<template>
  <div class="core-plugin-consents" :aria-busy="loading">
    <FlareStatusBanner v-if="error" :text="error" tone="danger" :action-text="t('common.retry')" @action="load" />
    <FlareEmptyState v-if="loading && !consents.length" loading :title="t('common.loading')" />
    <FlareEmptyState v-else-if="loaded && !consents.length && !error" icon="lock" :title="texts.empty" />
    <FlareSettingsList v-else-if="consents.length" :sections="sections" @select="select" />
  </div>
</template>

<style scoped>
.core-plugin-consents { display: flex; flex-direction: column; gap: var(--flare-size-spacing-md); }
</style>
