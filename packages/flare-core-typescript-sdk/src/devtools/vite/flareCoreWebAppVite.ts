export type FlareCoreWebAppViteOptions = {
  appDir: string;
  serverPort: number;
  defineConfig: (config: (context: { mode: string }) => Record<string, unknown>) => unknown;
  loadEnv: (mode: string, envDir: string, prefixes: string) => Record<string, string>;
  vuePlugin: () => unknown;
  extraAliases?: unknown[];
  extraDefine?: Record<string, unknown>;
  /**
   * The distribution the core reports on CONNECT when `VITE_FLARE_DISTRIBUTION` is unset, e.g.
   * `electron` for a renderer packaged in the Electron shell. Empty: the core reports `web`.
   */
  appDistribution?: string;
  /**
   * Directory holding flare-core-sdk-engine and flare-im-design. Defaults to the nearest such
   * directory above this SDK package, then above `appDir`.
   */
  workspaceRoot?: string;
  /** wasm-bindgen output served at /flare-core-wasm/. Defaults to the engine's bindings/wasm/pkg. */
  wasmBindingRoot?: string;
  /** SDK sources the `@flare-im/sdk` aliases point at. Defaults to this package's own src. */
  sdkSourceRoot?: string;
  /** Give it on a web app: production builds then carry a build id, `asset-manifest.json` and `sw.js`. */
  webUpdate?: Pick<FlareWebUpdateBuildOptions, "viteBuild" | "serviceWorkerEntry">;
};

export type FlareWebUpdateBuildOptions = {
  buildId: string;
  /** Vite's `build`. */
  viteBuild: (config: Record<string, unknown>) => Promise<unknown>;
  /** The Service Worker's source, relative to the app. Default `src/sw.ts`. */
  serviceWorkerEntry?: string;
  /** Directories of the output holding files of this build with no content hash in their name. */
  pinned?: string[];
  /** The query strings the page asks for some of them with, by path relative to the output. */
  assetQueries?: Record<string, string>;
};

export type WriteWebUpdateFilesOptions = {
  outDir: string;
  base?: string;
  buildId: string;
  assetsDir?: string;
  pinned?: string[];
  assetQueries?: Record<string, string>;
};

export declare function createFlareCoreWebAppViteConfig(options: FlareCoreWebAppViteOptions): unknown;
/** The Vite plugin behind `webUpdate`, for apps with a Vite config of their own. */
export declare function flareWebUpdateBuild(options: FlareWebUpdateBuildOptions): unknown;
/** `VITE_FLARE_WEB_BUILD_ID`, else the day and a random suffix. */
export declare function resolveWebBuildId(env?: Record<string, string | undefined>, now?: Date): string;
export declare function writeWebUpdateFiles(options: WriteWebUpdateFilesOptions): Promise<{ manifest: unknown; sha256: string }>;
