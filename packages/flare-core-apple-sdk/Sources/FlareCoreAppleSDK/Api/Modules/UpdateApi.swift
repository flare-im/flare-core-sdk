import Foundation

/// GENERATED. Do not edit by hand.
/// Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors.
public protocol UpdateApiProtocol: AnyObject {
    func getState(_ request: UpdateGetStateRequest) async throws -> UpdateStatus
    func check(_ request: UpdateCheckRequest) async throws -> UpdateStatus
    func download(_ request: UpdateDownloadRequest) async throws -> UpdateStatus
    func install() async throws -> UpdateInstallPlan
    func reportInstall(_ request: UpdateReportInstallRequest) async throws -> UpdateStatus
    func `defer`() async throws -> UpdateStatus
    func skip(_ request: UpdateSkipRequest) async throws -> UpdateStatus
    func markPrompted(_ request: UpdateMarkPromptedRequest) async throws -> UpdateStatus
    func setLocale(_ request: UpdateSetLocaleRequest) async throws -> UpdateStatus
    func getResources(_ request: UpdateGetResourcesRequest) async throws -> UpdateResources
}
