<script setup lang="ts">
import { computed, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useToast } from "../ui/toast";
import { FlareStatusBanner } from "@flare-im/vue-ui/components";
import { AuthScreen } from "../ui/components";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { useFlareI18n } from "../shared/i18n";
import { useFlareUpdates } from "../state/update";

const sdk = useFlareSdk();
const updates = useFlareUpdates();
const router = useRouter();
const message = useToast();
const { t } = useFlareI18n();

const sessionSummary = computed(() => ({
  userId: sdk.currentUserId.value || sdk.form.userId,
  sessionActive: sdk.sessionActive.value,
  isConnected: sdk.isConnected.value,
  connectionPhase: sdk.connectionPhase.value,
  runtime: sdk.sdkRuntimeStatus.value,
}));

const runtimeUnavailable = computed(
  () => sdk.sdkRuntimeStatus.value === "browser-unavailable" && !sdk.loggedIn.value,
);

// A forced update has to reach this page, and nobody here has to sign in for the core to tell.
onMounted(() => {
  void sdk.initBeforeSignIn().then((ready) => (ready ? updates.start() : undefined));
});

async function login(): Promise<void> {
  try {
    await sdk.initializeAndLogin();
    await router.replace({ name: "sync" });
  } catch (error) {
    // A build the server refuses has no session and so no event: the prompt needs this read.
    updates.refresh();
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || t("login.failed"));
  }
}

</script>

<template>
  <div class="auth-route">
    <!-- Where this build connects is set when it is built; without it there is nothing to sign in to. -->
    <FlareStatusBanner
      v-if="sdk.accessConfigError.value"
      tone="danger"
      :text="`${t('login.accessConfigMissing')}: ${sdk.accessConfigError.value}`"
    />
    <FlareStatusBanner v-else-if="runtimeUnavailable" tone="danger" :text="`${t('login.runtimeUnavailable')}: ${t('login.runtimeUnavailableHint')}`" />
    <AuthScreen
      v-model:user-id="sdk.form.userId"
      :loading="sdk.busy.value"
      :disabled="Boolean(sdk.accessConfigError.value)"
      @login="login"
    />
    <section v-if="sdk.initialized.value || sdk.events.value.length" class="auth-session-strip">
      <FlareStatusBanner
        :tone="sessionSummary.isConnected ? 'success' : 'warning'"
        :text="`${sessionSummary.sessionActive ? t('login.sessionActive') : t('login.sessionInactive')} · ${sessionSummary.isConnected ? t('login.connected') : t('login.disconnected')} · ${sessionSummary.userId} · ${sessionSummary.connectionPhase} · runtime=${sessionSummary.runtime}`"
      />
    </section>
  </div>
</template>

<style scoped>
.auth-route {
  min-height: 100%;
}
</style>
