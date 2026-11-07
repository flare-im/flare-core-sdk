<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { useToast } from "../ui/toast";
import { FlareEmptyState, FlareScreen, FlareStatusBanner } from "@flare-im/vue-ui/components";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { useFlareI18n } from "../shared/i18n";
const { t } = useFlareI18n();

const sdk = useFlareSdk();
const router = useRouter();
const message = useToast();
const running = ref(false);

const progress = computed(() => sdk.homeSyncProgress.value);
const percent = computed(() => Math.max(0, Math.min(100, progress.value.percent)));
const failed = computed(() => progress.value.step === "failed");
const done = computed(() => progress.value.step === "ready");
const statusType = computed(() => {
  if (failed.value) return "danger";
  if (done.value) return "success";
  return "info";
});

async function runSync(): Promise<void> {
  if (running.value) return;
  running.value = true;
  try {
    await sdk.syncHomeBeforeEnter();
    await router.replace({ name: "conversations" });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || t("workbench.homeSyncFailed"));
  } finally {
    running.value = false;
  }
}

onMounted(() => {
  void runSync();
});
</script>

<template>
  <main class="sync-route">
    <FlareScreen surface="canvas" padded>
      <FlareEmptyState
        :title="progress.title"
        :description="`${progress.detail} · ${percent}%`"
        :loading="running && !failed && !done"
        :tone="failed ? 'error' : 'normal'"
        :icon="done ? 'check' : 'chat'"
      >
        <template v-if="failed" #actions>
          <FlareStatusBanner
            :text="t('sync.failedTitle')"
            tone="danger"
            :action-text="running ? undefined : t('common.retry')"
            @action="runSync"
          />
        </template>
      </FlareEmptyState>
      <FlareStatusBanner
        :tone="statusType"
        :text="`${t('workbench.conversationsLabel')}: ${sdk.conversations.value.length} · ${t('workbench.unreadLabel')}: ${sdk.totalUnread.value} · ${t('workbench.connectionState')}: ${sdk.connectionPhase.value}`"
      />
    </FlareScreen>
  </main>
</template>

<style scoped>
/* Root viewport only; progress, retry and status surfaces belong to the kit. */
.sync-route { height: 100dvh; min-height: 0; }
</style>
