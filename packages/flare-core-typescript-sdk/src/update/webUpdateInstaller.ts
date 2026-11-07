import type { LifecycleEventTarget } from "../lifecycle/platformLifecycle";
import { AppState } from "../model/app_state";
import type { SetAppStateRequest } from "../model/set_app_state_request";
import type { UpdateInstallPlan } from "../model/update_install_plan";
import { isActivateWebBundlePlan, type UpdateActivateWebBundlePlan, type UpdateErrorCode } from "./model";
import type { FlareUpdateInstaller, UpdateInstallContext, UpdateInstallResult } from "./updateInstaller";
import {
  FLARE_UPDATE_STATE_CACHE,
  INSTALL_FAILURE_KEY,
  WORKER_SKIP_WAITING,
  openUpdateChannel,
  sha256Hex,
  webBundleTargetOf,
  workerScriptUrl,
  type UpdateChannel,
  type UpdateChannelMessage,
  type WebBundleInstallFailure,
} from "./webBundle";

/** The parts of `ServiceWorker` the installer uses. */
export interface WebUpdateWorker {
  readonly state: string;
  readonly scriptURL: string;
  postMessage(message: unknown): void;
  addEventListener(type: "statechange", listener: () => void): void;
  removeEventListener(type: "statechange", listener: () => void): void;
}

/** The parts of `ServiceWorkerRegistration` the installer uses. */
export interface WebUpdateRegistration {
  readonly installing: WebUpdateWorker | null;
  readonly waiting: WebUpdateWorker | null;
  readonly active: WebUpdateWorker | null;
}

/** The parts of `ServiceWorkerContainer` the installer uses. */
export interface WebUpdateContainer {
  getRegistration(scope: string): Promise<WebUpdateRegistration | undefined>;
  register(url: string, options: { scope: string; updateViaCache: "none" }): Promise<WebUpdateRegistration>;
  addEventListener(type: "controllerchange", listener: () => void): void;
  removeEventListener(type: "controllerchange", listener: () => void): void;
}

/** The parts of `sessionStorage` the installer uses. */
export interface WebUpdateStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

/** How the page tells the core it is going away; the outbox is in IndexedDB, so a reload loses nothing. */
export interface WebUpdateSession {
  setAppState(request: SetAppStateRequest): Promise<void>;
  disconnect(): Promise<void>;
}

export interface WebUpdateInstallerOptions {
  /** The build this page runs: the value given to `app.buildId`. */
  buildId: string;
  session: WebUpdateSession;
  /** True while the composer holds nothing: a forced update may only reload an idle, empty page. */
  isInputEmpty(): boolean;
  /** Default `/sw.js`. */
  scriptUrl?: string;
  /** Default `/`. */
  scope?: string;
  /** No input for this long counts as idle. Default 30 seconds. */
  idleMs?: number;
  /** Default the page's own; null where the browser offers none. */
  container?: WebUpdateContainer | null;
  caches?: CacheStorage | null;
  storage?: WebUpdateStorage | null;
  activityTarget?: LifecycleEventTarget | null;
  createChannel?: () => UpdateChannel | null;
  reload?: () => void;
  onError?: (error: unknown) => void;
}

export interface RegisterFlareServiceWorkerOptions {
  /** The build this page runs. */
  buildId: string;
  /** Default `/asset-manifest.json`. */
  assetManifestUrl?: string;
  /** Default `/sw.js`. */
  scriptUrl?: string;
  /** Default `/`. */
  scope?: string;
  container?: WebUpdateContainer | null;
  fetch?: (url: string, init: RequestInit) => Promise<Response>;
  /** Resolves when registering no longer competes with the first screen. */
  afterFirstPaint?: () => Promise<void>;
  onError?: (error: unknown) => void;
}

const DEFAULT_SCRIPT_URL = "/sw.js";
const DEFAULT_SCOPE = "/";
const DEFAULT_ASSET_MANIFEST_URL = "/asset-manifest.json";
const DEFAULT_IDLE_MS = 30_000;
/** How often an idle page with text in the composer looks again. */
const IDLE_RECHECK_MS = 1_000;
/** The browser ends a stuck install by itself; this only keeps the prompt from waiting on it forever. */
const INSTALL_TIMEOUT_MS = 300_000;
const STOP_SESSION_TIMEOUT_MS = 3_000;
const ACTIVATION_TIMEOUT_MS = 5_000;
const ACTIVITY_EVENTS = ["pointerdown", "pointermove", "keydown", "wheel", "touchstart"] as const;
/** The build a reload was last sent to; finding it again means that reload did not get there. */
const RELOAD_TARGET_KEY = "flare-update:reload-target";

function browserContainer(): WebUpdateContainer | null {
  const page = globalThis as unknown as { navigator?: { serviceWorker?: unknown } };
  return (page.navigator?.serviceWorker as WebUpdateContainer | undefined) ?? null;
}

function browserStorage(): WebUpdateStorage | null {
  try {
    return (globalThis as unknown as { sessionStorage?: WebUpdateStorage }).sessionStorage ?? null;
  } catch {
    return null;
  }
}

function browserCaches(): CacheStorage | null {
  return (globalThis as unknown as { caches?: CacheStorage }).caches ?? null;
}

function browserActivityTarget(): LifecycleEventTarget | null {
  return (globalThis as unknown as { window?: LifecycleEventTarget }).window ?? null;
}

function browserReload(): void {
  (globalThis as unknown as { location?: { reload(): void } }).location?.reload();
}

function browserAfterFirstPaint(): Promise<void> {
  const page = globalThis as unknown as {
    document?: { readyState?: string };
    requestIdleCallback?: (callback: () => void) => unknown;
    addEventListener?: (type: string, listener: () => void, options: { once: boolean }) => void;
  };
  return new Promise((resolve) => {
    const whenIdle = (): void => {
      if (page.requestIdleCallback) page.requestIdleCallback(() => resolve());
      else setTimeout(resolve, 0);
    };
    if (page.document?.readyState === "complete" || !page.addEventListener) whenIdle();
    else page.addEventListener("load", whenIdle, { once: true });
  });
}

function buildOf(worker: WebUpdateWorker): string | undefined {
  return webBundleTargetOf(worker.scriptURL)?.buildId;
}

/** Resolves when `work` settles or `ms` passed, whichever is first. Never rejects. */
function settleWithin(work: Promise<unknown>, ms: number): Promise<void> {
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, ms);
    const done = (): void => {
      clearTimeout(timer);
      resolve();
    };
    work.then(done, done);
  });
}

/**
 * Registers the worker of the running build once there is none, after the first screen. An existing
 * registration is left alone: it may already be a newer build, and only the update flow moves it.
 * The manifest's hash comes from the page here, since nothing signed names the running build.
 * Failures only cost this visit's offline start, so they go to `onError`.
 */
export async function registerFlareServiceWorker(options: RegisterFlareServiceWorkerOptions): Promise<void> {
  const container = options.container === undefined ? browserContainer() : options.container;
  if (!container) return;
  const scope = options.scope ?? DEFAULT_SCOPE;
  const manifestUrl = options.assetManifestUrl ?? DEFAULT_ASSET_MANIFEST_URL;
  try {
    await (options.afterFirstPaint ?? browserAfterFirstPaint)();
    if (await container.getRegistration(scope)) return;
    const load = options.fetch ?? ((url: string, init: RequestInit) => fetch(url, init));
    const response = await load(manifestUrl, { cache: "no-cache" });
    if (!response.ok) throw new Error(`asset manifest answered ${response.status}`);
    const manifestSha256 = await sha256Hex(await response.arrayBuffer());
    const url = workerScriptUrl(options.scriptUrl ?? DEFAULT_SCRIPT_URL, {
      buildId: options.buildId,
      manifestUrls: [manifestUrl],
      manifestSha256,
    });
    await container.register(url, { scope, updateViaCache: "none" });
  } catch (error) {
    options.onError?.(error);
  }
}

interface IdleWatch {
  /** Resolves once the page is idle with an empty composer. */
  readonly done: Promise<void>;
  stop(): void;
}

type Prepared = { worker: WebUpdateWorker | null } | { code: UpdateErrorCode };

class WebUpdateInstaller implements FlareUpdateInstaller {
  private readonly container: WebUpdateContainer | null;
  private readonly caches: CacheStorage | null;
  private readonly storage: WebUpdateStorage | null;
  private readonly activityTarget: LifecycleEventTarget | null;
  private readonly channel: UpdateChannel | null;
  private readonly reload: () => void;
  private readonly idleWatches = new Set<IdleWatch>();
  private installing: { buildId: string; context: UpdateInstallContext } | null = null;
  private followingReload = false;
  private disposed = false;

  private readonly onChannelMessage = (event: { data: unknown }): void => {
    const message = event.data as UpdateChannelMessage | null;
    if (message?.type === "installProgress") {
      if (this.installing?.buildId === message.buildId) {
        this.installing.context.setProgress({ received: message.received, total: message.total });
      }
    } else if (message?.type === "reload" && message.buildId !== this.options.buildId) {
      void this.followReload();
    }
  };

  constructor(private readonly options: WebUpdateInstallerOptions) {
    this.container = options.container === undefined ? browserContainer() : options.container;
    this.caches = options.caches === undefined ? browserCaches() : options.caches;
    this.storage = options.storage === undefined ? browserStorage() : options.storage;
    this.activityTarget = options.activityTarget === undefined ? browserActivityTarget() : options.activityTarget;
    this.channel = (options.createChannel ?? openUpdateChannel)();
    this.reload = options.reload ?? browserReload;
    this.channel?.addEventListener("message", this.onChannelMessage);
    if (this.storage?.getItem(RELOAD_TARGET_KEY) === options.buildId) this.storage.removeItem(RELOAD_TARGET_KEY);
  }

  async execute(plan: UpdateInstallPlan, context: UpdateInstallContext): Promise<UpdateInstallResult> {
    if (!isActivateWebBundlePlan(plan)) return { outcome: "failed", code: "update.installFailed" };

    // Without a Service Worker there is nothing to verify or activate: a reload is the whole update.
    const prepared: Prepared = this.container ? await this.prepare(this.container, plan, context) : { worker: null };
    if ("code" in prepared) return { outcome: "failed", code: prepared.code };

    // The last reload went to this build and this page is not it. Reloading again would only loop.
    if (this.storage?.getItem(RELOAD_TARGET_KEY) === plan.buildId) {
      this.storage.removeItem(RELOAD_TARGET_KEY);
      return { outcome: "failed", code: "update.installFailed" };
    }

    if (!(await this.decide(plan, context))) return { outcome: "cancelled" };

    await this.stopSession();
    if (prepared.worker) await this.activate(prepared.worker);
    this.storage?.setItem(RELOAD_TARGET_KEY, plan.buildId);
    this.channel?.postMessage({ type: "reload", buildId: plan.buildId });
    return { outcome: "completed", finish: () => this.reload() };
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    for (const watch of [...this.idleWatches]) watch.stop();
    this.channel?.removeEventListener("message", this.onChannelMessage);
    this.channel?.close();
  }

  /**
   * Installs the target's worker and waits until it is verified. The worker to activate comes back,
   * or null when the target is already the active one and only this page lags behind.
   */
  private async prepare(
    container: WebUpdateContainer,
    plan: UpdateActivateWebBundlePlan,
    context: UpdateInstallContext,
  ): Promise<Prepared> {
    const url = workerScriptUrl(this.options.scriptUrl ?? DEFAULT_SCRIPT_URL, {
      buildId: plan.buildId,
      manifestUrls: plan.assetManifestUrls,
      manifestSha256: plan.assetManifestSha256,
    });
    this.installing = { buildId: plan.buildId, context };
    try {
      let registration: WebUpdateRegistration;
      try {
        registration = await container.register(url, {
          scope: this.options.scope ?? DEFAULT_SCOPE,
          updateViaCache: "none",
        });
      } catch (error) {
        this.options.onError?.(error);
        return { code: "update.downloadFailed" };
      }
      const worker = registration.installing ?? registration.waiting;
      if (!worker) {
        const active = registration.active;
        if (active && buildOf(active) === plan.buildId) return { worker: null };
        return { code: await this.takeInstallFailure(plan.buildId) };
      }
      if (buildOf(worker) !== plan.buildId) return { code: "update.installFailed" };
      const state = await this.installed(worker);
      if (state === "redundant") return { code: await this.takeInstallFailure(plan.buildId) };
      if (state === "timeout") return { code: "update.downloadFailed" };
      return { worker };
    } finally {
      this.installing = null;
      context.setProgress(null);
    }
  }

  private installed(worker: WebUpdateWorker): Promise<"installed" | "redundant" | "timeout"> {
    return new Promise((resolve) => {
      const settle = (state: "installed" | "redundant" | "timeout"): void => {
        clearTimeout(timer);
        worker.removeEventListener("statechange", check);
        resolve(state);
      };
      const check = (): void => {
        if (worker.state === "redundant") settle("redundant");
        else if (worker.state !== "parsed" && worker.state !== "installing") settle("installed");
      };
      const timer = setTimeout(() => settle("timeout"), INSTALL_TIMEOUT_MS);
      worker.addEventListener("statechange", check);
      check();
    });
  }

  /** What the worker recorded before it gave up; the record is consumed. */
  private async takeInstallFailure(buildId: string): Promise<UpdateErrorCode> {
    if (!this.caches) return "update.installFailed";
    try {
      const cache = await this.caches.open(FLARE_UPDATE_STATE_CACHE);
      const response = await cache.match(INSTALL_FAILURE_KEY);
      if (!response) return "update.installFailed";
      const failure = await response.json() as WebBundleInstallFailure;
      await cache.delete(INSTALL_FAILURE_KEY);
      return failure.buildId === buildId ? failure.code : "update.installFailed";
    } catch (error) {
      this.options.onError?.(error);
      return "update.installFailed";
    }
  }

  /** Whether to go ahead: a blocking update at once, a forced one also when idle, the rest on request. */
  private async decide(plan: UpdateActivateWebBundlePlan, context: UpdateInstallContext): Promise<boolean> {
    if (plan.blockUi) return true;
    if (!plan.mandatory) return context.waitForConfirmation();
    const idle = this.watchIdle();
    try {
      return await Promise.race([context.waitForConfirmation(), idle.done.then(() => true)]);
    } finally {
      idle.stop();
    }
  }

  private watchIdle(): IdleWatch {
    const idleMs = this.options.idleMs ?? DEFAULT_IDLE_MS;
    const target = this.activityTarget;
    let lastActivity = Date.now();
    let timer: ReturnType<typeof setTimeout> | null = null;
    let finish: () => void = () => undefined;
    const noteActivity = (): void => {
      lastActivity = Date.now();
    };
    const stop = (): void => {
      if (timer !== null) clearTimeout(timer);
      timer = null;
      for (const type of ACTIVITY_EVENTS) target?.removeEventListener(type, noteActivity);
      this.idleWatches.delete(watch);
    };
    const tick = (): void => {
      const remaining = lastActivity + idleMs - Date.now();
      if (remaining > 0) {
        timer = setTimeout(tick, remaining);
      } else if (this.options.isInputEmpty()) {
        stop();
        finish();
      } else {
        timer = setTimeout(tick, IDLE_RECHECK_MS);
      }
    };
    const done = new Promise<void>((resolve) => {
      finish = resolve;
    });
    const watch: IdleWatch = { done, stop };
    this.idleWatches.add(watch);
    for (const type of ACTIVITY_EVENTS) target?.addEventListener(type, noteActivity);
    timer = setTimeout(tick, idleMs);
    return watch;
  }

  /** Background, then a graceful disconnect. Neither may hold the update back. */
  private stopSession(): Promise<void> {
    const { session, onError } = this.options;
    const stop = async (): Promise<void> => {
      try {
        await session.setAppState({ appState: AppState.Background });
      } catch (error) {
        onError?.(error);
      }
      try {
        await session.disconnect();
      } catch (error) {
        onError?.(error);
      }
    };
    return settleWithin(stop(), STOP_SESSION_TIMEOUT_MS);
  }

  /** `skipWaiting`, then waits for the worker to take over. A reload also gets there, only later. */
  private activate(worker: WebUpdateWorker): Promise<void> {
    const container = this.container;
    if (!container || worker.state !== "installed") return Promise.resolve();
    return new Promise((resolve) => {
      const done = (): void => {
        clearTimeout(timer);
        container.removeEventListener("controllerchange", done);
        resolve();
      };
      const timer = setTimeout(done, ACTIVATION_TIMEOUT_MS);
      container.addEventListener("controllerchange", done);
      worker.postMessage({ type: WORKER_SKIP_WAITING });
    });
  }

  /** Another tab activated a build. This tab follows, but never over text still in its composer. */
  private async followReload(): Promise<void> {
    if (this.followingReload) return;
    this.followingReload = true;
    if (!this.options.isInputEmpty()) await this.watchIdle().done;
    await this.stopSession();
    this.reload();
  }
}

/**
 * The installer for `activateWebBundle` plans. Create it at startup, not when a plan arrives: it also
 * listens for builds other tabs activate.
 */
export function createWebUpdateInstaller(options: WebUpdateInstallerOptions): FlareUpdateInstaller {
  return new WebUpdateInstaller(options);
}
