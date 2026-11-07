/**
 * What the update center adds to the generated models in `../model`. Those keep `state`, `prompt` and the like plain
 * strings, so a value a newer core sends passes through; the unions here name what this code branches on.
 *
 * Absent values are left out of a status. `updateStatusFromWire` also takes the core's form with null fields.
 */

import type {
  UpdateErrorInfo,
  UpdateInstallPlan,
  UpdateProgress,
  UpdateReleaseSummary,
  UpdateResourcePack,
  UpdateStatus,
} from "../model";

/** The prompts that really open on screen; `update.mark_prompted` counts these. */
export type UpdatePromptForm = "sheet" | "modal" | "fullscreen";

export type UpdateInstallOutcome = "started" | "completed" | "cancelled" | "failed";

/** Where the failure prompt sends people when retrying does not help. */
export type UpdateFallbackTarget = "website" | "store";

/** What an update prompt shows for one status, under the props of the Kit's `FlareUpdatePrompt`. */
export interface UpdatePromptView {
  form: UpdatePromptForm;
  /** Empty for a forced update no manifest named a release for yet. */
  version: string;
  notes: string[];
  sizeBytes?: number;
  mandatory: boolean;
  state: string;
  progress?: UpdateProgress;
  errorCode?: string;
  retryable: boolean;
  fallbackTarget: UpdateFallbackTarget;
  canContinueReadOnly: boolean;
  /** Why this build was blocked, in the reader's language; the forced prompt says it instead of its fixed words. */
  reason?: string;
}

export type UpdateErrorCode =
  | "update.manifestUnavailable"
  | "update.manifestRejected"
  | "update.noArtifact"
  | "update.meteredConfirmationRequired"
  | "update.insufficientSpace"
  | "update.downloadFailed"
  | "update.hashMismatch"
  | "update.installFailed"
  | "update.signatureMismatch"
  | "update.downgradeRejected"
  | "update.notSkippable";

/** A plan with what activating a web bundle needs: `kind` says which of the flat plan's fields are there. */
export type UpdateActivateWebBundlePlan = UpdateInstallPlan
  & Required<Pick<UpdateInstallPlan, "buildId" | "assetManifestUrls" | "assetManifestSha256">>;

/** A plan with what the desktop updater needs. */
export type UpdateDesktopUpdaterPlan = UpdateInstallPlan & Required<Pick<UpdateInstallPlan, "version">>;

const INSTALL_PLAN_KINDS: ReadonlySet<string> = new Set([
  "openStore",
  "installPackage",
  "activateWebBundle",
  "desktopUpdater",
]);

export function isActivateWebBundlePlan(plan: UpdateInstallPlan): plan is UpdateActivateWebBundlePlan {
  return plan.kind === "activateWebBundle"
    && Boolean(plan.buildId)
    && Boolean(plan.assetManifestSha256)
    && Array.isArray(plan.assetManifestUrls);
}

export function isDesktopUpdaterPlan(plan: UpdateInstallPlan): plan is UpdateDesktopUpdaterPlan {
  return plan.kind === "desktopUpdater" && Boolean(plan.version);
}

/** The form to open for `prompt`; null for `none`, `badge` and anything unknown. */
export function updatePromptFormOf(prompt: string): UpdatePromptForm | null {
  return prompt === "sheet" || prompt === "modal" || prompt === "fullscreen" ? prompt : null;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function textOrAbsent(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function numberOr(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function numberOrAbsent(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function textList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function releaseFromWire(value: unknown): UpdateReleaseSummary | undefined {
  if (value === null || value === undefined) return undefined;
  const record = asRecord(value);
  return {
    releaseId: text(record.releaseId),
    version: text(record.version),
    build: numberOr(record.build, 0),
    notes: textList(record.notes),
    sizeBytes: numberOrAbsent(record.sizeBytes),
    mandatory: record.mandatory === true,
    recommended: record.recommended === true,
    kind: text(record.kind),
  };
}

function progressFromWire(value: unknown): UpdateProgress | undefined {
  if (value === null || value === undefined) return undefined;
  const record = asRecord(value);
  return { received: numberOr(record.received, 0), total: numberOr(record.total, 0) };
}

function errorFromWire(value: unknown): UpdateErrorInfo | undefined {
  if (value === null || value === undefined) return undefined;
  const record = asRecord(value);
  return {
    code: text(record.code),
    retryable: record.retryable === true,
    fallbackUrl: textOrAbsent(record.fallbackUrl),
  };
}

/** The status in `value`, an `update.*` answer or an `update://state` payload. */
export function updateStatusFromWire(value: unknown): UpdateStatus {
  const record = asRecord(value);
  const current = asRecord(record.current);
  return {
    state: text(record.state),
    current: {
      version: textOrAbsent(current.version),
      build: numberOrAbsent(current.build),
      channel: text(current.channel),
      distribution: textOrAbsent(current.distribution),
    },
    release: releaseFromWire(record.release),
    progress: progressFromWire(record.progress),
    prompt: text(record.prompt) || "none",
    blockUi: record.blockUi === true,
    readOnly: record.readOnly === true,
    lastCheckedAt: numberOrAbsent(record.lastCheckedAt),
    error: errorFromWire(record.error),
    blockReason: textOrAbsent(record.blockReason),
  };
}

/** The plan `update.install` answered. A plan of an unknown kind cannot be carried out, so it throws. */
export function updateInstallPlanFromWire(value: unknown): UpdateInstallPlan {
  const record = asRecord(value);
  if (typeof record.kind !== "string" || !INSTALL_PLAN_KINDS.has(record.kind)) {
    throw new Error(`unknown update install plan: ${String(record.kind)}`);
  }
  const fields = Object.entries(record).filter(([, field]) => field !== null);
  return Object.fromEntries(fields) as unknown as UpdateInstallPlan;
}

/** The packs in an `update.get_resources` answer, in the core's order. */
export function resourcePacksFromWire(value: unknown): UpdateResourcePack[] {
  const { packs } = asRecord(value);
  if (!Array.isArray(packs)) return [];
  return packs.map((pack: unknown) => {
    const record = asRecord(pack);
    return {
      id: text(record.id),
      kind: text(record.kind),
      packVersion: numberOr(record.packVersion, 0),
      contentJson: text(record.contentJson),
    };
  });
}

/**
 * The `update.*` code an SDK failure carries, whichever field the binding put it in; `update.install` throws it as the
 * error's text. Undefined for a failure from outside the update center.
 */
export function updateErrorCodeOf(error: unknown): string | undefined {
  const record = asRecord(error);
  for (const value of [record.code, record.reason, record.machineReason, record.message]) {
    if (typeof value === "string" && value.startsWith("update.")) return value;
  }
  return undefined;
}
