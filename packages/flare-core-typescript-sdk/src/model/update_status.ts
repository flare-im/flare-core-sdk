/** GENERATED. Do not edit by hand. */
import type { UpdateCurrentApp } from './update_current_app';
import type { UpdateErrorInfo } from './update_error_info';
import type { UpdateProgress } from './update_progress';
import type { UpdateReleaseSummary } from './update_release_summary';

/** Update center state: the update://state payload and the answer of every update.* call but install. */
export interface UpdateStatus {
  /** wire: `state`. idle, checking, upToDate, available, required, downloading, verifying, readyToInstall, installing or failed. */
  state: string;
  /** wire: `current`. The running app. */
  current: UpdateCurrentApp;
  /** wire: `release`. The release on offer. Can be absent in required: the server rejected this build and no manifest arrived yet. */
  release?: UpdateReleaseSummary;
  /** wire: `progress`. Present while downloading. */
  progress?: UpdateProgress;
  /** wire: `prompt`. none, badge, sheet, modal or fullscreen. The core keeps it through the whole flow; bind to it directly. */
  prompt: string;
  /** wire: `blockUi`. A forced update blocks the interface. */
  blockUi: boolean;
  /** wire: `readOnly`. The connection was refused with UPGRADE_REQUIRED or REST answered 426. */
  readOnly: boolean;
  /** wire: `lastCheckedAt`. Last successful check, Unix milliseconds. */
  lastCheckedAt?: number;
  /** wire: `error`. Why the last action did not go through. */
  error?: UpdateErrorInfo;
  /** wire: `blockReason`. Why this build is blocked, in the chosen language. Present when the current build falls in blockedBuilds and the range gives a reason; a forced prompt shows it ahead of the fixed text. */
  blockReason?: string;
}
