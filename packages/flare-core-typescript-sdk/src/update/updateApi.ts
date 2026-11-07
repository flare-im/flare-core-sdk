import type {
  UpdateCheckRequest,
  UpdateDownloadRequest,
  UpdateGetResourcesRequest,
  UpdateGetStateRequest,
  UpdateMarkPromptedRequest,
  UpdateReportInstallRequest,
  UpdateSetLocaleRequest,
  UpdateSkipRequest,
} from "../model";

/**
 * The `update.*` operations the controller calls: `client.update`, or `social.update` on the social SDK. Answers stay
 * raw: the controller decodes them with `updateStatusFromWire`, `updateInstallPlanFromWire` and `resourcePacksFromWire`.
 */
export interface FlareUpdateApi {
  /** With `foreground` the core first does what coming forward does, so a late `lifecycle.set_app_state` changes nothing. */
  getState(request: UpdateGetStateRequest): Promise<unknown>;
  /** Picks the release notes and the block reason in this language at once. */
  setLocale(request: UpdateSetLocaleRequest): Promise<unknown>;
  /** Answers at once, `checking` while the round runs: the result arrives as a later status. */
  check(request: UpdateCheckRequest): Promise<unknown>;
  download(request: UpdateDownloadRequest): Promise<unknown>;
  /** Answers an `UpdateInstallPlan`; `getResources` answers the packs; every other operation answers an `UpdateStatus`. */
  install(): Promise<unknown>;
  reportInstall(request: UpdateReportInstallRequest): Promise<unknown>;
  defer(): Promise<unknown>;
  skip(request: UpdateSkipRequest): Promise<unknown>;
  markPrompted(request: UpdateMarkPromptedRequest): Promise<unknown>;
  /** The packs the core read at start, as `{ packs }`. Works before sign-in. */
  getResources(request: UpdateGetResourcesRequest): Promise<unknown>;
}
