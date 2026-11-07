/**
 * App identity for CONNECT on browser runtimes: the version and build injected at build time,
 * filled into the init request's `app` keys the host left out. Free of the wasm runtime and of
 * every bridge, like the rest of `@flare-im/sdk/lifecycle`.
 */

/** App identity for CONNECT and the update center; fills the `sdkConfig.app` keys the host left out. */
export interface WebAppInfo {
  version?: string;
  build?: number;
  distribution?: string;
  /** Update channel (`stable`, `beta`). */
  channel?: string;
  /** The web build this page runs: the update center compares it, not `build`. */
  buildId?: string;
  /** Interface language (BCP-47); the release notes follow it. */
  locale?: string;
  /** Desktop target (`darwin-aarch64`). */
  target?: string;
}

declare const __FLARE_APP_VERSION__: string | undefined;
declare const __FLARE_APP_BUILD__: string | number | undefined;
declare const __FLARE_APP_CHANNEL__: string | undefined;
declare const __FLARE_WEB_BUILD_ID__: string | undefined;

/**
 * The app identity injected at build time (the Flare Vite config defines `__FLARE_APP_VERSION__` from the app's
 * package.json, `__FLARE_APP_BUILD__` from `VITE_FLARE_APP_BUILD`, `__FLARE_APP_CHANNEL__` from
 * `VITE_FLARE_APP_CHANNEL`, and `__FLARE_WEB_BUILD_ID__` on a production web build). Empty outside such a build; the
 * core then reports no version.
 */
export function webAppInfoFromBuild(): WebAppInfo {
  const version = typeof __FLARE_APP_VERSION__ === "string" ? __FLARE_APP_VERSION__.trim() : "";
  const channel = typeof __FLARE_APP_CHANNEL__ === "string" ? __FLARE_APP_CHANNEL__.trim() : "";
  const buildId = typeof __FLARE_WEB_BUILD_ID__ === "string" ? __FLARE_WEB_BUILD_ID__.trim() : "";
  const rawBuild = typeof __FLARE_APP_BUILD__ === "number" || typeof __FLARE_APP_BUILD__ === "string"
    ? Number(__FLARE_APP_BUILD__)
    : Number.NaN;
  return {
    ...(version ? { version } : {}),
    ...(Number.isSafeInteger(rawBuild) && rawBuild >= 0 ? { build: rawBuild } : {}),
    ...(channel ? { channel } : {}),
    ...(buildId ? { buildId } : {}),
  };
}

/**
 * `request` (an init request or its `sdkConfig`) with the `app` keys taken from `info` where the
 * host left them out: keys the host gave stay as given. With nothing to fill no `app` is added;
 * the core reports `distribution` as `web` when it stays unset.
 */
export function withWebAppInfo(request: unknown, info: WebAppInfo): unknown {
  if (!request || typeof request !== "object" || Array.isArray(request)) return request;
  const record = request as Record<string, unknown>;
  const sdkConfig = record.sdkConfig;
  if (sdkConfig && typeof sdkConfig === "object" && !Array.isArray(sdkConfig)) {
    return { ...record, sdkConfig: withWebAppInfo(sdkConfig, info) };
  }
  const given = record.app && typeof record.app === "object" && !Array.isArray(record.app)
    ? record.app as Record<string, unknown>
    : {};
  const app: Record<string, unknown> = { ...given };
  for (const key of ["version", "build", "distribution", "channel", "buildId", "locale", "target"] as const) {
    if ((app[key] === undefined || app[key] === null) && info[key] !== undefined) app[key] = info[key];
  }
  return Object.keys(app).length === 0 ? record : { ...record, app };
}
