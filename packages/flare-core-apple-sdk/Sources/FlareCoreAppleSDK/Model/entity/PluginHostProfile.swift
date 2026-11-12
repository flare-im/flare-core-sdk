import Foundation

/// GENERATED. Do not edit by hand.
/// The plugin UI a host can draw.
public struct PluginHostProfile: Sendable {
    /// wire: `platform`. web, tauri, android, ios, flutter or harmonyos.
    public let platform: String
    /// wire: `kitVocabulary`. The kit's PLUGIN_UI_VOCABULARY.
    public let kitVocabulary: [String: AnySendable]
    /// wire: `nativeAllowlist`. Native capabilities this host grants plugin actions.
    public let nativeAllowlist: [String]?
    /// wire: `bundleRuntime`. {bridge, engine, engineMajor} when the host can open web bundles.
    public let bundleRuntime: [String: AnySendable]?

    public init(platform: String = "", kitVocabulary: [String: AnySendable] = [:], nativeAllowlist: [String]? = nil, bundleRuntime: [String: AnySendable]? = nil) {
        self.platform = platform
        self.kitVocabulary = kitVocabulary
        self.nativeAllowlist = nativeAllowlist
        self.bundleRuntime = bundleRuntime
    }
}
