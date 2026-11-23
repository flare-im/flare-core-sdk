<script setup lang="ts">
import { computed, onMounted, onScopeDispose, ref } from "vue";
import { FlareScanHitGate, FlareScanViewfinder } from "@flare-im/scan-kit";
import { createBrowserScanCapture, createScanImageDecoder } from "@flare-im/scan-kit/composables";
import type { CorePluginCapabilityResult } from "./capabilityRequests";

const emit = defineEmits<{ answer: [value: CorePluginCapabilityResult] }>();
const video = ref<HTMLVideoElement | null>(null);
const photo = ref<HTMLInputElement | null>(null);
const decoder = createScanImageDecoder();
const hitGate = new FlareScanHitGate();
let finished = false;
let reading = false;

const capture = createBrowserScanCapture({
  video,
  decoder,
  onFrame(frame) {
    const hit = hitGate.observe(frame);
    if (hit.kind === "lock" && hit.ready) finish({ text: hit.code.raw });
  },
});
const capabilities = computed(() => ({
  live: true, album: true, paste: false, myCode: false, torch: capture.torchAvailable.value,
}));

function finish(result: CorePluginCapabilityResult): void {
  if (finished) return;
  finished = true;
  capture.stop();
  decoder.dispose();
  emit("answer", result);
}
async function decodePhoto(event: Event): Promise<void> {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = "";
  if (!file || finished || reading) return;
  if (file.size > 10 * 1024 * 1024) {
    capture.state.value = "imageError";
    return;
  }
  reading = true;
  capture.state.value = "imageDecoding";
  try {
    const codes = await capture.decodeImage(file, () => !finished);
    if (finished) return;
    if (codes.length === 1) finish({ text: codes[0].raw });
    else capture.state.value = "noCodeInImage";
  } catch {
    if (!finished) capture.state.value = "imageError";
  } finally {
    reading = false;
  }
}

onMounted(() => { void capture.start(); });
onScopeDispose(() => {
  finished = true;
  capture.stop();
  decoder.dispose();
});
</script>

<template>
  <div class="plugin-qr-surface">
    <FlareScanViewfinder
      :state="capture.state.value"
      :capabilities="capabilities"
      :torch="capture.torch.value"
      @close="finish({ cancelled: true })"
      @retry="capture.start"
      @request-permission="capture.start"
      @toggle-torch="capture.toggleTorch"
      @pick-image="photo?.click()"
    >
      <template #preview>
        <video ref="video" autoplay muted playsinline />
      </template>
    </FlareScanViewfinder>
    <input ref="photo" type="file" accept="image/*" hidden @change="decodePhoto" />
  </div>
</template>

<style scoped>
.plugin-qr-surface { height: min(58dvh, 520px); }
</style>
