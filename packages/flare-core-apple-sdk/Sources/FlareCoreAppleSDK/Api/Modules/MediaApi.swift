import Foundation

/// GENERATED. Do not edit by hand.
/// Media access URL and local cache operations.
public protocol MediaApiProtocol: AnyObject {
    func uploadFile(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func uploadImage(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func uploadVideo(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func uploadBytes(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func deleteFile(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func getMediaUrl(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func resolveAttachment(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func getTempDownloadUrl(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func resolveMediaAccess(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func cacheRemoteMedia(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func getMediaCacheStats() async throws -> [String: AnySendable]
    func setMediaCacheMaxBytes(_ request: [String: AnySendable]) async throws -> Void
    func setMediaCacheRoot(_ request: [String: AnySendable]) async throws -> Void
    func clearMediaCache() async throws -> Void
    func getUserDownloadSubfolder() async throws -> [String: AnySendable]
    func setUserDownloadSubfolder(_ request: [String: AnySendable]) async throws -> Void
    func getUserDownloadSavedPath(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func deleteUserDownloadRecord(_ request: [String: AnySendable]) async throws -> Void
    func getUserDownloadDirectory() async throws -> [String: AnySendable]
    func setUserDownloadDirectory(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func downloadToUserDirectory(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func uploadRecovery(_ request: MediaUploadRecoveryRequest) async throws -> MediaUploadRecovery
    func cancelUpload(_ request: MediaTransferRequest) async throws -> MediaTransferCancellation
    func cancelTransfer(_ request: MediaTransferRequest) async throws -> MediaTransferCancellation
    func cancelUserFileDownload(_ request: [String: AnySendable]) async throws -> Bool
    func downloadFileToDownloads(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
}
