import Foundation

/// GENERATED. Do not edit by hand.
public final class DefaultUpdateApi: UpdateApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func getState(_ request: UpdateGetStateRequest) async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateGetState, request: updateGetStateRequestToMap(request))
        return try updateStatusFromJson(raw)
    }

    public func check(_ request: UpdateCheckRequest) async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateCheck, request: updateCheckRequestToMap(request))
        return try updateStatusFromJson(raw)
    }

    public func download(_ request: UpdateDownloadRequest) async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateDownload, request: updateDownloadRequestToMap(request))
        return try updateStatusFromJson(raw)
    }

    public func install() async throws -> UpdateInstallPlan {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateInstall, request: nil)
        return try updateInstallPlanFromJson(raw)
    }

    public func reportInstall(_ request: UpdateReportInstallRequest) async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateReportInstall, request: updateReportInstallRequestToMap(request))
        return try updateStatusFromJson(raw)
    }

    public func `defer`() async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateDefer, request: nil)
        return try updateStatusFromJson(raw)
    }

    public func skip(_ request: UpdateSkipRequest) async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateSkip, request: updateSkipRequestToMap(request))
        return try updateStatusFromJson(raw)
    }

    public func markPrompted(_ request: UpdateMarkPromptedRequest) async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateMarkPrompted, request: updateMarkPromptedRequestToMap(request))
        return try updateStatusFromJson(raw)
    }

    public func setLocale(_ request: UpdateSetLocaleRequest) async throws -> UpdateStatus {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateSetLocale, request: updateSetLocaleRequestToMap(request))
        return try updateStatusFromJson(raw)
    }

    public func getResources(_ request: UpdateGetResourcesRequest) async throws -> UpdateResources {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.updateGetResources, request: updateGetResourcesRequestToMap(request))
        return try updateResourcesFromJson(raw)
    }
}
