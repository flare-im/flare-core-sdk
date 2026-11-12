<script setup lang="ts">
// The upgrade notice of a "+" or 我 entry this build cannot draw (D-18): the kit's page notice in a bottom sheet. It
// asks the provided host (`CorePluginHost`) whether this device is offered the build the entry needs, and its key
// opens the update flow, which the app's update prompt draws.
import { computed, inject } from "vue";
import { FlareBottomSheet, FlarePluginUpgradeNotice } from "@flare-im/vue-ui";
import { pluginUiHostKey, type CorePluginHost } from "./context";
import { useCorePluginUpgrade } from "./upgrade";

const props = defineProps<{
  /** The tapped entry; the sheet is open while there is one. */
  entry: { title: string; upgrade?: { minBuild?: number } } | null;
  /** Defaults to the one provided above (`provideCorePluginHost`). */
  host?: CorePluginHost;
}>();
const emit = defineEmits<{ close: [] }>();
const provided = inject(pluginUiHostKey, undefined);
const host = (): CorePluginHost => props.host ?? provided ?? {};
const subject = computed(() => (props.entry
  ? { unavailableReason: "upgrade_required", ...(props.entry.upgrade?.minBuild ? { minBuild: props.entry.upgrade.minBuild } : {}) }
  : undefined));
const upgrade = useCorePluginUpgrade(() => subject.value, host);
</script>

<template>
  <FlareBottomSheet :open="Boolean(entry)" :title="entry?.title ?? ''" @close="emit('close')">
    <FlarePluginUpgradeNotice
      v-if="entry"
      variant="page"
      :title="entry.title"
      :status="upgrade.status.value"
      :on-update="upgrade.update.value"
      :busy="upgrade.busy.value"
    />
  </FlareBottomSheet>
</template>
