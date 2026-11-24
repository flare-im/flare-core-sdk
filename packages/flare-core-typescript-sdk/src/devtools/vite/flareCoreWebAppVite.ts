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
  /** Optional app plugins can use the resolved WASM output paths. */
  extraPlugins?: (context: {
    env: Record<string, string | undefined>;
    wasmAssetDirectory: string;
    wasmAssetQueries: Record<string, string>;
  }) => unknown[];
};

export declare function createFlareCoreWebAppViteConfig(options: FlareCoreWebAppViteOptions): unknown;
