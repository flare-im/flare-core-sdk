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
 * - confirmPayment: `FlarePaymentConfirmation` with the kit's six-cell `FlarePinInput` in its credential slot; the
 *   answer is `{confirmation: {method: "paymentPassword", password}}`, which the payment provider verifies. The password
 *   lives only in this sheet. When the request `reportsOutcome`, the sheet stays up, busy (every key locked, no way
 *   out), after the answer: the engine either asks again for the same order with `error` (the provider refused that
 *   password: shown in the sheet, unlocked for another try) or sends the `paymentSettled` notice, which closes it.
 * - locateOnce: one fix from `navigator.geolocation` (the consent prompt came first; the browser asks its own).
 * Anything else, or a host that cannot, answers `{unavailable: true}`.
 */
import { computed, inject, onBeforeUnmount, ref, shallowRef, useSlots, watch } from "vue";
import CorePluginAudioCapture from "./CorePluginAudioCapture.vue";
import {
  FlareCapabilityConsent,
  FlareBottomSheet,
  FlareButton,
  FlareDocumentCapture,
  FlarePaymentConfirmation,
  FlarePinInput,
  flareCapabilityConsentAnswer,
  flarePaymentAmountText,
  useFlareI18n,
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
import { offerCapturedPhoto } from "./capturedPhotos";
import { pluginUiErrorTextKey, type CorePluginErrorText } from "./context";

const props = defineProps<{
  /** The requests the host forwards (`createCorePluginCapabilityRequestFeed().requests`). */
  requests: CorePluginCapabilityRequestFeed;
  /** `plugin.capability_complete` (the core SDK's `completePluginCapabilityRequest`). */
  complete: (requestId: number, result: CorePluginCapabilityResult) => Promise<void>;
  /**
   * The plugin's name as the catalog gives it; the plugin id while unknown. A payment names the order's `requestedBy`
   * plugin when this knows it, else the requesting plugin.
   */
  pluginName?: (pluginId: string) => string | undefined | Promise<string | undefined>;
  /** The label and placeholder of the payment password in the confirmation sheet (the host's copy). */
  paymentPasswordLabel: string;
  /** One fix at the precision asked; defaults to the browser's location API. */
  locate?: (precision: "coarse" | "fine") => Promise<{ latitude: number; longitude: number; accuracyM?: number } | null>;
  /** The file picker; defaults to the browser's. */
  pickFile?: (accept: readonly string[], capability: string) => Promise<Blob | null>;
  deviceLabels?: { camera: string; image: string; file: string; unavailable: string };
  /**
   * The host's words for why the payment provider refused a password (`{reason, machineReason}`: the `sdk.plugin.*` key
   * and the provider's code); defaults to the one given to `provideCorePluginUi`, then the kit's generic line.
   */
  errorText?: CorePluginErrorText;
}>();

/** A page the viewer asked to open from a capability screen (the payment's top up). */
type CorePluginCapabilityPageTarget = { pluginId: string; page: string };
const emit = defineEmits<{
  /** Top up from an insufficient payment: the request is answered cancelled first; the host opens this page. */
  openPage: [target: CorePluginCapabilityPageTarget];
}>();
const slots = useSlots();

type Pending = { requestId: number; method: string; request: Record<string, unknown> };
const queue = shallowRef<Pending[]>([]);
const current = computed(() => queue.value[0]);
const name = ref("");
const busy = ref(false);
let disposed = false;

const { t } = useFlareI18n();
const providedErrorText = inject(pluginUiErrorTextKey, () => undefined);
/** The payment answered with a password whose outcome the engine reports: its sheet stays, busy, until then. */
let settling: Pending | undefined;
const orderIdOf = (request: Record<string, unknown>) => text((request.order as Record<string, unknown> | undefined)?.orderId);
function settled(): void {
  settling = undefined;
  queue.value = queue.value.slice(1);
  busy.value = false;
}

const stop = props.requests((request) => {
  const waiting = settling;
  const sameOrder = (pluginId: unknown, orderId: string) =>
    !!waiting && text(pluginId) === text(waiting.request.pluginId) && !!orderId && orderId === orderIdOf(waiting.request);
  // A notice, never queued nor answered: the engine is done with the confirmation the sheet may be waiting on.
  if (request.method === "paymentSettled") {
    if (sameOrder(request.request.pluginId, text(request.request.orderId))) settled();
    return;
  }
  // The engine asks again for that order (the provider refused the password): the same sheet, with why.
  if (request.method === "confirmPayment" && sameOrder(request.request.pluginId, orderIdOf(request.request))) {
    settling = undefined;
    queue.value = [request, ...queue.value.slice(1)];
    busy.value = false;
    return;
  }
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
  const requestedBy = head.method === "confirmPayment" ? text((head.request.order as Record<string, unknown> | undefined)?.requestedBy) : "";
  name.value = pluginId;
  const nameOf = (id: string) => Promise.resolve(id ? props.pluginName?.(id) : undefined).catch(() => undefined);
  void nameOf(requestedBy).then((by) => by || nameOf(pluginId)).then((resolved) => {
    if (current.value === head && resolved) name.value = resolved;
  });
  if (!corePluginCapabilityMethodKnown(head.method)) { await answer({ unavailable: true }); return; }
  if (head.method === "scanCode" && !slots.scan) await answer({ unavailable: true });
  else if (head.method === "pickFile" && head.request.capability === "microphone" &&
      (!list(head.request.accept).some((type) => type.startsWith("audio/")) || !bytesLimit(head.request.maxBytes))) {
    await answer({ unavailable: true });
  }
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
const audioPick = computed(() => picking.value?.request.capability === "microphone");
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
function deviceAnswer(head: Pending) {
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
  // The page takes this once to preview the slot; it stays in memory only.
  offerCapturedPhoto(text(current.value?.request.pluginId), side.value, new Blob([new Uint8Array(file.bytes)], { type: file.contentType }));
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
// The engine adds both only when the viewer's balance is short: a positive decimal in the order's currency, and the
// page that tops it up ({kind: "page", page, pluginId?}; the requesting plugin when pluginId is absent).
const paymentOrder = computed(() => (payment.value ? current.value?.request.order as Record<string, unknown> : undefined));
const paymentShortfall = computed(() => {
  const value = paymentOrder.value?.shortfall;
  if (typeof value !== "string" || !/^\d+(\.\d+)?$/.test(value) || !/[1-9]/.test(value)) return undefined;
  return flarePaymentAmountText(value, payment.value!.currency) ?? value;
});
const paymentTopUp = computed<CorePluginCapabilityPageTarget | undefined>(() => {
  const target = paymentOrder.value?.topUp as Record<string, unknown> | undefined;
  if (!target || target.kind !== "page" || !text(target.page)) return undefined;
  return { pluginId: text(target.pluginId) || text(current.value?.request.pluginId), page: text(target.page) };
});
watch([current, payment], ([head, order]) => {
  // A malformed order cannot be shown, so it cannot be confirmed.
  if (head?.method === "confirmPayment" && !order) void answer({ unavailable: true });
});
const password = ref("");
const passwordReady = computed(() => /^\d{6}$/.test(password.value));
// Why the provider refused the last password for this order (a re-asked request's `error`), in the host's words.
const paymentError = computed(() => {
  const error = payment.value ? current.value?.request.error : undefined;
  if (!error || typeof error !== "object" || busy.value) return undefined;
  const { key, code, message } = error as { key?: unknown; code?: unknown; message?: unknown };
  if (text(message)) return text(message);
  const cause = { reason: text(key), machineReason: text(code) || undefined };
  return (props.errorText ?? providedErrorText)(cause) ?? t("pluginRuntime.rejected");
});
function confirmPayment(): void {
  const head = current.value;
  if (!passwordReady.value || busy.value || head?.method !== "confirmPayment") return;
  busy.value = true;
  const proof = { method: "paymentPassword", password: password.value };
  password.value = "";
  // An engine that reports no outcome: answered and closed, as before.
  if (head.request.reportsOutcome !== true) { void answer({ confirmation: proof }); return; }
  // §4.3 busy until the engine settles this order or asks again with why.
  settling = head;
  void props.complete(head.requestId, { confirmation: proof }).catch(() => {
    // The engine no longer waits for it: nothing follows.
    if (settling === head) settled();
  });
}
// The request the sheet shows now: a second event in the same tick (start again, then the sheet's close) must not
// answer the next queued payment, which the sheet has not drawn yet.
let paymentShownId: number | undefined;
watch(payment, (order) => { paymentShownId = order ? current.value?.requestId : undefined; }, { immediate: true });
/** Cancel, close, or start again after expiry (§4.3): answered cancelled once; the page that asked can send again. */
function paymentCancelled(): boolean {
  const head = current.value;
  if (head?.method !== "confirmPayment" || head.requestId !== paymentShownId || settling === head) return false;
  paymentShownId = undefined;
  password.value = "";
  void answer({ cancelled: true });
  return true;
}
function topUp(): void {
  const target = paymentTopUp.value;
  if (!target || busy.value) return;
  if (paymentCancelled()) emit("openPage", target);
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
  <FlareBottomSheet v-if="picking && audioPick" :key="picking.requestId" :open="true" :title="name" @close="answer({ cancelled: true })">
    <CorePluginAudioCapture :accept="list(picking.request.accept)" :max-bytes="bytesLimit(picking.request.maxBytes)"
      :onAnswer="deviceAnswer(picking)" />
  </FlareBottomSheet>
  <FlareBottomSheet v-else-if="picking" :open="true" :title="name || pickLabel" @close="answer({ cancelled: true })">
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
    <slot name="scan" :answer="deviceAnswer(scanning)" />
  </FlareBottomSheet>
  <FlarePaymentConfirmation
    v-if="payment"
    :open="true"
    :order="payment"
    :plugin-name="name"
    :busy="busy"
    :error="paymentError"
    :confirm-disabled="!passwordReady"
    :shortfall="paymentShortfall"
    @confirm="confirmPayment"
    @cancel="paymentCancelled"
    @expire="password = ''"
    @start-again="paymentCancelled"
    @top-up="topUp"
  >
    <template #credential>
      <FlarePinInput v-model="password" :label="paymentPasswordLabel" :disabled="busy" :error="!!paymentError" />
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
