// GENERATED. Do not edit by hand.
// Module API: `update` — Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors.
import '../../model/model.dart';

/// Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors.
abstract interface class UpdateApi {
  /// getState maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.get_state`.
  Future<UpdateStatus> getState(UpdateGetStateRequest request);
  /// check maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.check`.
  Future<UpdateStatus> check(UpdateCheckRequest request);
  /// download maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.download`.
  Future<UpdateStatus> download(UpdateDownloadRequest request);
  /// install maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.install`.
  Future<UpdateInstallPlan> install();
  /// reportInstall maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.report_install`.
  Future<UpdateStatus> reportInstall(UpdateReportInstallRequest request);
  /// defer maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.defer`.
  Future<UpdateStatus> defer();
  /// skip maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.skip`.
  Future<UpdateStatus> skip(UpdateSkipRequest request);
  /// markPrompted maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.mark_prompted`.
  Future<UpdateStatus> markPrompted(UpdateMarkPromptedRequest request);
  /// setLocale maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.set_locale`.
  Future<UpdateStatus> setLocale(UpdateSetLocaleRequest request);
  /// getResources maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `update.get_resources`.
  Future<UpdateResources> getResources(UpdateGetResourcesRequest request);
}
