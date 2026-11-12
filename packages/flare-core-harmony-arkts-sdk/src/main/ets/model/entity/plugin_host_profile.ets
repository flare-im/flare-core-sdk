// GENERATED. Do not edit by hand.

/** The plugin UI a host can draw. */
export interface PluginHostProfile {
  /** wire: `platform`. web, tauri, android, ios, flutter or harmonyos. */
  platform: string;
  /** wire: `kitVocabulary`. The kit's PLUGIN_UI_VOCABULARY. */
  kitVocabulary: Record<string, Object>;
  /** wire: `nativeAllowlist`. Native capabilities this host grants plugin actions. */
  nativeAllowlist?: Array<string>;
  /** wire: `bundleRuntime`. {bridge, engine, engineMajor} when the host can open web bundles. */
  bundleRuntime?: Record<string, Object>;
}
