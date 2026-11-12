<script setup lang="ts">
import { watch } from "vue";
import { useRouter } from "vue-router";
import { FlareUiProvider } from "@flare-im/vue-ui/components";
import {
  createAppMediaResolver,
  provideFlareSdk,
} from "@flare-im/vue-ui/app";
import { useElectronNotifications } from "./notifications";

const sdk = provideFlareSdk();
const mediaResolver = createAppMediaResolver(sdk);
useElectronNotifications(sdk);
const router = useRouter();

watch(
  () => sdk.loggedIn.value,
  (loggedIn) => {
    if (!loggedIn && router.currentRoute.value.name !== "login") {
      void router.replace({ name: "login" });
    }
  },
);
</script>

<template>
  <FlareUiProvider layout-mode="auto" :media-resolver="mediaResolver">
    <router-view />
  </FlareUiProvider>
</template>
