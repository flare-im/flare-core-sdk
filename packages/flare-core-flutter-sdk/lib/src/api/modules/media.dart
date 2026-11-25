// GENERATED. Do not edit by hand.
// Module API: `media` — Media access URL and local cache operations.
import '../../model/model.dart';

/// Media access URL and local cache operations.
abstract interface class MediaApi {
  /// uploadFile maps to `flare_media_upload_file` via `ffi-symbol`. Operation: `media.upload_file`.
  Future<Map<String, Object?>> uploadFile(Map<String, Object?> request);
  /// uploadImage maps to `flare_media_upload_image` via `ffi-symbol`. Operation: `media.upload_image`.
  Future<Map<String, Object?>> uploadImage(Map<String, Object?> request);
  /// uploadVideo maps to `flare_media_upload_video` via `ffi-symbol`. Operation: `media.upload_video`.
  Future<Map<String, Object?>> uploadVideo(Map<String, Object?> request);
  /// uploadBytes maps to `flare_media_upload_bytes` via `ffi-symbol`. Operation: `media.upload_bytes`.
  Future<Map<String, Object?>> uploadBytes(Map<String, Object?> request);
  /// deleteFile maps to `flare_media_delete_file` via `ffi-symbol`. Operation: `media.delete_file`.
  Future<Map<String, Object?>> deleteFile(Map<String, Object?> request);
  /// getMediaUrl maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `get_url`. Operation: `media.get_url`.
  Future<Map<String, Object?>> getMediaUrl(Map<String, Object?> request);
  /// resolveAttachment maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `resolve_attachment`. Operation: `media.resolve_attachment`.
  Future<Map<String, Object?>> resolveAttachment(Map<String, Object?> request);
  /// getTempDownloadUrl maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `temp_download_url`. Operation: `media.temp_download_url`.
  Future<Map<String, Object?>> getTempDownloadUrl(Map<String, Object?> request);
  /// resolveMediaAccess maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `resolve_access`. Operation: `media.resolve_access`.
  Future<Map<String, Object?>> resolveMediaAccess(Map<String, Object?> request);
  /// cacheRemoteMedia maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cache_remote`. Operation: `media.cache_remote`.
  Future<Map<String, Object?>> cacheRemoteMedia(Map<String, Object?> request);
  /// getMediaCacheStats maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cache_stats`. Operation: `media.cache_stats`.
  Future<Map<String, Object?>> getMediaCacheStats();
  /// setMediaCacheMaxBytes maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `set_cache_max_bytes`. Operation: `media.set_cache_max_bytes`.
  Future<void> setMediaCacheMaxBytes(Map<String, Object?> request);
  /// setMediaCacheRoot maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `set_cache_root`. Operation: `media.set_cache_root`.
  Future<void> setMediaCacheRoot(Map<String, Object?> request);
  /// clearMediaCache maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `clear_cache`. Operation: `media.clear_cache`.
  Future<void> clearMediaCache();
  /// getUserDownloadSubfolder maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_subfolder`. Operation: `media.user_download_get_subfolder`.
  Future<Map<String, Object?>> getUserDownloadSubfolder();
  /// setUserDownloadSubfolder maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_set_subfolder`. Operation: `media.user_download_set_subfolder`.
  Future<void> setUserDownloadSubfolder(Map<String, Object?> request);
  /// getUserDownloadSavedPath maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_saved_path`. Operation: `media.user_download_get_saved_path`.
  Future<Map<String, Object?>> getUserDownloadSavedPath(Map<String, Object?> request);
  /// deleteUserDownloadRecord maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_delete_record`. Operation: `media.user_download_delete_record`.
  Future<void> deleteUserDownloadRecord(Map<String, Object?> request);
  /// getUserDownloadDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_directory`. Operation: `media.user_download_get_directory`.
  Future<Map<String, Object?>> getUserDownloadDirectory();
  /// setUserDownloadDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_set_directory`. Operation: `media.user_download_set_directory`.
  Future<Map<String, Object?>> setUserDownloadDirectory(Map<String, Object?> request);
  /// downloadToUserDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `download_to_user_directory`. Operation: `media.download_to_user_directory`.
  Future<Map<String, Object?>> downloadToUserDirectory(Map<String, Object?> request);
  /// uploadRecovery maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `upload_recovery`. Operation: `media.upload_recovery`.
  Future<MediaUploadRecovery> uploadRecovery(MediaUploadRecoveryRequest request);
  /// cancelUpload maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cancel_upload`. Operation: `media.cancel_upload`.
  Future<MediaTransferCancellation> cancelUpload(MediaTransferRequest request);
  /// cancelTransfer maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cancel_transfer`. Operation: `media.cancel_transfer`.
  Future<MediaTransferCancellation> cancelTransfer(MediaTransferRequest request);
  /// cancelUserFileDownload maps to `flare_media_cancel_user_file_download` via `ffi-symbol`. Operation: `media.cancel_user_file_download`.
  Future<bool> cancelUserFileDownload(Map<String, Object?> request);
  /// downloadFileToDownloads maps to `flare_media_download_file_to_downloads` via `ffi-symbol`. Operation: `media.download_file_to_downloads`.
  Future<Map<String, Object?>> downloadFileToDownloads(Map<String, Object?> request);
}
