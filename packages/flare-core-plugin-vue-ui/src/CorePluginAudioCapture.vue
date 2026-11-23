<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from "vue";
import { FlareButton } from "@flare-im/vue-ui";
import { formatVoiceDuration, useFlareVoiceRecorderAdapter, useVoiceRecorder } from "@flare-im/vue-ui/composables";
import { useFlareI18n } from "@flare-im/vue-ui/i18n";
import { corePluginCapabilityFile, type CorePluginCapabilityResult } from "./capabilityRequests";

const props = defineProps<{ accept: string[]; maxBytes: number }>();
const emit = defineEmits<{ answer: [value: CorePluginCapabilityResult] }>();
const { t, locale } = useFlareI18n();
const busy = ref(false);
const incompatible = ref(false);
const recorder = useVoiceRecorder({
  adapter: useFlareVoiceRecorderAdapter(),
  onError: () => emit("answer", { unavailable: true }),
});
const { requestPending, recording, preview, previewUrl, atLimit, elapsedMs } = recorder;

function visibilityChanged(): void {
  if (document.hidden && recorder.cancel()) emit("answer", { cancelled: true });
}
onMounted(() => document.addEventListener("visibilitychange", visibilityChanged));
onBeforeUnmount(() => document.removeEventListener("visibilitychange", visibilityChanged));
watch(atLimit, (reached) => { if (reached) void recorder.finalize(); });

async function useRecording(): Promise<void> {
  const clip = preview.value;
  if (!clip || busy.value) return;
  busy.value = true;
  try {
    const type = clip.mimeType.split(";", 1)[0].toLowerCase();
    const file = new File([clip.blob], clip.fileName, { type });
    const value = await corePluginCapabilityFile(file, props.accept, props.maxBytes);
    if (value) emit("answer", { file: value });
    else incompatible.value = true;
  } catch {
    emit("answer", { unavailable: true });
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="plugin-recording" :aria-label="t('composer.voice')">
    <time v-if="recording">{{ formatVoiceDuration(elapsedMs) }}</time>
    <audio v-if="previewUrl" :src="previewUrl" controls :aria-label="t('composer.previewRecording')" />
    <p v-if="incompatible" role="status">
      {{ locale.startsWith("zh") ? "录音格式或大小超出此字段的要求。" : "This field cannot accept the recording format or size." }}
    </p>
    <div class="plugin-recording-actions">
      <FlareButton v-if="recording" :label="locale.startsWith('zh') ? '结束录音' : 'Stop recording'" @click="recorder.finalize" />
      <template v-else-if="preview">
        <FlareButton :label="t('composer.discardRecording')" :disabled="busy" @click="recorder.cancel(); incompatible = false" />
        <FlareButton :label="locale.startsWith('zh') ? '使用录音' : 'Use recording'" :disabled="busy || incompatible" @click="useRecording" />
      </template>
      <FlareButton v-else :label="t(requestPending ? 'composer.requestingMicrophone' : 'composer.startRecording')"
        :disabled="requestPending" @click="recorder.start" />
    </div>
  </div>
</template>

<style scoped>
.plugin-recording { display: grid; gap: 12px; min-width: 0; }
.plugin-recording audio { width: 100%; }
.plugin-recording-actions { display: flex; flex-wrap: wrap; gap: 8px; }
</style>
