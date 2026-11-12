<script setup lang="ts">
/**
 * The plugin capabilities the viewer allowed "always" on this device (`capability.plugin_capability_consents`), as kit
 * settings rows: the plugin, then what it may use. Selecting a row asks to take it back (the kit's confirm); once
 * confirmed the consent is revoked (`capability.plugin_capability_consent_revoke`) and the plugin asks again next time.
 */
import { computed, onMounted, ref, shallowRef } from "vue";
import {
  FlareEmptyState,
  FlareSettingsList,
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
  texts: { empty: string; revokeTitle: string; revokeDescription: string; revoke: string; failed: string };
}>();

const { t } = useFlareI18n();
const confirm = useFlareConfirm();
const consents = shallowRef<Consent[]>([]);
const loaded = ref(false);
const error = ref("");

function read(value: unknown): Consent[] {
  const list = (value as { consents?: unknown } | null)?.consents;
  return Array.isArray(list) ? list.flatMap((entry) => {
    const c = entry as { pluginId?: unknown; capability?: unknown; level?: unknown };
    return typeof c.pluginId === "string" && typeof c.capability === "string"
      ? [{ pluginId: c.pluginId, capability: c.capability, level: typeof c.level === "number" ? c.level : 0 }] : [];
  }) : [];
}
async function load(): Promise<void> {
  if (!props.port) return;
  error.value = "";
  try { consents.value = read(await props.port.capabilityConsents({})); } catch { error.value = props.texts.failed; }
  loaded.value = true;
}
onMounted(load);

const key = (c: Consent) => `${c.pluginId}\u0000${c.capability}`;
/** What it may use: the kit's capability line (a level-1 location is the fine one). */
function capabilityText(c: Consent): string {
  const params = c.capability === "locationOnce" ? { precision: c.level >= 1 ? "fine" : "coarse" } : null;
  return t(`capability.label.${flareCapabilityLabelKey(c.capability, params)}`);
}
const sections = computed<FlareSettingsSection[]>(() => [{
  items: consents.value.map((c): FlareSettingsItem => ({
    key: key(c), label: props.pluginName?.(c.pluginId) ?? c.pluginId, detail: capabilityText(c), kind: "navigation",
  })),
}]);
async function select(item: FlareSettingsItem): Promise<void> {
  const consent = consents.value.find((c) => key(c) === item.key);
  const port = props.port;
  if (!consent || !port) return;
  await confirm({
    title: props.texts.revokeTitle,
    description: props.texts.revokeDescription,
    target: `${props.pluginName?.(consent.pluginId) ?? consent.pluginId} · ${capabilityText(consent)}`,
    confirmText: props.texts.revoke,
    action: async () => {
      try {
        await port.revokeCapabilityConsent({ pluginId: consent.pluginId, capability: consent.capability });
      } catch {
        error.value = props.texts.failed;
      }
      await load();
    },
  });
}
</script>

<template>
  <div class="core-plugin-consents">
    <p v-if="error" class="core-plugin-consents__error" role="alert">{{ error }}</p>
    <FlareEmptyState v-if="loaded && !consents.length && !error" icon="lock" :title="texts.empty" />
    <FlareSettingsList v-else-if="consents.length" :sections="sections" @select="select" />
  </div>
</template>

<style scoped>
.core-plugin-consents { display: flex; flex-direction: column; gap: var(--flare-size-spacing-md); }
.core-plugin-consents__error { margin: 0; color: var(--flare-color-error-text); font-size: var(--flare-size-font-size-md); }
</style>
