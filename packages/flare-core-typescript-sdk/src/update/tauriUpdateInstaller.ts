import type { UpdateInstallPlan } from "../model";
import { isDesktopUpdaterPlan } from "./model";
import type { FlareUpdateInstaller, UpdateInstallContext, UpdateInstallResult } from "./updateInstaller";

/** `DownloadEvent` of `@tauri-apps/plugin-updater`. */
export type TauriUpdateDownloadEvent =
  | { event: "Started"; data: { contentLength?: number } }
  | { event: "Progress"; data: { chunkLength: number } }
  | { event: "Finished" };

/** The parts of the plugin's `Update` the installer uses. */
export interface TauriUpdateHandle {
  readonly version: string;
  downloadAndInstall(onEvent?: (event: TauriUpdateDownloadEvent) => void): Promise<void>;
  close?(): Promise<void>;
}

export interface TauriUpdateInstallerOptions {
  /** `check` of `@tauri-apps/plugin-updater`; this package does not depend on the plugin. */
  check(): Promise<TauriUpdateHandle | null>;
  /**
   * `relaunch` of `@tauri-apps/plugin-process`, run once the person confirms the restart. Without
   * it the new version starts at the next launch.
   */
  relaunch?(): Promise<void>;
  /**
   * `openUrl` of `@tauri-apps/plugin-opener`: opens the store page of an `openStore` plan, the update path of a Mac
   * App Store or Microsoft Store build. Without it such a plan fails.
   */
  openUrl?(url: string): void | Promise<void>;
  onError?: (error: unknown) => void;
}

/** Progress reaches the prompt at this rate at most; the plugin reports every chunk. */
const PROGRESS_INTERVAL_MS = 200;

/**
 * The installer for `desktopUpdater` and `openStore` plans. A plan exists only when the core judged
 * the release available or required, so rollout and forced updates stay the core's call and the
 * updater is never asked on its own. Its endpoint serves the newest release, which need not be the
 * one this install was given: anything but the planned version is refused, not installed.
 */
export function createTauriUpdateInstaller(options: TauriUpdateInstallerOptions): FlareUpdateInstaller {
  const { check, relaunch, openUrl, onError } = options;

  /** Opening the page is all there is to do: the store installs, and the person may not go through with it. */
  async function openStore(url: string | undefined): Promise<UpdateInstallResult> {
    if (!url || !openUrl) return { outcome: "failed", code: "update.installFailed" };
    try {
      await openUrl(url);
      return { outcome: "completed" };
    } catch (error) {
      onError?.(error);
      return { outcome: "failed", code: "update.installFailed" };
    }
  }

  async function installPlanned(version: string, context: UpdateInstallContext): Promise<UpdateInstallResult | null> {
    let update: TauriUpdateHandle | null;
    try {
      update = await check();
    } catch (error) {
      onError?.(error);
      return { outcome: "failed", code: "update.downloadFailed" };
    }
    if (!update) return { outcome: "failed", code: "update.noArtifact" };
    try {
      if (update.version !== version) return { outcome: "failed", code: "update.noArtifact" };
      let received = 0;
      let total = 0;
      let reportedAt = 0;
      await update.downloadAndInstall((event) => {
        if (event.event === "Started") {
          total = event.data.contentLength ?? 0;
          context.setProgress({ received, total });
        } else if (event.event === "Progress") {
          received += event.data.chunkLength;
          const now = Date.now();
          if (now - reportedAt >= PROGRESS_INTERVAL_MS) {
            reportedAt = now;
            context.setProgress({ received, total });
          }
        }
      });
      return null;
    } catch (error) {
      onError?.(error);
      return { outcome: "failed", code: "update.installFailed" };
    } finally {
      context.setProgress(null);
      await update.close?.().catch((error: unknown) => onError?.(error));
    }
  }

  return {
    async execute(plan: UpdateInstallPlan, context: UpdateInstallContext): Promise<UpdateInstallResult> {
      if (plan.kind === "openStore") return openStore(plan.url);
      if (!isDesktopUpdaterPlan(plan)) return { outcome: "failed", code: "update.installFailed" };
      const failure = await installPlanned(plan.version, context);
      if (failure) return failure;
      if (!relaunch) return { outcome: "completed" };
      const confirmed = await context.waitForConfirmation();
      return confirmed
        ? { outcome: "completed", finish: () => relaunch() }
        : { outcome: "completed", restart: () => relaunch() };
    },
  };
}
