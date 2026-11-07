<script setup lang="ts">
import { computed, onMounted, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { FlareConnectionNotice, FlareUiProvider } from "@flare-im/vue-ui/components";
import {
  FlareUpdatePromptHost,
  appPlatformOptions,
  createAppMediaResolver,
  pendingRecoveryLink,
  productionAppHost,
  provideFlareSdk,
  provideFlareUpdates,
} from "./workbench/app";
import ToastHost from "./workbench/app/components/ToastHost.vue";

const sdk = provideFlareSdk();
const updates = provideFlareUpdates(sdk.client);
const mediaResolver = createAppMediaResolver(sdk);
const platform = appPlatformOptions();
const router = useRouter();
const route = useRoute();
/** The diagnostics page says all the notice would, and the notice would hang over its header. */
const noticeHidden = computed(() => route.name === "network");
// The notice draws "update" only while someone listens: a host without an update center gets no button.
const updateListener = updates.available ? { update: updates.update } : {};

watch(sdk.loggedIn, (loggedIn) => {
  if (!loggedIn && router.currentRoute.value.name !== "login") {
    void router.replace({ name: "login" });
  }
});

// A saved session skips the sign-in page, which otherwise starts the update center.
watch(sdk.loggedIn, (loggedIn) => {
  if (loggedIn) void updates.start();
  else updates.restart();
}, { immediate: true });

// The system delivered a recovery link. The page importing it needs the initialized SDK, so a link arriving before
// sign-in waits for it.
watch([pendingRecoveryLink, sdk.loggedIn], ([link, loggedIn]) => {
  if (link && loggedIn) void router.push({ name: "network" });
}, { immediate: true });
onMounted(() => {
  void productionAppHost().followRecoveryLinks?.((link) => {
    pendingRecoveryLink.value = link;
  }).catch((error: unknown) => console.warn("[access] following recovery links failed", error));
});
</script>

<template>
  <FlareUiProvider layout-mode="auto" :media-resolver="mediaResolver" :platform="platform">
    <!-- The one connection notice, above every route and always mounted: when it shows and for how long is the
         kit's call from the status timeline, and unmounting would lose its timing. -->
    <div v-show="!noticeHidden" class="reference-app__notices">
      <FlareConnectionNotice
        :status="sdk.connectionStatus.value"
        floating
        @retry="sdk.reconnectNow"
        @sign-in="sdk.signInAgain"
        @diagnose="router.push({ name: 'network' })"
        v-on="updateListener"
      />
    </div>
    <router-view />
    <FlareUpdatePromptHost />
    <ToastHost />
  </FlareUiProvider>
</template>

<style scoped>
/* The notice hangs over the routes without taking layout space: below a page header (one touch target plus a
   small spacing above and below, the kit's header geometry), centred and no wider than the small breakpoint so it
   never covers the side navigation on a wide window. Only the banner itself takes pointer events. */
.reference-app__notices {
  position: fixed;
  z-index: var(--flare-z-index-overlay);
  top: calc(env(safe-area-inset-top, 0px) + var(--flare-size-layout-touch-target) + var(--flare-size-spacing-sm) * 2);
  left: 0;
  right: 0;
  max-width: var(--flare-breakpoint-sm);
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0 var(--flare-size-spacing-md);
  pointer-events: none;
}
.reference-app__notices > * {
  pointer-events: auto;
}
</style>
