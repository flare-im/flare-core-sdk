package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// What the platform package has to do. kind selects the fields that apply.
public class UpdateInstallPlan {
    // wire: `kind`. openStore, installPackage, activateWebBundle or desktopUpdater.
    public let kind: String
    // wire: `store`. Optional. openStore: play, appstore, testflight, appgallery or a store channel name.
    public let store: ?String
    // wire: `url`. Optional. openStore: the store page.
    public let url: ?String
    // wire: `packageName`. Optional. openStore: package name.
    public let packageName: ?String
    // wire: `appId`. Optional. openStore: app id in the store.
    public let appId: ?String
    // wire: `immediate`. Optional. openStore: the Play immediate flow.
    public let immediate: ?Bool
    // wire: `path`. Optional. installPackage: the verified file.
    public let path: ?String
    // wire: `sha256`. Optional. installPackage and desktopUpdater: lowercase hex.
    public let sha256: ?String
    // wire: `signingCertSha256`. Optional. installPackage: expected signing certificate.
    public let signingCertSha256: ?String
    // wire: `build`. Optional. installPackage: build number.
    public let build: ?UInt64
    // wire: `sizeBytes`. Optional. installPackage: file size.
    public let sizeBytes: ?UInt64
    // wire: `buildId`. Optional. activateWebBundle: target build.
    public let buildId: ?String
    // wire: `assetManifestUrls`. Optional. activateWebBundle: asset manifest addresses.
    public let assetManifestUrls: ?String
    // wire: `assetManifestSha256`. Optional. activateWebBundle: asset manifest hash.
    public let assetManifestSha256: ?String
    // wire: `mandatory`. Optional. activateWebBundle: forced update.
    public let mandatory: ?Bool
    // wire: `blockUi`. Optional. activateWebBundle: blocks the interface.
    public let blockUi: ?Bool
    // wire: `version`. Optional. desktopUpdater: target version.
    public let version: ?String
    // wire: `target`. Optional. desktopUpdater: desktop target.
    public let target: ?String

    public init(kind!: String, store!: ?String, url!: ?String, packageName!: ?String, appId!: ?String, immediate!: ?Bool, path!: ?String, sha256!: ?String, signingCertSha256!: ?String, build!: ?UInt64, sizeBytes!: ?UInt64, buildId!: ?String, assetManifestUrls!: ?String, assetManifestSha256!: ?String, mandatory!: ?Bool, blockUi!: ?Bool, version!: ?String, target!: ?String) {
        this.kind = kind
        this.store = store
        this.url = url
        this.packageName = packageName
        this.appId = appId
        this.immediate = immediate
        this.path = path
        this.sha256 = sha256
        this.signingCertSha256 = signingCertSha256
        this.build = build
        this.sizeBytes = sizeBytes
        this.buildId = buildId
        this.assetManifestUrls = assetManifestUrls
        this.assetManifestSha256 = assetManifestSha256
        this.mandatory = mandatory
        this.blockUi = blockUi
        this.version = version
        this.target = target
    }
}
