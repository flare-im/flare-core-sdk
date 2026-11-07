package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** What the platform package has to do. kind selects the fields that apply. */
data class UpdateInstallPlan(
    /** wire: `kind`. openStore, installPackage, activateWebBundle or desktopUpdater. */
    val kind: String = "",
    /** wire: `store`. openStore: play, appstore, testflight, appgallery or a store channel name. */
    val store: String? = null,
    /** wire: `url`. openStore: the store page. */
    val url: String? = null,
    /** wire: `packageName`. openStore: package name. */
    val packageName: String? = null,
    /** wire: `appId`. openStore: app id in the store. */
    val appId: String? = null,
    /** wire: `immediate`. openStore: the Play immediate flow. */
    val immediate: Boolean? = null,
    /** wire: `path`. installPackage: the verified file. */
    val path: String? = null,
    /** wire: `sha256`. installPackage and desktopUpdater: lowercase hex. */
    val sha256: String? = null,
    /** wire: `signingCertSha256`. installPackage: expected signing certificate. */
    val signingCertSha256: String? = null,
    /** wire: `build`. installPackage: build number. */
    val build: Long? = null,
    /** wire: `sizeBytes`. installPackage: file size. */
    val sizeBytes: Long? = null,
    /** wire: `buildId`. activateWebBundle: target build. */
    val buildId: String? = null,
    /** wire: `assetManifestUrls`. activateWebBundle: asset manifest addresses. */
    val assetManifestUrls: List<String>? = null,
    /** wire: `assetManifestSha256`. activateWebBundle: asset manifest hash. */
    val assetManifestSha256: String? = null,
    /** wire: `mandatory`. activateWebBundle: forced update. */
    val mandatory: Boolean? = null,
    /** wire: `blockUi`. activateWebBundle: blocks the interface. */
    val blockUi: Boolean? = null,
    /** wire: `version`. desktopUpdater: target version. */
    val version: String? = null,
    /** wire: `target`. desktopUpdater: desktop target. */
    val target: String? = null,
)
