import Foundation

/// GENERATED. Do not edit by hand.
public final class DefaultAccessApi: AccessApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func getStatus() async throws -> AccessStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.accessGetStatus, request: nil)
        return try accessStatusFromJson(raw)
    }

    public func listAccessPoints() async throws -> [AccessPointInfo] {
        let raw = try await bridge.invoke(NativeCallMap.accessListAccessPoints, request: nil)
        return try accessPointInfoListFromJson(raw.value)
    }

    public func pin(_ request: AccessPinRequest) async throws -> AccessPin {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.accessPin, request: accessPinRequestToMap(request))
        return try accessPinFromJson(raw)
    }

    public func unpin() async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.accessUnpin, request: nil)
    }

    public func refresh() async throws -> AccessRefreshReport {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.accessRefresh, request: nil)
        return try accessRefreshReportFromJson(raw)
    }

    public func importRecovery(_ request: AccessImportRecoveryRequest) async throws -> AccessRecoveryImport {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.accessImportRecovery, request: accessImportRecoveryRequestToMap(request))
        return try accessRecoveryImportFromJson(raw)
    }

    public func exportDiagnostics() async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.accessExportDiagnostics, request: nil)
    }
}
