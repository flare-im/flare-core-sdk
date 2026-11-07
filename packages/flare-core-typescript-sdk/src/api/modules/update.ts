/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `update` — Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors.
 */
import type { UpdateCheckRequest, UpdateDownloadRequest, UpdateGetResourcesRequest, UpdateGetStateRequest, UpdateInstallPlan, UpdateMarkPromptedRequest, UpdateReportInstallRequest, UpdateResources, UpdateSetLocaleRequest, UpdateSkipRequest, UpdateStatus } from '../../model';

/** Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors. */
export interface UpdateApi {
  /** getState maps to `flare_sdk_invoke_json`. Operation: `update.get_state`. */
  getState(request: UpdateGetStateRequest): Promise<UpdateStatus>;
  /** check maps to `flare_sdk_invoke_json`. Operation: `update.check`. */
  check(request: UpdateCheckRequest): Promise<UpdateStatus>;
  /** download maps to `flare_sdk_invoke_json`. Operation: `update.download`. */
  download(request: UpdateDownloadRequest): Promise<UpdateStatus>;
  /** install maps to `flare_sdk_invoke_json`. Operation: `update.install`. */
  install(): Promise<UpdateInstallPlan>;
  /** reportInstall maps to `flare_sdk_invoke_json`. Operation: `update.report_install`. */
  reportInstall(request: UpdateReportInstallRequest): Promise<UpdateStatus>;
  /** defer maps to `flare_sdk_invoke_json`. Operation: `update.defer`. */
  defer(): Promise<UpdateStatus>;
  /** skip maps to `flare_sdk_invoke_json`. Operation: `update.skip`. */
  skip(request: UpdateSkipRequest): Promise<UpdateStatus>;
  /** markPrompted maps to `flare_sdk_invoke_json`. Operation: `update.mark_prompted`. */
  markPrompted(request: UpdateMarkPromptedRequest): Promise<UpdateStatus>;
  /** setLocale maps to `flare_sdk_invoke_json`. Operation: `update.set_locale`. */
  setLocale(request: UpdateSetLocaleRequest): Promise<UpdateStatus>;
  /** getResources maps to `flare_sdk_invoke_json`. Operation: `update.get_resources`. */
  getResources(request: UpdateGetResourcesRequest): Promise<UpdateResources>;
}
