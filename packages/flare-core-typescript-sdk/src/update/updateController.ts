import { browserLifecycleSources, type AppStateSource } from "../lifecycle/platformLifecycle";
import { AppState } from "../model/app_state";
import type { UpdateInstallPlan } from "../model/update_install_plan";
import type { UpdateProgress } from "../model/update_progress";
import type { UpdateResourcePack } from "../model/update_resource_pack";
import type { UpdateStatus } from "../model/update_status";
import {
  resourcePacksFromWire,
  updateErrorCodeOf,
  updateInstallPlanFromWire,
  updatePromptFormOf,
  updateStatusFromWire,
  type UpdateErrorCode,
  type UpdateFallbackTarget,
  type UpdatePromptForm,
  type UpdatePromptView,
} from "./model";
import type { FlareUpdateApi } from "./updateApi";
import type { FlareUpdateInstaller, UpdateInstallResult } from "./updateInstaller";

/** A removal function, or an `EventSubscription` as `client.events.on*` return it. */
export type UpdateSubscription = (() => void) | { unsubscribe(): void };

export type UpdateSubscribe = (listener: (event: unknown) => void) => UpdateSubscription | Promise<UpdateSubscription>;

export interface FlareUpdateControllerOptions {
  api: FlareUpdateApi;
  installer: FlareUpdateInstaller;
  /** `update://state`. */
  subscribe: UpdateSubscribe;
  /** Login success. Events only reach the host while a session exists, so the state is read again then. */
  loginSucceeded?: UpdateSubscribe;
  /** Foreground and background; default the browser's. Null leaves foreground out. */
  appState?: AppStateSource | null;
  onError?: (error: unknown) => void;
}

const POLL_INTERVAL_MS = 500;
const METERED_CONFIRMATION = "update.meteredConfirmationRequired";
/** Transient states the core leaves on its own; without events the controller has to look. */
const POLLED_STATES: ReadonlySet<string> = new Set(["checking", "downloading", "verifying"]);
const CHECK_STATES: ReadonlySet<string> = new Set(["checking"]);
const DOWNLOAD_STATES: ReadonlySet<string> = new Set(["downloading", "verifying"]);
const NOTHING_TO_UPDATE: ReadonlySet<string> = new Set(["idle", "checking", "upToDate"]);
/** No store serves these channels: a failed update points to the website. */
const WEBSITE_DISTRIBUTIONS: ReadonlySet<string> = new Set(["direct", "web", "tauri", "electron"]);

/**
 * Whether a store ships this build. Stores forbid an app to update itself, so such a build has no updater. Unset is no
 * store: the binding then reports the channel of a build without one. `scripts/tauri-build-with-updater.mjs` draws the
 * same line.
 */
export function isStoreDistribution(distribution: string | null | undefined): boolean {
  const name = distribution?.trim() ?? "";
  return name !== "" && !WEBSITE_DISTRIBUTIONS.has(name);
}

/** A server refusal makes an update forced before any manifest names a release. */
function isForced(engine: UpdateStatus): boolean {
  return engine.state === "required" || engine.release?.mandatory === true;
}

/**
 * The update flow an app binds to: it shows `status` and wires the Kit's callbacks to these methods.
 *
 * The core owns the state, `prompt` and `readOnly` included. What the controller adds to `status` is
 * only what the core cannot know: the installer waiting for the person or a restart they put off
 * (`readyToInstall` both) and installer progress.
 *
 * Business failures never reject: they arrive in `status.error`, so the Kit's callbacks need no
 * try/catch. Only `start` rejects, when the first read of the state fails.
 */
export class FlareUpdateController {
  private engine: UpdateStatus | null = null;
  private readonly listeners = new Set<(status: UpdateStatus) => void>();
  private readonly removals: Array<() => void> = [];
  private starting: Promise<UpdateStatus> | null = null;
  private running: Promise<UpdateStatus> | null = null;
  private confirmation: { promise: Promise<boolean>; resolve(confirmed: boolean): void } | null = null;
  private installProgress: UpdateProgress | null = null;
  /** The restart the person put off: the install is in place, the next `update()` runs this. */
  private pendingRestart: (() => void | Promise<void>) | null = null;
  /** Set by `later()` during a download: the run ends at `readyToInstall`, no installer opens by itself. */
  private stopBeforeInstall = false;
  /** Calls waiting for the core to leave `states`; polling gets them out when no event comes. */
  private waiters: Array<{ states: ReadonlySet<string>; resolve(): void }> = [];
  private autoUpdatedRelease: string | null = null;
  private pollTimer: ReturnType<typeof setTimeout> | null = null;
  /** Counts `update://state` events: a read overtaken by one is older than what it would replace. */
  private eventsSeen = 0;
  private disposed = false;

  constructor(private readonly options: FlareUpdateControllerOptions) {}

  /** The state to show; null until the first read. */
  get status(): UpdateStatus | null {
    const engine = this.engine;
    if (!engine) return null;
    let status = engine;
    if (this.installProgress) status = { ...status, progress: this.installProgress };
    if (this.confirmation || this.pendingRestart) status = { ...status, state: "readyToInstall", progress: undefined };
    return status;
  }

  /** Whether the failure prompt offers retrying. */
  get errorRetryable(): boolean {
    return this.engine?.error?.retryable === true;
  }

  /** Where the failure prompt's other way out leads; the address is `status.error.fallbackUrl`. */
  get fallbackTarget(): UpdateFallbackTarget {
    return WEBSITE_DISTRIBUTIONS.has(this.engine?.current.distribution ?? "") ? "website" : "store";
  }

  /** Whether the prompt offers browsing on: a forced update that does not block the UI. */
  get canContinueReadOnly(): boolean {
    const engine = this.engine;
    return engine !== null && isForced(engine) && !engine.blockUi;
  }

  /** What the prompt shows now, under the Kit's prop names; null while no prompt is open. */
  get promptView(): UpdatePromptView | null {
    const status = this.status;
    const form = status ? updatePromptFormOf(status.prompt) : null;
    if (!status || !form) return null;
    const { release } = status;
    return {
      form,
      version: release?.version ?? "",
      notes: release?.notes ?? [],
      sizeBytes: release?.sizeBytes,
      mandatory: isForced(status),
      state: status.state,
      progress: status.progress,
      errorCode: status.error?.code,
      retryable: this.errorRetryable,
      fallbackTarget: this.fallbackTarget,
      canContinueReadOnly: this.canContinueReadOnly,
      reason: status.blockReason,
    };
  }

  /** Calls `listener` with every new status; returns its removal. */
  subscribe(listener: (status: UpdateStatus) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Subscribes and reads the state. Repeat calls share the first; every other method runs it itself. */
  start(): Promise<UpdateStatus> {
    this.starting ??= this.begin().catch((error: unknown) => {
      this.removeSubscriptions();
      this.starting = null;
      throw error;
    });
    return this.starting;
  }

  /** Reads the state from the core. */
  refresh(): Promise<UpdateStatus> {
    return this.read({});
  }

  /**
   * The person asked for a check; the core's own checks need no call. The core answers `checking` at once and runs the
   * round by itself, so this ends when the state has left `checking`, not with that answer.
   */
  async check(): Promise<UpdateStatus> {
    await this.start();
    await this.call(() => this.options.api.check({ manual: true }), "update.manifestUnavailable");
    await this.settled(CHECK_STATES);
    return this.snapshot();
  }

  /**
   * The language of the app, which the system's need not be: release notes and the block reason follow it at once.
   * Call it when the app knows its language and whenever that changes.
   */
  async setLocale(locale: string): Promise<UpdateStatus> {
    await this.start();
    return this.call(() => this.options.api.setLocale({ locale }));
  }

  /**
   * This run's resource packs, for the Kit to lay over what is built in. The app is whole without them, so a failed read
   * goes to `onError` and answers none. The core reads them once at start: a pack that arrives later waits for the next
   * run. Independent of `start()`.
   */
  async loadResources(): Promise<UpdateResourcePack[]> {
    try {
      return resourcePacksFromWire(await this.options.api.getResources({}));
    } catch (error) {
      this.options.onError?.(error);
      return [];
    }
  }

  /**
   * Download if needed, `update.install`, carry out the plan, `update.report_install`. It is also the
   * answer to everything the flow asks: while the installer waits it confirms, after a metered
   * refusal it allows the download, after a failure it retries, after a put-off restart it restarts.
   */
  update(): Promise<UpdateStatus> {
    this.stopBeforeInstall = false;
    this.settleConfirmation(true);
    this.running ??= this.runUpdate().finally(() => {
      this.running = null;
      // A forced release that arrived during this run found it busy.
      this.autoUpdate();
    });
    return this.running;
  }

  /**
   * `update.defer`; what it means in this phase is the core's call. An install waiting for the person
   * ends first, except a forced one, which does not wait on them alone.
   */
  async later(): Promise<UpdateStatus> {
    await this.start();
    const engine = this.currentEngine();
    if (DOWNLOAD_STATES.has(engine.state)) this.stopBeforeInstall = true;
    if (this.confirmation && !isForced(engine)) await this.leaveConfirmation();
    return this.call(() => this.options.api.defer());
  }

  /** Skips the version on offer. */
  async skip(): Promise<UpdateStatus> {
    await this.start();
    const release = this.currentEngine().release;
    if (!release) return this.snapshot();
    if (this.confirmation) await this.leaveConfirmation();
    return this.call(() => this.options.api.skip({ build: release.build }));
  }

  /** Call when the prompt really opened; the frequency rules count on it. Default form: `status.prompt`. */
  async markPrompted(form?: UpdatePromptForm): Promise<UpdateStatus> {
    await this.start();
    const engine = this.currentEngine();
    const shown = form ?? updatePromptFormOf(engine.prompt);
    if (!shown) return this.snapshot();
    // A forced update has no release until a manifest arrives: the prompt is then about no build.
    const build = engine.release?.build;
    return this.call(() => this.options.api.markPrompted(build === undefined ? { form: shown } : { build, form: shown }));
  }

  /**
   * The person chose to browse on under a forced update. It is `update.defer`: the core hides the prompt and turns
   * read-only until the app next comes forward or starts.
   */
  async continueReadOnly(): Promise<UpdateStatus> {
    await this.start();
    if (!this.canContinueReadOnly) return this.snapshot();
    return this.call(() => this.options.api.defer());
  }

  /** Removes every subscription; an install waiting for the person ends as put off. */
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.stopPolling();
    this.removeSubscriptions();
    this.settleConfirmation(false);
    this.releaseWaiters(null);
    this.options.installer.dispose?.();
    this.listeners.clear();
  }

  private async begin(): Promise<UpdateStatus> {
    const { subscribe, loginSucceeded } = this.options;
    await this.hold(subscribe((payload) => {
      this.eventsSeen += 1;
      this.adopt(payload);
    }));
    if (loginSucceeded) await this.hold(loginSucceeded(() => this.refreshQuietly()));
    const appState = this.options.appState === undefined ? browserLifecycleSources().appState : this.options.appState;
    if (appState) {
      this.removals.push(appState.subscribe((state) => {
        if (state === AppState.Foreground) this.refreshQuietly({ foreground: true });
      }));
    }
    return this.refresh();
  }

  private async read(request: { foreground?: boolean }): Promise<UpdateStatus> {
    const seen = this.eventsSeen;
    const answer = await this.options.api.getState(request);
    return seen === this.eventsSeen ? this.adopt(answer) : this.snapshot();
  }

  private async hold(subscription: UpdateSubscription | Promise<UpdateSubscription>): Promise<void> {
    const resolved = await subscription;
    const remove = typeof resolved === "function" ? resolved : () => resolved.unsubscribe();
    if (this.disposed) remove();
    else this.removals.push(remove);
  }

  private removeSubscriptions(): void {
    for (const remove of this.removals.splice(0)) {
      try {
        remove();
      } catch (error) {
        this.options.onError?.(error);
      }
    }
  }

  private refreshQuietly(request: { foreground?: boolean } = {}): void {
    this.read(request).catch((error: unknown) => this.options.onError?.(error));
  }

  private async runUpdate(): Promise<UpdateStatus> {
    await this.start();
    if (this.pendingRestart) return this.restart(this.pendingRestart);
    const engine = this.currentEngine();
    // Refused by the server before any manifest arrived: find the release instead of doing nothing.
    if (!engine.release && engine.state === "required") return this.check();
    if (!engine.release || NOTHING_TO_UPDATE.has(engine.state)) return this.snapshot();
    try {
      if (engine.release.kind === "package" && !(await this.downloaded())) return this.snapshot();
      let answer: unknown;
      try {
        answer = await this.options.api.install();
      } catch (error) {
        return await this.installRefused(error);
      }
      const plan = updateInstallPlanFromWire(answer);
      // `update.install` answers the plan, not a status, and events may not be arriving.
      this.publish({ ...this.currentEngine(), state: "installing" });
      await this.finishInstall(await this.execute(plan));
    } catch (error) {
      return this.fail(error, "update.installFailed");
    }
    return this.snapshot();
  }

  /** The restart stays on offer if it fails: the install is still in place. */
  private async restart(run: () => void | Promise<void>): Promise<UpdateStatus> {
    try {
      await run();
    } catch (error) {
      return this.fail(error, "update.installFailed");
    }
    return this.snapshot();
  }

  /**
   * `update.install` refuses with the bare code. The rest of the error, the way out in `fallbackUrl` above all, is in
   * the state it left, and with no session no event brings it.
   */
  private async installRefused(error: unknown): Promise<UpdateStatus> {
    const failed = this.fail(error, "update.installFailed");
    try {
      const state = updateStatusFromWire(await this.options.api.getState({}));
      return this.publish(state.error ? state : { ...state, error: failed.error });
    } catch (readError) {
      this.options.onError?.(readError);
      return failed;
    }
  }

  /** Whether the package is verified and the flow should go on to install it. */
  private async downloaded(): Promise<boolean> {
    const engine = this.currentEngine();
    if (engine.state === "readyToInstall" || engine.state === "installing") return true;
    if (!DOWNLOAD_STATES.has(engine.state)) {
      try {
        const allowMetered = engine.error?.code === METERED_CONFIRMATION;
        this.adopt(await this.options.api.download({ allowMetered }));
      } catch (error) {
        this.fail(error, "update.downloadFailed");
        return false;
      }
    }
    await this.settled(DOWNLOAD_STATES);
    return this.currentEngine().state === "readyToInstall" && !this.stopBeforeInstall;
  }

  private settled(states: ReadonlySet<string>): Promise<void> {
    if (!states.has(this.currentEngine().state)) return Promise.resolve();
    return new Promise((resolve) => this.waiters.push({ states, resolve }));
  }

  /** Lets go of the waits `state` has left; null, on dispose, of all of them. */
  private releaseWaiters(state: string | null): void {
    const waiting = this.waiters;
    this.waiters = [];
    for (const waiter of waiting) {
      if (state !== null && waiter.states.has(state)) this.waiters.push(waiter);
      else waiter.resolve();
    }
  }

  private async execute(plan: UpdateInstallPlan): Promise<UpdateInstallResult> {
    try {
      return await this.options.installer.execute(plan, {
        waitForConfirmation: () => this.waitForConfirmation(),
        setProgress: (progress) => {
          this.installProgress = progress;
          this.emit();
        },
      });
    } catch (error) {
      this.options.onError?.(error);
      const code = updateErrorCodeOf(error) as UpdateErrorCode | undefined;
      return { outcome: "failed", code: code ?? "update.installFailed" };
    } finally {
      this.installProgress = null;
      this.settleConfirmation(false);
    }
  }

  /** Reports the outcome, then lets the installer end the process. A lost report must not stop that. */
  private async finishInstall(result: UpdateInstallResult): Promise<void> {
    const { outcome, code } = result;
    if (result.restart) this.pendingRestart = result.restart;
    try {
      this.adopt(await this.options.api.reportInstall(code === undefined ? { outcome } : { outcome, code }));
    } catch (error) {
      this.options.onError?.(error);
    }
    try {
      await result.finish?.();
    } catch (error) {
      this.options.onError?.(error);
    }
  }

  private waitForConfirmation(): Promise<boolean> {
    if (this.confirmation) return this.confirmation.promise;
    let resolve: (confirmed: boolean) => void = () => undefined;
    const promise = new Promise<boolean>((settle) => {
      resolve = settle;
    });
    this.confirmation = { promise, resolve };
    this.emit();
    return promise;
  }

  private settleConfirmation(confirmed: boolean): void {
    const confirmation = this.confirmation;
    if (!confirmation) return;
    this.confirmation = null;
    confirmation.resolve(confirmed);
    this.emit();
  }

  /** Ends the waiting install as put off and lets it report. */
  private async leaveConfirmation(): Promise<void> {
    this.settleConfirmation(false);
    await this.running;
  }

  /** A forced web update needs nobody's click: the installer waits for an idle page by itself. */
  private autoUpdate(): void {
    const engine = this.engine;
    if (this.disposed || this.running || engine?.state !== "required") return;
    const release = engine.release;
    if (release?.kind !== "webBundle" || this.autoUpdatedRelease === release.releaseId) return;
    this.autoUpdatedRelease = release.releaseId;
    this.update().catch((error: unknown) => this.options.onError?.(error));
  }

  private async call(request: () => Promise<unknown>, fallback?: UpdateErrorCode): Promise<UpdateStatus> {
    try {
      return this.adopt(await request());
    } catch (error) {
      return this.fail(error, fallback);
    }
  }

  /** Puts a failure the core threw instead of returning into the status; the next status replaces it. */
  private fail(error: unknown, fallback?: UpdateErrorCode): UpdateStatus {
    this.options.onError?.(error);
    const engine = this.currentEngine();
    const code = updateErrorCodeOf(error) ?? fallback;
    if (code === undefined) return this.snapshot();
    return this.publish({
      ...engine,
      error: { code, retryable: true, fallbackUrl: engine.error?.fallbackUrl },
    });
  }

  private adopt(raw: unknown): UpdateStatus {
    return this.publish(updateStatusFromWire(raw));
  }

  private publish(engine: UpdateStatus): UpdateStatus {
    this.engine = engine;
    this.releaseWaiters(engine.state);
    this.armPoll();
    this.autoUpdate();
    this.emit();
    return this.snapshot();
  }

  /** Every status restarts the wait: events flowing keep the timer from ever firing. */
  private armPoll(): void {
    this.stopPolling();
    if (this.disposed || !this.engine || !POLLED_STATES.has(this.engine.state)) return;
    this.pollTimer = setTimeout(() => {
      this.pollTimer = null;
      this.refresh().catch((error: unknown) => {
        this.options.onError?.(error);
        this.armPoll();
      });
    }, POLL_INTERVAL_MS);
  }

  private stopPolling(): void {
    if (this.pollTimer !== null) clearTimeout(this.pollTimer);
    this.pollTimer = null;
  }

  private emit(): void {
    const status = this.status;
    if (!status || this.disposed) return;
    for (const listener of [...this.listeners]) {
      try {
        listener(status);
      } catch (error) {
        this.options.onError?.(error);
      }
    }
  }

  private currentEngine(): UpdateStatus {
    if (!this.engine) throw new Error("the update state has not been read");
    return this.engine;
  }

  private snapshot(): UpdateStatus {
    const status = this.status;
    if (!status) throw new Error("the update state has not been read");
    return status;
  }
}
