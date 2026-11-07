import Foundation

/// GENERATED. Do not edit by hand.
/// Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page.
public protocol AccessApiProtocol: AnyObject {
    func getStatus() async throws -> AccessStatus
    func listAccessPoints() async throws -> [AccessPointInfo]
    func pin(_ request: AccessPinRequest) async throws -> AccessPin
    func unpin() async throws -> Void
    func refresh() async throws -> AccessRefreshReport
    func importRecovery(_ request: AccessImportRecoveryRequest) async throws -> AccessRecoveryImport
    func exportDiagnostics() async throws -> [String: AnySendable]
}
