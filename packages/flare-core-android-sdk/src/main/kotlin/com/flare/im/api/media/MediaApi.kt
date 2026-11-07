package com.flare.im.api.media

import com.flare.im.callback.*
import com.flare.im.listener.*
import com.flare.im.model.catalog.*
import com.flare.im.model.command.*
import com.flare.im.model.command.message.*
import com.flare.im.model.command.message.build.*
import com.flare.im.model.common.enums.*
import com.flare.im.model.common.error.*
import com.flare.im.model.content.*
import com.flare.im.model.entity.*
import com.flare.im.model.event.*
import com.flare.im.model.event.access.*
import com.flare.im.model.event.connection.*
import com.flare.im.model.event.conversation.*
import com.flare.im.model.event.lifecycle.*
import com.flare.im.model.event.message.*
import com.flare.im.model.event.plugin.*
import com.flare.im.model.event.presence.*
import com.flare.im.model.event.progress.*
import com.flare.im.model.event.sync.*
import com.flare.im.model.media.*
import com.flare.im.model.query.*
import com.flare.im.model.response.*

/** GENERATED. Do not edit by hand. */
/** Media access URL and local cache operations. */
interface MediaApi {
    /** uploadFile maps to `flare_media_upload_file` via `ffi-symbol`. Operation: `media.upload_file`. */
    suspend fun uploadFile(request: Map<String, Any?>): Map<String, Any?>
    /** uploadImage maps to `flare_media_upload_image` via `ffi-symbol`. Operation: `media.upload_image`. */
    suspend fun uploadImage(request: Map<String, Any?>): Map<String, Any?>
    /** uploadVideo maps to `flare_media_upload_video` via `ffi-symbol`. Operation: `media.upload_video`. */
    suspend fun uploadVideo(request: Map<String, Any?>): Map<String, Any?>
    /** uploadBytes maps to `flare_media_upload_bytes` via `ffi-symbol`. Operation: `media.upload_bytes`. */
    suspend fun uploadBytes(request: Map<String, Any?>): Map<String, Any?>
    /** deleteFile maps to `flare_media_delete_file` via `ffi-symbol`. Operation: `media.delete_file`. */
    suspend fun deleteFile(request: Map<String, Any?>): Map<String, Any?>
    /** getMediaUrl maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `get_url`. Operation: `media.get_url`. */
    suspend fun getMediaUrl(request: Map<String, Any?>): Map<String, Any?>
    /** getTempDownloadUrl maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `temp_download_url`. Operation: `media.temp_download_url`. */
    suspend fun getTempDownloadUrl(request: Map<String, Any?>): Map<String, Any?>
    /** resolveMediaAccess maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `resolve_access`. Operation: `media.resolve_access`. */
    suspend fun resolveMediaAccess(request: Map<String, Any?>): Map<String, Any?>
    /** cacheRemoteMedia maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cache_remote`. Operation: `media.cache_remote`. */
    suspend fun cacheRemoteMedia(request: Map<String, Any?>): Map<String, Any?>
    /** getMediaCacheStats maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `cache_stats`. Operation: `media.cache_stats`. */
    suspend fun getMediaCacheStats(): Map<String, Any?>
    /** setMediaCacheMaxBytes maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `set_cache_max_bytes`. Operation: `media.set_cache_max_bytes`. */
    suspend fun setMediaCacheMaxBytes(request: Map<String, Any?>): Unit
    /** setMediaCacheRoot maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `set_cache_root`. Operation: `media.set_cache_root`. */
    suspend fun setMediaCacheRoot(request: Map<String, Any?>): Unit
    /** clearMediaCache maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `clear_cache`. Operation: `media.clear_cache`. */
    suspend fun clearMediaCache(): Unit
    /** getUserDownloadSubfolder maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_subfolder`. Operation: `media.user_download_get_subfolder`. */
    suspend fun getUserDownloadSubfolder(): Map<String, Any?>
    /** setUserDownloadSubfolder maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_set_subfolder`. Operation: `media.user_download_set_subfolder`. */
    suspend fun setUserDownloadSubfolder(request: Map<String, Any?>): Unit
    /** getUserDownloadSavedPath maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_saved_path`. Operation: `media.user_download_get_saved_path`. */
    suspend fun getUserDownloadSavedPath(request: Map<String, Any?>): Map<String, Any?>
    /** deleteUserDownloadRecord maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_delete_record`. Operation: `media.user_download_delete_record`. */
    suspend fun deleteUserDownloadRecord(request: Map<String, Any?>): Unit
    /** getUserDownloadDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_get_directory`. Operation: `media.user_download_get_directory`. */
    suspend fun getUserDownloadDirectory(): Map<String, Any?>
    /** setUserDownloadDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `user_download_set_directory`. Operation: `media.user_download_set_directory`. */
    suspend fun setUserDownloadDirectory(request: Map<String, Any?>): Map<String, Any?>
    /** downloadToUserDirectory maps to `flare_media_dispatch_json` via `media-dispatch-json`, dispatch op `download_to_user_directory`. Operation: `media.download_to_user_directory`. */
    suspend fun downloadToUserDirectory(request: Map<String, Any?>): Map<String, Any?>
    /** cancelUserFileDownload maps to `flare_media_cancel_user_file_download` via `ffi-symbol`. Operation: `media.cancel_user_file_download`. */
    suspend fun cancelUserFileDownload(request: Map<String, Any?>): Boolean
    /** downloadFileToDownloads maps to `flare_media_download_file_to_downloads` via `ffi-symbol`. Operation: `media.download_file_to_downloads`. */
    suspend fun downloadFileToDownloads(request: Map<String, Any?>): Map<String, Any?>
}
