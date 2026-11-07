// GENERATED. Do not edit by hand.

/// What the platform package has to do. kind selects the fields that apply.
final class UpdateInstallPlan {
  /// wire: `kind`. openStore, installPackage, activateWebBundle or desktopUpdater.
  final String kind;
  /// wire: `store`. openStore: play, appstore, testflight, appgallery or a store channel name.
  final String? store;
  /// wire: `url`. openStore: the store page.
  final String? url;
  /// wire: `packageName`. openStore: package name.
  final String? packageName;
  /// wire: `appId`. openStore: app id in the store.
  final String? appId;
  /// wire: `immediate`. openStore: the Play immediate flow.
  final bool? immediate;
  /// wire: `path`. installPackage: the verified file.
  final String? path;
  /// wire: `sha256`. installPackage and desktopUpdater: lowercase hex.
  final String? sha256;
  /// wire: `signingCertSha256`. installPackage: expected signing certificate.
  final String? signingCertSha256;
  /// wire: `build`. installPackage: build number.
  final int? build;
  /// wire: `sizeBytes`. installPackage: file size.
  final int? sizeBytes;
  /// wire: `buildId`. activateWebBundle: target build.
  final String? buildId;
  /// wire: `assetManifestUrls`. activateWebBundle: asset manifest addresses.
  final List<String>? assetManifestUrls;
  /// wire: `assetManifestSha256`. activateWebBundle: asset manifest hash.
  final String? assetManifestSha256;
  /// wire: `mandatory`. activateWebBundle: forced update.
  final bool? mandatory;
  /// wire: `blockUi`. activateWebBundle: blocks the interface.
  final bool? blockUi;
  /// wire: `version`. desktopUpdater: target version.
  final String? version;
  /// wire: `target`. desktopUpdater: desktop target.
  final String? target;

  const UpdateInstallPlan({
    this.kind = '',
    this.store,
    this.url,
    this.packageName,
    this.appId,
    this.immediate,
    this.path,
    this.sha256,
    this.signingCertSha256,
    this.build,
    this.sizeBytes,
    this.buildId,
    this.assetManifestUrls,
    this.assetManifestSha256,
    this.mandatory,
    this.blockUi,
    this.version,
    this.target,
  });
}
