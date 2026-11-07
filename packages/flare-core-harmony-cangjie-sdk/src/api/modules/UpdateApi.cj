package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors.
public interface UpdateApi {
    func getState(request: UpdateGetStateRequest): UpdateStatus
    func check(request: UpdateCheckRequest): UpdateStatus
    func download(request: UpdateDownloadRequest): UpdateStatus
    func install(): UpdateInstallPlan
    func reportInstall(request: UpdateReportInstallRequest): UpdateStatus
    func defer(): UpdateStatus
    func skip(request: UpdateSkipRequest): UpdateStatus
    func markPrompted(request: UpdateMarkPromptedRequest): UpdateStatus
    func setLocale(request: UpdateSetLocaleRequest): UpdateStatus
    func getResources(request: UpdateGetResourcesRequest): UpdateResources
}
