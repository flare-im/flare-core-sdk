import Foundation

/// GENERATED. Do not edit by hand.
public final class DefaultMediaApi: MediaApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func uploadFile(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUploadFile, request: unwrapRequest(AnySendable(request)))
    }

    public func uploadImage(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUploadImage, request: unwrapRequest(AnySendable(request)))
    }

    public func uploadVideo(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUploadVideo, request: unwrapRequest(AnySendable(request)))
    }

    public func uploadBytes(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUploadBytes, request: unwrapRequest(AnySendable(request)))
    }

    public func deleteFile(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaDeleteFile, request: unwrapRequest(AnySendable(request)))
    }

    public func getMediaUrl(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaGetUrl, request: unwrapRequest(AnySendable(request)))
    }

    public func resolveAttachment(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaResolveAttachment, request: unwrapRequest(AnySendable(request)))
    }

    public func getTempDownloadUrl(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaTempDownloadUrl, request: unwrapRequest(AnySendable(request)))
    }

    public func resolveMediaAccess(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaResolveAccess, request: unwrapRequest(AnySendable(request)))
    }

    public func cacheRemoteMedia(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaCacheRemote, request: unwrapRequest(AnySendable(request)))
    }

    public func getMediaCacheStats() async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaCacheStats, request: nil)
    }

    public func setMediaCacheMaxBytes(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.mediaSetCacheMaxBytes, request: AnySendable(request))
    }

    public func setMediaCacheRoot(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.mediaSetCacheRoot, request: AnySendable(request))
    }

    public func clearMediaCache() async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.mediaClearCache, request: nil)
    }

    public func getUserDownloadSubfolder() async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUserDownloadGetSubfolder, request: nil)
    }

    public func setUserDownloadSubfolder(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.mediaUserDownloadSetSubfolder, request: AnySendable(request))
    }

    public func getUserDownloadSavedPath(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUserDownloadGetSavedPath, request: unwrapRequest(AnySendable(request)))
    }

    public func deleteUserDownloadRecord(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.mediaUserDownloadDeleteRecord, request: AnySendable(request))
    }

    public func getUserDownloadDirectory() async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUserDownloadGetDirectory, request: nil)
    }

    public func setUserDownloadDirectory(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaUserDownloadSetDirectory, request: unwrapRequest(AnySendable(request)))
    }

    public func downloadToUserDirectory(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaDownloadToUserDirectory, request: unwrapRequest(AnySendable(request)))
    }

    public func uploadRecovery(_ request: MediaUploadRecoveryRequest) async throws -> MediaUploadRecovery {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.mediaUploadRecovery, request: mediaUploadRecoveryRequestToMap(request))
        return try mediaUploadRecoveryFromJson(raw)
    }

    public func cancelUpload(_ request: MediaTransferRequest) async throws -> MediaTransferCancellation {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.mediaCancelUpload, request: mediaTransferRequestToMap(request))
        return try mediaTransferCancellationFromJson(raw)
    }

    public func cancelTransfer(_ request: MediaTransferRequest) async throws -> MediaTransferCancellation {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.mediaCancelTransfer, request: mediaTransferRequestToMap(request))
        return try mediaTransferCancellationFromJson(raw)
    }

    public func cancelUserFileDownload(_ request: [String: AnySendable]) async throws -> Bool {
        return try await invokeBool(bridge, descriptor: NativeCallMap.mediaCancelUserFileDownload, request: AnySendable(request))
    }

    public func downloadFileToDownloads(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.mediaDownloadFileToDownloads, request: unwrapRequest(AnySendable(request)))
    }
}
