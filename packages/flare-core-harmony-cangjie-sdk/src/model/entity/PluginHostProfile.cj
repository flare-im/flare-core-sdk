package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The plugin UI a host can draw.
public class PluginHostProfile {
    // wire: `platform`. web, tauri, android, ios, flutter or harmonyos.
    public let platform: String
    // wire: `kitVocabulary`. The kit's PLUGIN_UI_VOCABULARY.
    public let kitVocabulary: String
    // wire: `nativeAllowlist`. Optional. Native capabilities this host grants plugin actions.
    public let nativeAllowlist: ?String
    // wire: `bundleRuntime`. Optional. {bridge, engine, engineMajor} when the host can open web bundles.
    public let bundleRuntime: ?String

    public init(platform!: String, kitVocabulary!: String, nativeAllowlist!: ?String, bundleRuntime!: ?String) {
        this.platform = platform
        this.kitVocabulary = kitVocabulary
        this.nativeAllowlist = nativeAllowlist
        this.bundleRuntime = bundleRuntime
    }
}
