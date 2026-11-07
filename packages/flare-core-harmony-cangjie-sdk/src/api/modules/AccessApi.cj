package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page.
public interface AccessApi {
    func getStatus(): AccessStatus
    func listAccessPoints(): Array<AccessPointInfo>
    func pin(request: AccessPinRequest): AccessPin
    func unpin(): Unit
    func refresh(): AccessRefreshReport
    func importRecovery(request: AccessImportRecoveryRequest): AccessRecoveryImport
    func exportDiagnostics(): JsonValue
}
