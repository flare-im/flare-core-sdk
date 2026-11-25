package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Media access URL and local cache operations.
public interface MediaApi {
    func uploadFile(requestJson: String): String
    func uploadImage(requestJson: String): String
    func uploadVideo(requestJson: String): String
    func uploadBytes(requestJson: String): String
    func deleteFile(requestJson: String): String
    func getMediaUrl(requestJson: String): String
    func resolveAttachment(requestJson: String): String
    func getTempDownloadUrl(requestJson: String): String
    func resolveMediaAccess(requestJson: String): String
    func cacheRemoteMedia(requestJson: String): String
    func getMediaCacheStats(): String
    func setMediaCacheMaxBytes(requestJson: String): Unit
    func setMediaCacheRoot(requestJson: String): Unit
    func clearMediaCache(): Unit
    func getUserDownloadSubfolder(): String
    func setUserDownloadSubfolder(requestJson: String): Unit
    func getUserDownloadSavedPath(requestJson: String): String
    func deleteUserDownloadRecord(requestJson: String): Unit
    func getUserDownloadDirectory(): String
    func setUserDownloadDirectory(requestJson: String): String
    func downloadToUserDirectory(requestJson: String): String
    func uploadRecovery(request: MediaUploadRecoveryRequest): MediaUploadRecovery
    func cancelUpload(request: MediaTransferRequest): MediaTransferCancellation
    func cancelTransfer(request: MediaTransferRequest): MediaTransferCancellation
    func cancelUserFileDownload(requestJson: String): BooleanResponse
    func downloadFileToDownloads(requestJson: String): String
}
