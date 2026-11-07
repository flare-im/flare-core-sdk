import type { UpdateInstallPlan, UpdateProgress } from "../model";
import type { UpdateErrorCode, UpdateInstallOutcome } from "./model";

/** What the controller lends an installer while it carries out a plan. */
export interface UpdateInstallContext {
  /**
   * Shows `readyToInstall` and waits for the person: true once they confirm with
   * `controller.update()`, false when they put it off or the controller is disposed.
   */
  waitForConfirmation(): Promise<boolean>;
  /** Progress of work the installer does itself, shown as `status.progress`; null clears it. */
  setProgress(progress: UpdateProgress | null): void;
}

export interface UpdateInstallResult {
  outcome: UpdateInstallOutcome;
  code?: UpdateErrorCode;
  /**
   * Runs after the outcome reached `update.report_install`: the reload or relaunch that ends this
   * process, which would otherwise take the report down with it.
   */
  finish?(): void | Promise<void>;
  /**
   * The install is in place and only the restart was put off. The controller keeps it: the status stays
   * `readyToInstall`, and the next `controller.update()` runs it.
   */
  restart?: () => void | Promise<void>;
}

/** Carries out an install plan with what the platform offers. Decides nothing about what to install. */
export interface FlareUpdateInstaller {
  execute(plan: UpdateInstallPlan, context: UpdateInstallContext): Promise<UpdateInstallResult>;
  /** Removes the listeners the installer holds; the controller calls it from its own dispose. */
  dispose?(): void;
}
