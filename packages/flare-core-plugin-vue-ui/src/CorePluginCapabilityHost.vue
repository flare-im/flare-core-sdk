<script setup lang="ts">
/**
 * The host's part of plugin capabilities for browser and webview hosts (Web, Tauri): the engine asks
 * (`im://plugin_capability_request`), this draws the kit's screen and answers once (`plugin.capability_complete`).
 * Mount it once for as long as the user is signed in; requests are answered one at a time, in order.
 *
 * - consent: `FlareCapabilityConsent`; the answer is the viewer's decision as it is (`once`, `always`, `deny`). The
 *   engine keeps only "always"; "once" lets this one request through. Dismissing is a refusal.
 * - captureDocument: `FlareDocumentCapture` over the camera (`getUserMedia`, the back camera when there is one) and the
 *   file picker; the kit frames, compresses and strips the photo, the engine uploads it.
 * - pickFile: the file picker, checked against the request's `accept` and `maxBytes`.
 * - confirmPayment: `FlarePaymentConfirmation` with the payment password in its credential slot; the answer is
 *   `{confirmation: {method: "paymentPassword", password}}`, which the plugin's server verifies against its own
 *   credential store (the wallet's payment password). The password lives only in this sheet.
 * - locateOnce: one fix from `navigator.geolocation` (the consent prompt came first; the browser asks its own).
 * Anything else, or a host that cannot, answers `{unavailable: true}`.
 */
import { computed, onBeforeUnmount, ref, shallowRef, useSlots, watch } from "vue";
import {
  FlareCapabilityConsent,
  FlareBottomSheet,
  FlareButton,
  FlareDocumentCapture,
  FlareInput,
  FlarePaymentConfirmation,
  flareCapabilityConsentAnswer,
  type FlareCapabilityConsentDecision,
  type FlareCapturedDocument,
  type FlareDocumentSide,
  type FlarePaymentOrder,
} from "@flare-im/vue-ui";
import {
  browserLocateOnce,
  browserPickFile,
  corePluginCapabilityFile,
  corePluginCapabilityMethodKnown,
  type CorePluginCapabilityRequestFeed,
  type CorePluginCapabilityResult,
} from "./capabilityRequests";

const props = defineProps<{
  /** The requests the host forwards (`createCorePluginCapabilityRequestFeed().requests`). */
  requests: CorePluginCapabilityRequestFeed;
  /** `plugin.capability_complete` (the core SDK's `completePluginCapabilityRequest`). */
  complete: (requestId: number, result: CorePluginCapabilityResult) => Promise<void>;
  /** The plugin's name as the catalog gives it; the plugin id while unknown. */
  pluginName?: (pluginId: string) => string | undefined | Promise<string | undefined>;
  /** The label and placeholder of the payment password in the confirmation sheet (the host's copy). */
  paymentPasswordLabel: string;
  /** One fix at the precision asked; defaults to the browser's location API. */
  locate?: (precision: "coarse" | "fine") => Promise<{ latitude: number; longitude: number; accuracyM?: number } | null>;
  /** The file picker; defaults to the browser's. */
  pickFile?: (accept: readonly string[], capability: string) => Promise<Blob | null>;
  deviceLabels?: { camera: string; image: string; file: string; unavailable: string };
}>();
const slots = useSlots();

type Pending = { requestId: number; method: string; request: Record<string, unknown> };
const queue = shallowRef<Pending[]>([]);
const current = computed(() => queue.value[0]);
const name = ref("");
const busy = ref(false);
let disposed = false;

const stop = props.requests((request) => {
  queue.value = [...queue.value, request];
});
onBeforeUnmount(() => {
  disposed = true;
  stop();
  stopCamera();
  password.value = "";
  // Nothing on screen answers what is still waiting: tell the engine now rather than in ten minutes.
  for (const pending of queue.value) void props.complete(pending.requestId, { unavailable: true }).catch(() => undefined);
  queue.value = [];
});

/** Answers the head request once and moves on. A late answer (the engine gave up) is dropped quietly. */
async function answer(result: CorePluginCapabilityResult): Promise<void> {
  const head = current.value;
  if (!head) return;
  queue.value = queue.value.slice(1);
  busy.value = false;
  try { await props.complete(head.requestId, result); } catch { /* No longer waiting. */ }
}

const text = (value: unknown) => (typeof value === "string" ? value : "");
const list = (value: unknown) => (Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : []);
const bytesLimit = (value: unknown) => (typeof value === "number" && Number.isSafeInteger(value) && value > 0 ? value : 0);

// Each new head request: its plugin's name, then whatever needs no screen runs at once.
watch(current, async (head) => {
  stopCamera();
  password.value = "";
  if (!head) return;
  const pluginId = text(head.request.pluginId);
  name.value = pluginId;
  void Promise.resolve(props.pluginName?.(pluginId)).then((resolved) => {
    if (current.value === head && resolved) name.value = resolved;
  }).catch(() => undefined);
  if (!corePluginCapabilityMethodKnown(head.method)) { await answer({ unavailable: true }); return; }
  if (head.method === "scanCode" && !slots.scan) await answer({ unavailable: true });
  else if (head.method === "locateOnce") await runLocate(head);
  else if (head.method === "captureDocument" || (head.method === "pickFile" && head.request.capability === "camera")) void startCamera();
}, { flush: "post" });

// ---- consent ----
const consent = computed(() => (current.value?.method === "consent" ? current.value.request : undefined));
const consentParams = computed(() => {
  const params = consent.value?.params;
  return params && typeof params === "object" && !Array.isArray(params) ? params as Record<string, unknown> : null;
});
function decide(decision: FlareCapabilityConsentDecision): void {
  void answer({ ...flareCapabilityConsentAnswer(decision) });
}

// ---- pickFile, locateOnce ----
const picking = computed(() => current.value?.method === "pickFile" ? current.value : undefined);
const scanning = computed(() => current.value?.method === "scanCode" ? current.value : undefined);
const cameraPick = computed(() => picking.value?.request.capability === "camera");
const pickLabel = computed(() => cameraPick.value
  ? props.deviceLabels?.camera ?? "Take photo"
  : picking.value?.request.capability === "selectImage"
    ? props.deviceLabels?.image ?? "Choose image"
    : props.deviceLabels?.file ?? "Choose file");
const cameraReady = ref(false);
async function runPick(): Promise<void> {
  const head = picking.value;
  if (!head || busy.value) return;
  busy.value = true;
  const accept = list(head.request.accept);
  const file = await (cameraPick.value ? shoot() : (props.pickFile ?? browserPickFile)(accept, text(head.request.capability))).catch(() => null);
  if (disposed || current.value !== head) return;
  if (!file) { await answer({ cancelled: true }); return; }
  const value = await corePluginCapabilityFile(file, accept, bytesLimit(head.request.maxBytes)).catch(() => null);
  if (disposed || current.value !== head) return;
  await answer(value ? { file: value } : { unavailable: true });
}
function scanAnswer(head: Pending) {
  return (result: CorePluginCapabilityResult): void => {
    if (current.value === head) void answer(result);
  };
}
async function runLocate(head: Pending): Promise<void> {
  const precision = head.request.precision === "fine" ? "fine" : "coarse";
  const fix = await (props.locate ?? browserLocateOnce)(precision).catch(() => null);
  if (disposed || current.value !== head) return;
  await answer(fix ? { location: fix } : { unavailable: true });
}

// ---- captureDocument ----
const capture = computed(() => (current.value?.method === "captureDocument" ? current.value.request : undefined));
const side = computed<FlareDocumentSide>(() => {
  const value = capture.value?.side;
  return value === "back" || value === "holding" ? value : "front";
});
const video = ref<HTMLVideoElement | null>(null);
const stream = shallowRef<MediaStream | null>(null);
const cameraUnavailable = ref(false);
async function startCamera(): Promise<void> {
  cameraUnavailable.value = false;
  const head = current.value;
  try {
    if (!navigator.mediaDevices?.getUserMedia) throw new Error("no camera");
    const opened = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: "environment" } }, audio: false });
    if (disposed || current.value !== head) { opened.getTracks().forEach((track) => track.stop()); return; }
    stream.value = opened;
  } catch {
    if (current.value === head) cameraUnavailable.value = true;
  }
}
function stopCamera(): void {
  cameraReady.value = false;
  stream.value?.getTracks().forEach((track) => track.stop());
  stream.value = null;
}
watch([video, stream], ([element, opened]) => {
  if (element && element.srcObject !== opened) element.srcObject = opened;
});
/** A still from the live camera, as a JPEG blob the kit then processes. */
async function shoot(): Promise<File | null> {
  const element = video.value;
  if (!element || !element.videoWidth || !element.videoHeight) return null;
  const canvas = document.createElement("canvas");
  canvas.width = element.videoWidth;
  canvas.height = element.videoHeight;
  canvas.getContext("2d")?.drawImage(element, 0, 0);
  return new Promise((resolve) => canvas.toBlob((blob) => resolve(blob
    ? new File([blob], "photo.jpg", { type: "image/jpeg" }) : null), "image/jpeg", 0.95));
}
function pickPhoto(): Promise<Blob | null> {
  return (props.pickFile ?? browserPickFile)(["image/jpeg", "image/png", "image/webp", "image/heic"], "selectImage").catch(() => null);
}
function captured(file: FlareCapturedDocument): void {
  stopCamera();
  void answer({ file: { fileName: file.fileName, contentType: file.contentType, bytes: Array.from(file.bytes) } });
}
function captureCancelled(): void {
  stopCamera();
  void answer({ cancelled: true });
}

// ---- confirmPayment ----
const payment = computed<FlarePaymentOrder | undefined>(() => {
  if (current.value?.method !== "confirmPayment") return undefined;
  const order = current.value.request.order as Partial<FlarePaymentOrder> | undefined;
  return order && typeof order.orderId === "string" && typeof order.amount === "string" && typeof order.currency === "string"
    && typeof order.expiresAtMs === "number"
    ? { orderId: order.orderId, amount: order.amount, currency: order.currency, payee: text(order.payee), title: text(order.title),
      expiresAtMs: order.expiresAtMs }
    : undefined;
});
watch([current, payment], ([head, order]) => {
  // A malformed order cannot be shown, so it cannot be confirmed.
  if (head?.method === "confirmPayment" && !order) void answer({ unavailable: true });
});
const password = ref("");
const passwordReady = computed(() => /^\d{6}$/.test(password.value));
function confirmPayment(): void {
  if (!passwordReady.value || busy.value) return;
  busy.value = true;
  const proof = { method: "paymentPassword", password: password.value };
  password.value = "";
  void answer({ confirmation: proof });
}
function paymentCancelled(): void {
  password.value = "";
  void answer({ cancelled: true });
}
</script>

<template>
  <FlareCapabilityConsent
    v-if="consent"
    :open="true"
    :plugin-name="name"
    :capability="text(consent.capability)"
    :params="consentParams"
    @decide="decide"
  />
  <FlareDocumentCapture
    v-if="capture"
    :open="true"
    :side="side"
    :accept="list(capture.accept)"
    :max-bytes="bytesLimit(capture.maxBytes)"
    :capture="stream ? shoot : undefined"
    :pick-photo="pickPhoto"
    :camera-unavailable="cameraUnavailable"
    @done="captured"
    @cancel="captureCancelled"
  >
    <template #preview>
      <video v-if="stream" ref="video" class="core-plugin-capability-camera" autoplay playsinline muted />
    </template>
  </FlareDocumentCapture>
  <FlareBottomSheet v-if="picking" :open="true" :title="name || pickLabel" @close="answer({ cancelled: true })">
    <video
      v-if="cameraPick && stream"
      ref="video"
      class="core-plugin-capability-camera"
      autoplay playsinline muted
      @canplay="cameraReady = true"
    />
    <p v-if="cameraPick && cameraUnavailable" role="status">{{ deviceLabels?.unavailable ?? "Camera unavailable" }}</p>
    <FlareButton :label="pickLabel" :disabled="busy || (cameraPick && !cameraReady)" @click="runPick" />
  </FlareBottomSheet>
  <FlareBottomSheet v-if="scanning && slots.scan" :key="scanning.requestId" :open="true" :title="name" @close="answer({ cancelled: true })">
    <slot name="scan" :answer="scanAnswer(scanning)" />
  </FlareBottomSheet>
  <FlarePaymentConfirmation
    v-if="payment"
    :open="true"
    :order="payment"
    :plugin-name="name"
    :busy="busy"
    :confirm-disabled="!passwordReady"
    @confirm="confirmPayment"
    @cancel="paymentCancelled"
    @expire="paymentCancelled"
  >
    <template #credential>
      <FlareInput
        v-model="password"
        secure
        inputmode="numeric"
        autocomplete="off"
        :max-length="6"
        :show-count="false"
        :aria-label="paymentPasswordLabel"
        :placeholder="paymentPasswordLabel"
        :disabled="busy"
        @submit="confirmPayment"
      />
    </template>
  </FlarePaymentConfirmation>
</template>

<style scoped>
.core-plugin-capability-camera {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
