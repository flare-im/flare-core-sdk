import Foundation

/// GENERATED. Do not edit by hand.
/// What the platform package has to do. kind selects the fields that apply.
public struct UpdateInstallPlan: Codable, Sendable {
    /// wire: `kind`. openStore, installPackage, activateWebBundle or desktopUpdater.
    public let kind: String
    /// wire: `store`. openStore: play, appstore, testflight, appgallery or a store channel name.
    public let store: String?
    /// wire: `url`. openStore: the store page.
    public let url: String?
    /// wire: `packageName`. openStore: package name.
    public let packageName: String?
    /// wire: `appId`. openStore: app id in the store.
    public let appId: String?
    /// wire: `immediate`. openStore: the Play immediate flow.
    public let immediate: Bool?
    /// wire: `path`. installPackage: the verified file.
    public let path: String?
    /// wire: `sha256`. installPackage and desktopUpdater: lowercase hex.
    public let sha256: String?
    /// wire: `signingCertSha256`. installPackage: expected signing certificate.
    public let signingCertSha256: String?
    /// wire: `build`. installPackage: build number.
    public let build: UInt64?
    /// wire: `sizeBytes`. installPackage: file size.
    public let sizeBytes: UInt64?
    /// wire: `buildId`. activateWebBundle: target build.
    public let buildId: String?
    /// wire: `assetManifestUrls`. activateWebBundle: asset manifest addresses.
    public let assetManifestUrls: [String]?
    /// wire: `assetManifestSha256`. activateWebBundle: asset manifest hash.
    public let assetManifestSha256: String?
    /// wire: `mandatory`. activateWebBundle: forced update.
    public let mandatory: Bool?
    /// wire: `blockUi`. activateWebBundle: blocks the interface.
    public let blockUi: Bool?
    /// wire: `version`. desktopUpdater: target version.
    public let version: String?
    /// wire: `target`. desktopUpdater: desktop target.
    public let target: String?

    public init(kind: String = "", store: String? = nil, url: String? = nil, packageName: String? = nil, appId: String? = nil, immediate: Bool? = nil, path: String? = nil, sha256: String? = nil, signingCertSha256: String? = nil, build: UInt64? = nil, sizeBytes: UInt64? = nil, buildId: String? = nil, assetManifestUrls: [String]? = nil, assetManifestSha256: String? = nil, mandatory: Bool? = nil, blockUi: Bool? = nil, version: String? = nil, target: String? = nil) {
        self.kind = kind
        self.store = store
        self.url = url
        self.packageName = packageName
        self.appId = appId
        self.immediate = immediate
        self.path = path
        self.sha256 = sha256
        self.signingCertSha256 = signingCertSha256
        self.build = build
        self.sizeBytes = sizeBytes
        self.buildId = buildId
        self.assetManifestUrls = assetManifestUrls
        self.assetManifestSha256 = assetManifestSha256
        self.mandatory = mandatory
        self.blockUi = blockUi
        self.version = version
        self.target = target
    }
}
