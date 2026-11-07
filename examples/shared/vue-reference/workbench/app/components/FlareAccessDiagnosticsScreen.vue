<script setup lang="ts">
// Network and lines: the settings sheet's entry and the connection notice's "diagnose" both land here. The page body
// is the kit's FlareAccessDiagnostics; the reads and calls are in state/accessDiagnostics.ts.
import { onBeforeUnmount, onMounted, watch } from "vue";
import { useRouter } from "vue-router";
import { FlareAccessDiagnostics, FlareScreen } from "@flare-im/vue-ui/components";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { useFlareI18n } from "../shared/i18n";
import { createAccessDiagnostics, pendingRecoveryLink } from "../state/accessDiagnostics";
import { useToast } from "../ui/toast";

const sdk = useFlareSdk();
const router = useRouter();
const message = useToast();
const { t } = useFlareI18n();
const {
  status,
  accessPoints,
  refreshing,
  refreshOutcome,
  importing,
  importResult,
  exporting,
  exportOutcome,
  pin,
  unpin,
  refresh,
  importRecovery,
  exportDiagnostics,
  follow,
} = createAccessDiagnostics({
  client: sdk.client,
  onPinFailed: () => message.error(t("workbench.accessPinFailed")),
});

// A link the system delivered is imported here, so its outcome is said here.
watch(pendingRecoveryLink, (link) => {
  if (!link) return;
  pendingRecoveryLink.value = null;
  void importRecovery(link);
}, { immediate: true });

let stopFollowing: (() => void) | undefined;
onMounted(() => {
  stopFollowing = follow();
});
onBeforeUnmount(() => stopFollowing?.());

/** Back to where the page was opened from; a page reloaded on this route has nowhere to go back to. */
function leave(): void {
  if (window.history.state?.back) router.back();
  else void router.replace({ name: "conversations" });
}
</script>

<template>
  <FlareScreen :title="t('accessDiagnostics.title')" back surface="canvas" readable padded class="access-diagnostics-screen" @back="leave">
    <FlareAccessDiagnostics
      :status="status"
      :access-points="accessPoints"
      :refreshing="refreshing"
      :refresh-outcome="refreshOutcome"
      :importing="importing"
      :import-outcome="importResult?.outcome"
      :import-code="importResult?.code"
      :exporting="exporting"
      :export-outcome="exportOutcome"
      @pin="pin"
      @unpin="unpin"
      @refresh="refresh"
      @import-recovery="importRecovery"
      @export-diagnostics="exportDiagnostics"
    />
  </FlareScreen>
</template>

<style scoped>
.access-diagnostics-screen {
  height: 100%;
  min-height: 0;
}
</style>
