<script setup lang="ts">
// Version information: the settings sheet's entry lands here. The page body is the kit's FlareVersionPanel; a manual
// check that failed opens no prompt, so this page says it.
import { useRouter } from "vue-router";
import { FlareScreen, FlareStatusBanner, FlareVersionPanel } from "@flare-im/vue-ui/components";
import { webAppInfoFromBuild } from "@flare-im/sdk/lifecycle";
import { useFlareI18n } from "../shared/i18n";
import { useFlareUpdates } from "../state/update";

const router = useRouter();
const { t } = useFlareI18n();
const updates = useFlareUpdates();
const { status, checkFailure } = updates;
/** Before the first read of the state the build's own version is all there is. */
const built = webAppInfoFromBuild();

/** Back to where the page was opened from; a page reloaded on this route has nowhere to go back to. */
function leave(): void {
  if (window.history.state?.back) router.back();
  else void router.replace({ name: "conversations" });
}
</script>

<template>
  <FlareScreen :title="t('versionPanel.title')" back surface="canvas" readable padded class="about-screen" @back="leave">
    <div class="about-screen__body">
      <FlareStatusBanner v-if="checkFailure" :text="t(checkFailure)" tone="warning" />
      <FlareVersionPanel
        :version="status?.current.version ?? built.version ?? ''"
        :build="status?.current.build ?? built.build"
        :channel="status?.current.channel ?? built.channel"
        :update-state="status?.state"
        @check="updates.check"
        @update="updates.update"
      />
    </div>
  </FlareScreen>
</template>

<style scoped>
.about-screen {
  height: 100%;
  min-height: 0;
}
.about-screen__body {
  display: flex;
  flex-direction: column;
  gap: var(--flare-size-spacing-sm);
}
</style>
