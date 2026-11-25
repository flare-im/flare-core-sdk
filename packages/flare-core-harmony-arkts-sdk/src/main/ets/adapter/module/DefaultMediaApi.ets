// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { MediaApi } from '../../api/modules/media';
import type { MediaTransferCancellation, MediaTransferRequest, MediaUploadRecovery, MediaUploadRecoveryRequest } from '../../model';
import { invokeBool, invokeMap, invokeVoid } from '../codec/NativeInvoke';
import { mediaTransferCancellationFromJson, mediaTransferRequestToMap, mediaUploadRecoveryFromJson, mediaUploadRecoveryRequestToMap } from '../codec/WireCodec';

export class DefaultMediaApi implements MediaApi {
  constructor(private readonly bridge: NativeBridge) {}

  async uploadFile(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadFile, request);
  }

  async uploadImage(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadImage, request);
  }

  async uploadVideo(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadVideo, request);
  }

  async uploadBytes(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadBytes, request);
  }

  async deleteFile(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaDeleteFile, request);
  }

  async getMediaUrl(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaGetUrl, request);
  }

  async resolveAttachment(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaResolveAttachment, request);
  }

  async getTempDownloadUrl(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaTempDownloadUrl, request);
  }

  async resolveMediaAccess(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaResolveAccess, request);
  }

  async cacheRemoteMedia(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaCacheRemote, request);
  }

  async getMediaCacheStats(): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaCacheStats);
  }

  async setMediaCacheMaxBytes(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaSetCacheMaxBytes, request);
  }

  async setMediaCacheRoot(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaSetCacheRoot, request);
  }

  async clearMediaCache(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaClearCache);
  }

  async getUserDownloadSubfolder(): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadGetSubfolder);
  }

  async setUserDownloadSubfolder(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaUserDownloadSetSubfolder, request);
  }

  async getUserDownloadSavedPath(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadGetSavedPath, request);
  }

  async deleteUserDownloadRecord(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaUserDownloadDeleteRecord, request);
  }

  async getUserDownloadDirectory(): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadGetDirectory);
  }

  async setUserDownloadDirectory(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadSetDirectory, request);
  }

  async downloadToUserDirectory(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaDownloadToUserDirectory, request);
  }

  async uploadRecovery(request: MediaUploadRecoveryRequest): Promise<MediaUploadRecovery> {
    const raw = await invokeMap(this.bridge, NativeCallMap.mediaUploadRecovery, mediaUploadRecoveryRequestToMap(request));
    return mediaUploadRecoveryFromJson(raw);
  }

  async cancelUpload(request: MediaTransferRequest): Promise<MediaTransferCancellation> {
    const raw = await invokeMap(this.bridge, NativeCallMap.mediaCancelUpload, mediaTransferRequestToMap(request));
    return mediaTransferCancellationFromJson(raw);
  }

  async cancelTransfer(request: MediaTransferRequest): Promise<MediaTransferCancellation> {
    const raw = await invokeMap(this.bridge, NativeCallMap.mediaCancelTransfer, mediaTransferRequestToMap(request));
    return mediaTransferCancellationFromJson(raw);
  }

  async cancelUserFileDownload(request: Record<string, Object>): Promise<boolean> {
    return await invokeBool(this.bridge, NativeCallMap.mediaCancelUserFileDownload, request);
  }

  async downloadFileToDownloads(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaDownloadFileToDownloads, request);
  }
}
