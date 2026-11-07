<script setup lang="ts">
// The update prompt: its form, words and buttons are the kit's, here are only the status and the actions. Without a
// fallback address `fallback` stays unbound, and the kit then draws no such button.
import { watch } from "vue";
import { FlareUpdatePrompt } from "@flare-im/vue-ui/components";
import { useFlareI18n } from "../shared/i18n";
import { useFlareUpdates } from "../state/update";

const updates = useFlareUpdates();
const { promptView, fallbackUrl } = updates;
const { locale } = useFlareI18n();

// Release notes and the block reason follow the app's language: at start, and when it changes.
watch(locale, (next) => updates.setLocale(next), { immediate: true });

// Only a prompt really on screen counts: the frequency rules depend on it.
watch(() => promptView.value?.form, (form) => {
  if (form) updates.markPrompted(form);
}, { flush: "post", immediate: true });
</script>

<template>
  <FlareUpdatePrompt
    v-if="promptView"
    open
    v-bind="promptView"
    @update="updates.update"
    @later="updates.later"
    @skip="updates.skip"
    @retry="updates.update"
    @continue-read-only="updates.continueReadOnly"
    v-on="fallbackUrl ? { fallback: updates.openFallback } : {}"
  />
</template>
