/** The SDK event channel on which the engine asks the host for its part of a capability (`onPluginCapabilityRequest`). */
export const CORE_PLUGIN_CAPABILITY_REQUEST_CHANNEL = "im://plugin_capability_request";

/** What the engine asks the host to do. */
export type CorePluginCapabilityMethod = "consent" | "captureDocument" | "pickFile" | "scanCode" | "confirmPayment" | "locateOnce";

/**
 * One request of the engine (`plugin.capability_request`): answer it once with `plugin.capability_complete`
 * (`{requestId, result}`); the engine gives up after 10 minutes and refuses a late answer.
 */
export interface CorePluginCapabilityRequest {
  requestId: number;
  method: CorePluginCapabilityMethod;
  request: Record<string, unknown>;
}

/**
 * The host's answer, the `result` of `plugin.capability_complete`:
 * - consent: `{decision: "once" | "always" | "deny"}` (only "always" is kept by the engine);
 * - captureDocument, pickFile: `{file: {fileName, contentType, bytes: [0..255]}}`;
 * - scanCode: `{text}`;
 * - confirmPayment: `{confirmation: {method: "paymentPassword", password}}`, the proof the plugin's server verifies;
 * - locateOnce: `{location: {latitude, longitude, accuracyM?}}`;
 * - any of them: `{cancelled: true}` or `{unavailable: true}`.
 */
export type CorePluginCapabilityResult = Record<string, unknown>;

const METHODS: ReadonlySet<string> = new Set<CorePluginCapabilityMethod>(["consent", "captureDocument", "pickFile", "scanCode", "confirmPayment", "locateOnce"]);

/**
 * An `im://plugin_capability_request` payload as a request, or null when it is not one. A request of a method this
 * host does not know is still a request (it is answered `{unavailable: true}`), so its `method` stays as given.
 */
export function corePluginCapabilityRequest(payload: unknown): (Omit<CorePluginCapabilityRequest, "method"> & { method: string }) | null {
  const record = (payload ?? {}) as { requestId?: unknown; method?: unknown; request?: unknown };
  if (typeof record.requestId !== "number" || !Number.isSafeInteger(record.requestId) || record.requestId <= 0) return null;
  if (typeof record.method !== "string" || !record.method) return null;
  const request = record.request && typeof record.request === "object" && !Array.isArray(record.request)
    ? record.request as Record<string, unknown> : {};
  return { requestId: record.requestId, method: record.method, request };
}

/** Whether the host knows how to answer `method`. */
export function corePluginCapabilityMethodKnown(method: string): method is CorePluginCapabilityMethod {
  return METHODS.has(method);
}

/** Subscribes to capability requests; returns the unsubscribe. */
export type CorePluginCapabilityRequestFeed = (listener: (request: Omit<CorePluginCapabilityRequest, "method"> & { method: string }) => void) => () => void;

export interface CorePluginCapabilityRequestHub {
  /** What `CorePluginCapabilityHost` listens on. */
  requests: CorePluginCapabilityRequestFeed;
  /** Forwards one `im://plugin_capability_request` payload; returns whether it was a request. */
  announce(payload: unknown): boolean;
}

/**
 * The host's side of capability requests: the host routes the SDK event into `announce`, the one mounted
 * `CorePluginCapabilityHost` answers. A request that arrives while nobody listens is answered by nobody, and the engine
 * reads it as unavailable when its wait ends; mount the host for as long as the user is signed in.
 */
export function createCorePluginCapabilityRequestFeed(): CorePluginCapabilityRequestHub {
  const listeners = new Set<Parameters<CorePluginCapabilityRequestFeed>[0]>();
  return {
    requests: (listener) => {
      listeners.add(listener);
      return () => { listeners.delete(listener); };
    },
    announce(payload) {
      const request = corePluginCapabilityRequest(payload);
      if (!request) return false;
      for (const listener of [...listeners]) listener(request);
      return true;
    },
  };
}

/** The file a picker gave, as the engine takes it: `{fileName, contentType, bytes}`, refused when it breaks `accept` or `maxBytes`. */
export async function corePluginCapabilityFile(file: Blob & { name?: string }, accept: readonly string[], maxBytes: number):
  Promise<{ fileName: string; contentType: string; bytes: number[] } | null> {
  const contentType = (file.type || "application/octet-stream").toLowerCase();
  if (!file.size || file.size > maxBytes || (accept.length > 0 && !accept.includes(contentType))) return null;
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (!bytes.length || bytes.length > maxBytes) return null;
  return { fileName: file.name?.trim() || "file", contentType, bytes: Array.from(bytes) };
}

/** A fix from the browser's location API (`navigator.geolocation`), one reading at the precision asked. */
export function browserLocateOnce(precision: "coarse" | "fine", timeoutMs = 20000):
  Promise<{ latitude: number; longitude: number; accuracyM?: number } | null> {
  return new Promise((resolve) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) { resolve(null); return; }
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude, accuracy } = position.coords;
        resolve(Number.isFinite(latitude) && Number.isFinite(longitude)
          ? { latitude, longitude, ...(Number.isFinite(accuracy) && accuracy >= 0 ? { accuracyM: accuracy } : {}) } : null);
      },
      () => resolve(null),
      { enableHighAccuracy: precision === "fine", timeout: timeoutMs, maximumAge: precision === "fine" ? 0 : 300000 },
    );
  });
}

/** The browser file picker for a pick request (`selectImage`, `camera`, `selectFile`); null when nothing was chosen. */
export function browserPickFile(accept: readonly string[], capability: string): Promise<File | null> {
  return new Promise((resolve) => {
    const picker = document.createElement("input");
    picker.type = "file";
    picker.accept = accept.length ? accept.join(",") : capability === "selectFile" ? "" : "image/*";
    if (capability === "camera") picker.setAttribute("capture", "environment");
    picker.hidden = true;
    let done = false;
    const finish = (file: File | null) => {
      if (done) return;
      done = true;
      picker.remove();
      resolve(file);
    };
    picker.addEventListener("change", () => finish(picker.files?.[0] ?? null), { once: true });
    picker.addEventListener("cancel", () => finish(null), { once: true });
    document.body.appendChild(picker);
    picker.click();
  });
}
