/** GENERATED. Do not edit by hand. */

/** What the platform package has to do. kind selects the fields that apply. */
export interface UpdateInstallPlan {
  /** wire: `kind`. openStore, installPackage, activateWebBundle or desktopUpdater. */
  kind: string;
  /** wire: `store`. openStore: play, appstore, testflight, appgallery or a store channel name. */
  store?: string;
  /** wire: `url`. openStore: the store page. */
  url?: string;
  /** wire: `packageName`. openStore: package name. */
  packageName?: string;
  /** wire: `appId`. openStore: app id in the store. */
  appId?: string;
  /** wire: `immediate`. openStore: the Play immediate flow. */
  immediate?: boolean;
  /** wire: `path`. installPackage: the verified file. */
  path?: string;
  /** wire: `sha256`. installPackage and desktopUpdater: lowercase hex. */
  sha256?: string;
  /** wire: `signingCertSha256`. installPackage: expected signing certificate. */
  signingCertSha256?: string;
  /** wire: `build`. installPackage: build number. */
  build?: number;
  /** wire: `sizeBytes`. installPackage: file size. */
  sizeBytes?: number;
  /** wire: `buildId`. activateWebBundle: target build. */
  buildId?: string;
  /** wire: `assetManifestUrls`. activateWebBundle: asset manifest addresses. */
  assetManifestUrls?: string[];
  /** wire: `assetManifestSha256`. activateWebBundle: asset manifest hash. */
  assetManifestSha256?: string;
  /** wire: `mandatory`. activateWebBundle: forced update. */
  mandatory?: boolean;
  /** wire: `blockUi`. activateWebBundle: blocks the interface. */
  blockUi?: boolean;
  /** wire: `version`. desktopUpdater: target version. */
  version?: string;
  /** wire: `target`. desktopUpdater: desktop target. */
  target?: string;
}
