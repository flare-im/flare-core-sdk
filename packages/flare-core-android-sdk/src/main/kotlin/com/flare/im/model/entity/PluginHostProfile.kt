package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** The plugin UI a host can draw. */
data class PluginHostProfile(
    /** wire: `platform`. web, tauri, android, ios, flutter or harmonyos. */
    val platform: String = "",
    /** wire: `kitVocabulary`. The kit's PLUGIN_UI_VOCABULARY. */
    val kitVocabulary: Map<String, Any?> = emptyMap(),
    /** wire: `nativeAllowlist`. Native capabilities this host grants plugin actions. */
    val nativeAllowlist: List<String>? = null,
    /** wire: `bundleRuntime`. {bridge, engine, engineMajor} when the host can open web bundles. */
    val bundleRuntime: Map<String, Any?>? = null,
)
