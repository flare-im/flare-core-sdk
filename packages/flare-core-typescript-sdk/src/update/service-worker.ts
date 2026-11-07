/**
 * The Service Worker behind web updates. The whole of an app's `sw.ts`:
 *
 * ```ts
 * import { installFlareServiceWorker } from "@flare-im/sdk/update/service-worker";
 *
 * installFlareServiceWorker();
 * ```
 *
 * The script is the same for every build. Its URL names the build, the asset manifest and the
 * manifest's hash, which comes from the signed release manifest. At install the worker verifies the
 * manifest against that hash, then each shell asset against the manifest; any mismatch abandons the
 * install, and the failure stays in {@link FLARE_UPDATE_STATE_CACHE} for the page to report. A
 * rollback is the same URL with an older build in it.
 *
 * Navigations are answered from the build's own shell, so a tab only moves to another build through
 * the update flow, and the app still starts when the site is down.
 */

import type { UpdateErrorCode } from "./model";
import {
  FLARE_SHELL_CACHE_PREFIX,
  FLARE_UPDATE_STATE_CACHE,
  INSTALL_FAILURE_KEY,
  WORKER_SKIP_WAITING,
  openUpdateChannel,
  parseWebAssetManifest,
  sha256Hex,
  shellCacheName,
  webBundleTargetOf,
  type UpdateChannel,
  type WebAsset,
  type WebAssetManifest,
  type WebBundleInstallFailure,
} from "./webBundle";

interface WorkerExtendableEvent {
  waitUntil(work: Promise<unknown>): void;
}

interface WorkerFetchEvent {
  readonly request: Request;
  respondWith(response: Promise<Response>): void;
}

interface WorkerMessageEvent extends WorkerExtendableEvent {
  readonly data: unknown;
}

/** The parts of `ServiceWorkerGlobalScope` the worker uses. */
export interface FlareServiceWorkerScope {
  readonly location: { readonly href: string; readonly origin: string };
  readonly caches: CacheStorage;
  readonly registration: { readonly active: { readonly scriptURL: string } | null };
  readonly clients: { claim(): Promise<void> };
  skipWaiting(): Promise<void>;
  fetch(input: string | Request, init?: RequestInit): Promise<Response>;
  addEventListener(type: "install" | "activate", listener: (event: WorkerExtendableEvent) => void): void;
  addEventListener(type: "fetch", listener: (event: WorkerFetchEvent) => void): void;
  addEventListener(type: "message", listener: (event: WorkerMessageEvent) => void): void;
}

export interface FlareServiceWorkerOptions {
  /** The document navigations get, as the manifest lists it. Default `/index.html`. */
  navigationFallback?: string;
  /** Same-origin paths the worker leaves alone, requests and navigations alike (APIs, media). */
  bypass?: RegExp[];
  /** The worker's global scope; default `self`. */
  scope?: FlareServiceWorkerScope;
  createChannel?: () => UpdateChannel | null;
}

/** Key of the manifest in the shell cache: a restarted worker reads its assets back from there. */
const ASSETS_KEY = "/__flare-update/assets";

class BundleFailure extends Error {
  constructor(readonly code: UpdateErrorCode, readonly url?: string) {
    super(url === undefined ? code : `${code}: ${url}`);
  }
}

function failureOf(error: unknown): BundleFailure {
  if (error instanceof BundleFailure) return error;
  if ((error as { name?: unknown } | null)?.name === "QuotaExceededError") {
    return new BundleFailure("update.insufficientSpace");
  }
  return new BundleFailure("update.installFailed");
}

interface ServingState {
  cache: Cache;
  assets: Map<string, WebAsset>;
}

/** Installs the worker's handlers. Call it while the script evaluates, as the platform requires. */
export function installFlareServiceWorker(options: FlareServiceWorkerOptions = {}): void {
  const scope = options.scope ?? (globalThis as unknown as FlareServiceWorkerScope);
  const target = webBundleTargetOf(scope.location.href);
  if (!target) throw new Error("the Service Worker URL must carry build, manifest and sha256");

  const { buildId, manifestUrls, manifestSha256 } = target;
  const cacheName = shellCacheName(buildId);
  const bypass = options.bypass ?? [];
  const createChannel = options.createChannel ?? openUpdateChannel;
  const absolute = (url: string): string => new URL(url, scope.location.href).href;
  const fallback = absolute(options.navigationFallback ?? "/index.html");

  /** The file of `asset`, verified. Failures name the asset and leave nothing behind. */
  async function fetchVerified(asset: WebAsset): Promise<Response> {
    let response: Response;
    let body: ArrayBuffer;
    try {
      response = await scope.fetch(absolute(asset.source ?? asset.url), { cache: "no-cache" });
      if (!response.ok) throw new BundleFailure("update.downloadFailed", asset.url);
      body = await response.arrayBuffer();
    } catch (error) {
      throw error instanceof BundleFailure ? error : new BundleFailure("update.downloadFailed", asset.url);
    }
    if ((await sha256Hex(body)) !== asset.sha256) throw new BundleFailure("update.hashMismatch", asset.url);
    // A fresh response: one that followed a redirect could not answer a navigation.
    return new Response(body, { status: 200, headers: response.headers });
  }

  function checkedManifest(manifest: WebAssetManifest): WebAssetManifest {
    const sameOrigin = manifest.assets.every((asset) => new URL(asset.url, scope.location.href).origin === scope.location.origin);
    if (manifest.buildId !== buildId || !sameOrigin) throw new BundleFailure("update.installFailed");
    return manifest;
  }

  /** The first address whose content has the signed hash; a bad mirror does not end the attempt. */
  async function loadManifest(): Promise<WebAssetManifest> {
    let failure = new BundleFailure("update.downloadFailed");
    for (const url of manifestUrls) {
      let body: ArrayBuffer;
      try {
        const response = await scope.fetch(absolute(url), { cache: "no-cache" });
        if (!response.ok) continue;
        body = await response.arrayBuffer();
      } catch {
        continue;
      }
      if ((await sha256Hex(body)) !== manifestSha256) {
        failure = new BundleFailure("update.hashMismatch", url);
        continue;
      }
      return checkedManifest(parseWebAssetManifest(new TextDecoder().decode(body)));
    }
    throw failure;
  }

  async function recordFailure(error: unknown): Promise<void> {
    const failure = failureOf(error);
    const active = scope.registration.active;
    // A new script for the build already live shares its cache, which must keep serving.
    if (!active || webBundleTargetOf(active.scriptURL)?.buildId !== buildId) {
      await scope.caches.delete(cacheName);
    }
    const record: WebBundleInstallFailure = {
      buildId,
      code: failure.code,
      ...(failure.url !== undefined ? { url: failure.url } : {}),
    };
    const state = await scope.caches.open(FLARE_UPDATE_STATE_CACHE);
    await state.put(INSTALL_FAILURE_KEY, new Response(JSON.stringify(record)));
  }

  async function install(): Promise<void> {
    const channel = createChannel();
    try {
      const manifest = await loadManifest();
      const cache = await scope.caches.open(cacheName);
      const shell = manifest.assets.filter((asset) => asset.precache === true);
      const total = shell.reduce((sum, asset) => sum + asset.size, 0);
      let received = 0;
      for (const asset of shell) {
        await cache.put(absolute(asset.url), await fetchVerified(asset));
        received += asset.size;
        channel?.postMessage({ type: "installProgress", buildId, received, total });
      }
      await cache.put(ASSETS_KEY, new Response(JSON.stringify(manifest)));
    } catch (error) {
      await recordFailure(error);
      throw error;
    } finally {
      channel?.close();
    }
  }

  async function activate(): Promise<void> {
    for (const name of await scope.caches.keys()) {
      if (name.startsWith(FLARE_SHELL_CACHE_PREFIX) && name !== cacheName) await scope.caches.delete(name);
    }
    await scope.caches.delete(FLARE_UPDATE_STATE_CACHE);
    await scope.clients.claim();
  }

  let serving: ServingState | null = null;

  /** The cache and assets of this build; a worker restarts at will and reads them back. */
  async function servingState(): Promise<ServingState | null> {
    if (serving) return serving;
    const cache = await scope.caches.open(cacheName);
    const stored = await cache.match(ASSETS_KEY);
    if (!stored) return null;
    const manifest = parseWebAssetManifest(await stored.text());
    const assets = new Map<string, WebAsset>();
    for (const asset of manifest.assets) assets.set(absolute(asset.url), asset);
    serving = { cache, assets };
    return serving;
  }

  async function respond(request: Request, url: URL): Promise<Response> {
    const state = await servingState();
    if (!state) return scope.fetch(request);
    if (request.mode === "navigate") return (await state.cache.match(fallback)) ?? scope.fetch(request);
    const asset = state.assets.get(url.href);
    if (!asset) return scope.fetch(request);
    const hit = await state.cache.match(url.href);
    if (hit) return hit;
    const response = await fetchVerified(asset);
    await state.cache.put(url.href, response.clone());
    return response;
  }

  scope.addEventListener("install", (event) => event.waitUntil(install()));
  scope.addEventListener("activate", (event) => event.waitUntil(activate()));

  scope.addEventListener("message", (event) => {
    const type = (event.data as { type?: unknown } | null)?.type;
    if (type === WORKER_SKIP_WAITING) event.waitUntil(scope.skipWaiting());
  });

  scope.addEventListener("fetch", (event) => {
    const { request } = event;
    if (request.method !== "GET" || request.headers.has("range")) return;
    const url = new URL(request.url);
    if (url.origin !== scope.location.origin) return;
    if (bypass.some((pattern) => pattern.test(url.pathname))) return;
    event.respondWith(respond(request, url));
  });
}
