package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.media.MediaApi
import com.flare.im.callback.*
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallMap
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
class DefaultMediaApi(
    private val bridge: NativeBridge,
) : MediaApi {

    override suspend fun uploadFile(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_UPLOAD_FILE, request)
    }

    override suspend fun uploadImage(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_UPLOAD_IMAGE, request)
    }

    override suspend fun uploadVideo(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_UPLOAD_VIDEO, request)
    }

    override suspend fun uploadBytes(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_UPLOAD_BYTES, request)
    }

    override suspend fun deleteFile(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_DELETE_FILE, request)
    }

    override suspend fun getMediaUrl(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_GET_URL, request)
    }

    override suspend fun getTempDownloadUrl(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_TEMP_DOWNLOAD_URL, request)
    }

    override suspend fun resolveMediaAccess(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_RESOLVE_ACCESS, request)
    }

    override suspend fun cacheRemoteMedia(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_CACHE_REMOTE, request)
    }

    override suspend fun getMediaCacheStats(): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_CACHE_STATS)
    }

    override suspend fun setMediaCacheMaxBytes(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MEDIA_SET_CACHE_MAX_BYTES, request)
    }

    override suspend fun setMediaCacheRoot(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MEDIA_SET_CACHE_ROOT, request)
    }

    override suspend fun clearMediaCache(): Unit {
        invokeUnit(bridge, NativeCallMap.MEDIA_CLEAR_CACHE)
    }

    override suspend fun getUserDownloadSubfolder(): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_USER_DOWNLOAD_GET_SUBFOLDER)
    }

    override suspend fun setUserDownloadSubfolder(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MEDIA_USER_DOWNLOAD_SET_SUBFOLDER, request)
    }

    override suspend fun getUserDownloadSavedPath(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_USER_DOWNLOAD_GET_SAVED_PATH, request)
    }

    override suspend fun deleteUserDownloadRecord(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.MEDIA_USER_DOWNLOAD_DELETE_RECORD, request)
    }

    override suspend fun getUserDownloadDirectory(): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_USER_DOWNLOAD_GET_DIRECTORY)
    }

    override suspend fun setUserDownloadDirectory(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_USER_DOWNLOAD_SET_DIRECTORY, request)
    }

    override suspend fun downloadToUserDirectory(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_DOWNLOAD_TO_USER_DIRECTORY, request)
    }

    override suspend fun cancelUserFileDownload(request: Map<String, Any?>): Boolean {
        return invokeBool(bridge, NativeCallMap.MEDIA_CANCEL_USER_FILE_DOWNLOAD, request)
    }

    override suspend fun downloadFileToDownloads(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.MEDIA_DOWNLOAD_FILE_TO_DOWNLOADS, request)
    }
}
