/**
 * Unified dev media proxy: Vite same-origin paths → gateway (50050) + object storage (29000).
 */

const DEV_MEDIA_API_PROXY_PREFIX = "/__flare-media-api";
const DEV_STORAGE_PROXY_PREFIX = "/__flare-storage";
export const DEFAULT_MEDIA_API_TARGET = "http://127.0.0.1:50050";
export const DEFAULT_STORAGE_PROXY_TARGETS = [
  "http://127.0.0.1:29000",
  "http://localhost:29000",
  "http://127.0.0.1:9000",
  "http://localhost:9000",
] as const;

export type WebMediaProxyEnv = {
  apiProxyPrefix: string;
  apiProxyTarget: string;
  storageProxyPrefix: string;
  storageProxyTargets: string[];
};

function readEnvRecord(env: Record<string, string | undefined>): WebMediaProxyEnv {
  const pick = (key: string, fallback: string) => {
    const value = env[key];
    return typeof value === "string" && value.trim() ? value.trim() : fallback;
  };
  const list = (key: string, fallback: readonly string[]) => {
    const raw = env[key];
    if (typeof raw !== "string" || !raw.trim()) return [...fallback];
    return raw.split(",").map((s) => s.trim()).filter(Boolean);
  };
  return {
    apiProxyPrefix: pick("VITE_MEDIA_API_PROXY_PREFIX", DEV_MEDIA_API_PROXY_PREFIX),
    apiProxyTarget: pick("VITE_MEDIA_API_PROXY_TARGET", DEFAULT_MEDIA_API_TARGET),
    storageProxyPrefix: pick("VITE_STORAGE_PROXY_PREFIX", DEV_STORAGE_PROXY_PREFIX),
    storageProxyTargets: list("VITE_STORAGE_PROXY_TARGETS", DEFAULT_STORAGE_PROXY_TARGETS),
  };
}

/** Browser: `import.meta.env` (Vite client bundle). */
export function resolveWebMediaProxyEnv(): WebMediaProxyEnv | undefined {
  const enabled =
    import.meta.env.DEV ||
    import.meta.env.MODE === "development" ||
    import.meta.env.VITE_ENABLE_MEDIA_PROXY === "true";
  if (!enabled) return undefined;
  const env: Record<string, string | undefined> = {};
  for (const [key, value] of Object.entries(import.meta.env)) {
    if (typeof value === "string") env[key] = value;
  }
  return readEnvRecord(env);
}

export function sdkMediaProxyFields(): {
  storageProxyPrefix?: string;
  storageProxyTargets?: string[];
} {
  const proxy = resolveWebMediaProxyEnv();
  if (!proxy) return {};
  return {
    storageProxyPrefix: proxy.storageProxyPrefix,
    storageProxyTargets: proxy.storageProxyTargets,
  };
}

/** Vite `server.proxy` — Node only (`loadEnv` in vite.config.ts). */
export function viteMediaProxyTable(
  env: Record<string, string | undefined> = {},
): Record<string, { target: string; changeOrigin: boolean; rewrite: (path: string) => string }> {
  const resolved = readEnvRecord({
    VITE_MEDIA_API_PROXY_PREFIX: DEV_MEDIA_API_PROXY_PREFIX,
    VITE_MEDIA_API_PROXY_TARGET: DEFAULT_MEDIA_API_TARGET,
    VITE_STORAGE_PROXY_PREFIX: DEV_STORAGE_PROXY_PREFIX,
    VITE_STORAGE_PROXY_TARGETS: DEFAULT_STORAGE_PROXY_TARGETS.join(","),
    ...env,
  });
  const apiPrefix = resolved.apiProxyPrefix.replace(/\/$/, "");
  const storagePrefix = resolved.storageProxyPrefix.replace(/\/$/, "");
  return {
    [apiPrefix]: {
      target: resolved.apiProxyTarget,
      changeOrigin: true,
      rewrite: (path) => path.slice(apiPrefix.length) || "/",
    },
    [storagePrefix]: {
      target: resolved.storageProxyTargets[0] ?? "http://127.0.0.1:29000",
      changeOrigin: true,
      rewrite: (path) => path.slice(storagePrefix.length) || "/",
    },
  };
}
