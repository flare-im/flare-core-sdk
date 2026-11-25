/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `media` — Media access URL and local cache operations.
 */
import type { MediaTransferCancellation, MediaTransferRequest, MediaUploadRecovery, MediaUploadRecoveryRequest } from '../../model';
import type { CacheRemoteMediaRequest, CancelUserFileDownloadRequest, DeleteMediaFileRequest, DeleteMediaFileResponse, DeleteUserDownloadRecordRequest, DownloadFileToDownloadsRequest, DownloadToUserDirectoryRequest, GetMediaUrlRequest, GetUserDownloadSavedPathRequest, MediaAccessUrl, MediaCacheEntry, MediaCacheStats, MediaResolvedAccess, MediaUploadResponse, ResolveAttachmentRequest, ResolveMediaAccessRequest, SetMediaCacheMaxBytesRequest, SetMediaCacheRootRequest, SetUserDownloadDirectoryRequest, SetUserDownloadSubfolderRequest, TempDownloadUrlRequest, UploadBytesRequest, UploadFileRequest, UserDownloadDirectory, UserDownloadSavedPathResponse, UserDownloadSubfolderResponse, UserFileDownloadResult } from '../types';

/** Media access URL and local cache operations. */
export interface MediaApi {
  /** uploadFile maps to `flare_media_upload_file` via `ffi-symbol`. Operation: `media.upload_file`. */
  uploadFile(request: UploadFileRequest): Promise<MediaUploadResponse>;
  /** uploadImage maps to `flare_media_upload_image` via `ffi-symbol`. Operation: `media.upload_image`. */
  uploadImage(request: UploadFileRequest): Promise<MediaUploadResponse>;
  /** uploadVideo maps to `flare_media_upload_video` via `ffi-symbol`. Operation: `media.upload_video`. */
  uploadVideo(request: UploadFileRequest): Promise<MediaUploadResponse>;
  /** uploadBytes maps to `flare_media_upload_bytes` via `ffi-symbol`. Operation: `media.upload_bytes`. */
  uploadBytes(request: UploadBytesRequest): Promise<MediaUploadResponse>;
  /** deleteFile maps to `flare_media_delete_file` via `ffi-symbol`. Operation: `media.delete_file`. */
  deleteFile(request: DeleteMediaFileRequest): Promise<DeleteMediaFileResponse>;
  /** getMediaUrl maps to `flare_media_dispatch_json`, dispatch op `get_url`. Operation: `media.get_url`. */
  getMediaUrl(request: GetMediaUrlRequest): Promise<MediaAccessUrl>;
  /** resolveAttachment maps to `flare_media_dispatch_json`, dispatch op `resolve_attachment`. Operation: `media.resolve_attachment`. */
  resolveAttachment(request: ResolveAttachmentRequest): Promise<MediaAccessUrl>;
  /** getTempDownloadUrl maps to `flare_media_dispatch_json`, dispatch op `temp_download_url`. Operation: `media.temp_download_url`. */
  getTempDownloadUrl(request: TempDownloadUrlRequest): Promise<MediaAccessUrl>;
  /** resolveMediaAccess maps to `flare_media_dispatch_json`, dispatch op `resolve_access`. Operation: `media.resolve_access`. */
  resolveMediaAccess(request: ResolveMediaAccessRequest): Promise<MediaResolvedAccess>;
  /** Resolves a media item into a display-ready URL using the canonical core media access shape. */
  resolveDisplayUrl(request: ResolveMediaAccessRequest): Promise<string>;
  /** cacheRemoteMedia maps to `flare_media_dispatch_json`, dispatch op `cache_remote`. Operation: `media.cache_remote`. */
  cacheRemoteMedia(request: CacheRemoteMediaRequest): Promise<MediaCacheEntry>;
  /** getMediaCacheStats maps to `flare_media_dispatch_json`, dispatch op `cache_stats`. Operation: `media.cache_stats`. */
  getMediaCacheStats(): Promise<MediaCacheStats>;
  /** setMediaCacheMaxBytes maps to `flare_media_dispatch_json`, dispatch op `set_cache_max_bytes`. Operation: `media.set_cache_max_bytes`. */
  setMediaCacheMaxBytes(request: SetMediaCacheMaxBytesRequest): Promise<void>;
  /** setMediaCacheRoot maps to `flare_media_dispatch_json`, dispatch op `set_cache_root`. Operation: `media.set_cache_root`. */
  setMediaCacheRoot(request: SetMediaCacheRootRequest): Promise<void>;
  /** clearMediaCache maps to `flare_media_dispatch_json`, dispatch op `clear_cache`. Operation: `media.clear_cache`. */
  clearMediaCache(): Promise<void>;
  /** getUserDownloadSubfolder maps to `flare_media_dispatch_json`, dispatch op `user_download_get_subfolder`. Operation: `media.user_download_get_subfolder`. */
  getUserDownloadSubfolder(): Promise<UserDownloadSubfolderResponse>;
  /** setUserDownloadSubfolder maps to `flare_media_dispatch_json`, dispatch op `user_download_set_subfolder`. Operation: `media.user_download_set_subfolder`. */
  setUserDownloadSubfolder(request: SetUserDownloadSubfolderRequest): Promise<void>;
  /** getUserDownloadSavedPath maps to `flare_media_dispatch_json`, dispatch op `user_download_get_saved_path`. Operation: `media.user_download_get_saved_path`. */
  getUserDownloadSavedPath(request: GetUserDownloadSavedPathRequest): Promise<UserDownloadSavedPathResponse>;
  /** deleteUserDownloadRecord maps to `flare_media_dispatch_json`, dispatch op `user_download_delete_record`. Operation: `media.user_download_delete_record`. */
  deleteUserDownloadRecord(request: DeleteUserDownloadRecordRequest): Promise<void>;
  /** getUserDownloadDirectory maps to `flare_media_dispatch_json`, dispatch op `user_download_get_directory`. Operation: `media.user_download_get_directory`. */
  getUserDownloadDirectory(): Promise<UserDownloadDirectory>;
  /** setUserDownloadDirectory maps to `flare_media_dispatch_json`, dispatch op `user_download_set_directory`. Operation: `media.user_download_set_directory`. */
  setUserDownloadDirectory(request: SetUserDownloadDirectoryRequest): Promise<UserDownloadDirectory>;
  /** downloadToUserDirectory maps to `flare_media_dispatch_json`, dispatch op `download_to_user_directory`. Operation: `media.download_to_user_directory`. */
  downloadToUserDirectory(request: DownloadToUserDirectoryRequest): Promise<UserFileDownloadResult>;
  /** uploadRecovery maps to `flare_media_dispatch_json`, dispatch op `upload_recovery`. Operation: `media.upload_recovery`. */
  uploadRecovery(request: MediaUploadRecoveryRequest): Promise<MediaUploadRecovery>;
  /** cancelUpload maps to `flare_media_dispatch_json`, dispatch op `cancel_upload`. Operation: `media.cancel_upload`. */
  cancelUpload(request: MediaTransferRequest): Promise<MediaTransferCancellation>;
  /** cancelTransfer maps to `flare_media_dispatch_json`, dispatch op `cancel_transfer`. Operation: `media.cancel_transfer`. */
  cancelTransfer(request: MediaTransferRequest): Promise<MediaTransferCancellation>;
  /** cancelUserFileDownload maps to `flare_media_cancel_user_file_download` via `ffi-symbol`. Operation: `media.cancel_user_file_download`. */
  cancelUserFileDownload(request: CancelUserFileDownloadRequest): Promise<boolean>;
  /** downloadFileToDownloads maps to `flare_media_download_file_to_downloads` via `ffi-symbol`. Operation: `media.download_file_to_downloads`. */
  downloadFileToDownloads(request: DownloadFileToDownloadsRequest): Promise<UserDownloadSavedPathResponse>;
}
