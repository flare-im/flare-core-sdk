package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
public class DefaultMediaApi <: MediaApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func uploadFile(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUploadFile, requestJson: wireEncodeRequest(requestJson))
    }

    public func uploadImage(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUploadImage, requestJson: wireEncodeRequest(requestJson))
    }

    public func uploadVideo(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUploadVideo, requestJson: wireEncodeRequest(requestJson))
    }

    public func uploadBytes(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUploadBytes, requestJson: wireEncodeRequest(requestJson))
    }

    public func deleteFile(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaDeleteFile, requestJson: wireEncodeRequest(requestJson))
    }

    public func getMediaUrl(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaGetUrl, requestJson: wireEncodeRequest(requestJson))
    }

    public func resolveAttachment(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaResolveAttachment, requestJson: wireEncodeRequest(requestJson))
    }

    public func getTempDownloadUrl(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaTempDownloadUrl, requestJson: wireEncodeRequest(requestJson))
    }

    public func resolveMediaAccess(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaResolveAccess, requestJson: wireEncodeRequest(requestJson))
    }

    public func cacheRemoteMedia(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaCacheRemote, requestJson: wireEncodeRequest(requestJson))
    }

    public func getMediaCacheStats(): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaCacheStats, requestJson: wireEncodeRequest("{}"))
    }

    public func setMediaCacheMaxBytes(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.mediaSetCacheMaxBytes, requestJson: wireEncodeRequest(requestJson))
    }

    public func setMediaCacheRoot(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.mediaSetCacheRoot, requestJson: wireEncodeRequest(requestJson))
    }

    public func clearMediaCache(): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.mediaClearCache, requestJson: wireEncodeRequest("{}"))
    }

    public func getUserDownloadSubfolder(): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUserDownloadGetSubfolder, requestJson: wireEncodeRequest("{}"))
    }

    public func setUserDownloadSubfolder(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.mediaUserDownloadSetSubfolder, requestJson: wireEncodeRequest(requestJson))
    }

    public func getUserDownloadSavedPath(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUserDownloadGetSavedPath, requestJson: wireEncodeRequest(requestJson))
    }

    public func deleteUserDownloadRecord(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.mediaUserDownloadDeleteRecord, requestJson: wireEncodeRequest(requestJson))
    }

    public func getUserDownloadDirectory(): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUserDownloadGetDirectory, requestJson: wireEncodeRequest("{}"))
    }

    public func setUserDownloadDirectory(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaUserDownloadSetDirectory, requestJson: wireEncodeRequest(requestJson))
    }

    public func downloadToUserDirectory(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaDownloadToUserDirectory, requestJson: wireEncodeRequest(requestJson))
    }

    public func uploadRecovery(request: MediaUploadRecoveryRequest): MediaUploadRecovery {
        let raw = bridge.invoke(descriptor: NativeCallMap.mediaUploadRecovery, requestJson: wireEncodeRequest(mediaUploadRecoveryRequestToJson(request)))
        return mediaUploadRecoveryFromJson(raw)
    }

    public func cancelUpload(request: MediaTransferRequest): MediaTransferCancellation {
        let raw = bridge.invoke(descriptor: NativeCallMap.mediaCancelUpload, requestJson: wireEncodeRequest(mediaTransferRequestToJson(request)))
        return mediaTransferCancellationFromJson(raw)
    }

    public func cancelTransfer(request: MediaTransferRequest): MediaTransferCancellation {
        let raw = bridge.invoke(descriptor: NativeCallMap.mediaCancelTransfer, requestJson: wireEncodeRequest(mediaTransferRequestToJson(request)))
        return mediaTransferCancellationFromJson(raw)
    }

    public func cancelUserFileDownload(requestJson: String): BooleanResponse {
        return booleanResponseFromWire(bridge.invoke(descriptor: NativeCallMap.mediaCancelUserFileDownload, requestJson: wireEncodeRequest(requestJson)))
    }

    public func downloadFileToDownloads(requestJson: String): String {
        return bridge.invoke(descriptor: NativeCallMap.mediaDownloadFileToDownloads, requestJson: wireEncodeRequest(requestJson))
    }
}
