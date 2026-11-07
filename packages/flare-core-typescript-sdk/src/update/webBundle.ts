/**
 * What the page and the Service Worker share about a web bundle. Runs in both, so it touches no
 * `window`, `document` or `navigator`.
 *
 * `sw.js` is one generic script at the site root. A worker learns which build it is from its own
 * URL (`/sw.js?build=<buildId>&manifest=<url>&sha256=<hash>`), and a different query installs as a
 * new script. Rollout and rollback are therefore the same step: register the target's URL.
 */

import type { UpdateErrorCode } from "./model";

export const FLARE_UPDATE_CHANNEL = "flare-update";

export const FLARE_SHELL_CACHE_PREFIX = "flare-shell-";

/** Holds what a failed install leaves for the page; the page reads it once the worker is redundant. */
export const FLARE_UPDATE_STATE_CACHE = "flare-update-state";

export const INSTALL_FAILURE_KEY = "/__flare-update/install-failure";

export const WORKER_SKIP_WAITING = "flare-update:skip-waiting";

export const WEB_ASSET_MANIFEST_SCHEMA = "flare.web-assets.v1";

export interface WebAsset {
  /** The URL the page asks for, query included, same origin as the site. */
  url: string;
  /** Lowercase hex SHA-256 of the file. */
  sha256: string;
  size: number;
  /**
   * Where this build's file stays reachable when `url` does not pin it: `index.html`, and anything
   * else whose name carries no content hash, is overwritten by the next deployment. Defaults to `url`.
   */
  source?: string;
  /** Part of the shell: fetched and verified at install. The rest is cached on first use. */
  precache?: boolean;
}

export interface WebAssetManifest {
  schema: typeof WEB_ASSET_MANIFEST_SCHEMA;
  buildId: string;
  assets: WebAsset[];
}

/** What a worker's own URL says it is. */
export interface WebBundleTarget {
  buildId: string;
  /** Tried in order. */
  manifestUrls: string[];
  manifestSha256: string;
}

export interface WebBundleInstallFailure {
  buildId: string;
  code: UpdateErrorCode;
  /** The manifest or asset that failed. */
  url?: string;
}

export type UpdateChannelMessage =
  | { type: "installProgress"; buildId: string; received: number; total: number }
  | { type: "reload"; buildId: string };

/** The parts of `BroadcastChannel` the update center uses. */
export interface UpdateChannel {
  postMessage(message: UpdateChannelMessage): void;
  addEventListener(type: "message", listener: (event: { data: unknown }) => void): void;
  removeEventListener(type: "message", listener: (event: { data: unknown }) => void): void;
  close(): void;
}

export function openUpdateChannel(): UpdateChannel | null {
  return typeof BroadcastChannel === "function"
    ? new BroadcastChannel(FLARE_UPDATE_CHANNEL) as unknown as UpdateChannel
    : null;
}

export function shellCacheName(buildId: string): string {
  return `${FLARE_SHELL_CACHE_PREFIX}${buildId}`;
}

/** `scriptUrl` with the target in its query. */
export function workerScriptUrl(scriptUrl: string, target: WebBundleTarget): string {
  const query = new URLSearchParams();
  query.set("build", target.buildId);
  for (const url of target.manifestUrls) query.append("manifest", url);
  query.set("sha256", target.manifestSha256);
  return `${scriptUrl}?${query.toString()}`;
}

/** The target in a worker's script URL; null for a URL that names none. */
export function webBundleTargetOf(scriptUrl: string): WebBundleTarget | null {
  const query = new URL(scriptUrl, "https://flare.invalid/").searchParams;
  const buildId = query.get("build");
  const manifestUrls = query.getAll("manifest");
  const manifestSha256 = query.get("sha256");
  if (!buildId || manifestUrls.length === 0 || !manifestSha256) return null;
  return { buildId, manifestUrls, manifestSha256: manifestSha256.toLowerCase() };
}

export async function sha256Hex(data: ArrayBuffer): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  let hex = "";
  for (const byte of digest) hex += byte.toString(16).padStart(2, "0");
  return hex;
}

function assetFromJson(value: unknown): WebAsset {
  const record = value !== null && typeof value === "object" ? value as Record<string, unknown> : {};
  const { url, sha256, size, source, precache } = record;
  if (typeof url !== "string" || !url || typeof sha256 !== "string" || !sha256 || typeof size !== "number") {
    throw new Error("invalid web asset manifest entry");
  }
  return {
    url,
    sha256: sha256.toLowerCase(),
    size,
    ...(typeof source === "string" && source ? { source } : {}),
    ...(precache === true ? { precache: true } : {}),
  };
}

/** The manifest in `text`. Anything but a well-formed manifest of this schema throws. */
export function parseWebAssetManifest(text: string): WebAssetManifest {
  const value: unknown = JSON.parse(text);
  const record = value !== null && typeof value === "object" ? value as Record<string, unknown> : {};
  if (record.schema !== WEB_ASSET_MANIFEST_SCHEMA || typeof record.buildId !== "string" || !Array.isArray(record.assets)) {
    throw new Error("invalid web asset manifest");
  }
  return {
    schema: WEB_ASSET_MANIFEST_SCHEMA,
    buildId: record.buildId,
    assets: record.assets.map(assetFromJson),
  };
}
