// GENERATED. Do not edit by hand.

/// The plugin UI a host can draw.
final class PluginHostProfile {
  /// wire: `platform`. web, tauri, android, ios, flutter or harmonyos.
  final String platform;
  /// wire: `kitVocabulary`. The kit's PLUGIN_UI_VOCABULARY.
  final Map<String, Object?> kitVocabulary;
  /// wire: `nativeAllowlist`. Native capabilities this host grants plugin actions.
  final List<String>? nativeAllowlist;
  /// wire: `bundleRuntime`. {bridge, engine, engineMajor} when the host can open web bundles.
  final Map<String, Object?>? bundleRuntime;

  const PluginHostProfile({
    this.platform = '',
    this.kitVocabulary = const {},
    this.nativeAllowlist,
    this.bundleRuntime,
  });
}
