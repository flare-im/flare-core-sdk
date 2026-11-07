import type { MediaApi } from '../../../api/modules/media';
import type {
  CacheRemoteMediaRequest,
  CancelUserFileDownloadRequest,
  DeleteMediaFileRequest,
  DeleteMediaFileResponse,
  DeleteUserDownloadRecordRequest,
  DownloadFileToDownloadsRequest,
  DownloadToUserDirectoryRequest,
  GetMediaUrlRequest,
  GetUserDownloadSavedPathRequest,
  MediaAccessUrl,
  MediaCacheEntry,
  MediaCacheStats,
  MediaResolvedAccess,
  MediaUploadResponse,
  ResolveMediaAccessRequest,
  SetMediaCacheMaxBytesRequest,
  SetMediaCacheRootRequest,
  SetUserDownloadDirectoryRequest,
  SetUserDownloadSubfolderRequest,
  TempDownloadUrlRequest,
  UploadBytesRequest,
  UploadFileRequest,
  UserDownloadDirectory,
  UserDownloadSavedPathResponse,
  UserDownloadSubfolderResponse,
  UserFileDownloadResult,
} from '../../../api/types';
import { FlareSdkException } from '../../../bridge/flareSdkException';
import {
  browserMediaCacheStats,
  clearBrowserMediaCache,
  hasBrowserMedia,
  isBrowserMediaCacheAvailable,
  openBrowserMediaBlobUrl,
  cacheBrowserMedia,
  cacheBrowserMediaBlob,
  readBrowserMediaBlob,
  revokeBrowserMediaBlobUrl,
} from './browserMediaCache';
import {
  fetchBlob,
  forgetDownloadDirectory,
  forgetSavedDownload,
  pickDownloadDirectory,
  recordSavedDownload,
  sanitizeDownloadFileName,
  saveBlobToPickedDirectory,
  savedDownloadPresence,
  savedDownloadRecord,
  withExtensionFor,
  saveThroughBrowser,
  storedDownloadDirectory,
  supportsDownloadDirectoryPicker,
} from './browserDownload';
import { pickDisplayUrlFromResolved } from './webMediaHelpers';

const WEB_CACHE_UNSUPPORTED =
  'Native media cache is disabled on web/wasm. Use resolveMediaAccess(), resolveDisplayUrl(), or cacheRemoteMedia() with browser Cache API.';

function unsupported(operation: string): never {
  throw new FlareSdkException('operation.not_supported', WEB_CACHE_UNSUPPORTED, operation);
}

/** Pictures shown in chat are cached in the background up to this size (the native core's limit). */
const AUTO_CACHE_MAX_BYTES = 32 * 1024 * 1024;

/** Web download progress: the request may carry a callback (a JS function, not JSON). */
export type WebDownloadProgress = (downloaded: number, total: number | undefined) => void;

function stringField(request: Record<string, unknown>, ...keys: string[]): string {
  for (const key of keys) {
    const value = request[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return '';
}

function fileNameFromUrl(url: string): string {
  try {
    const last = new URL(url).pathname.split('/').filter(Boolean).pop();
    return last ? decodeURIComponent(last) : '';
  } catch {
    return '';
  }
}

/**
 * Web media API: gateway presigned URLs + optional browser Cache API storage.
 * Does not persist blobs in IndexedDB or WASM storage.
 */
export class WebMediaApi implements MediaApi {
  private constructor(private readonly inner: MediaApi) {}

  /** In-flight saves by download key, so they can be cancelled. */
  private readonly downloads = new Map<string, AbortController>();

  /** fileIds being cached in the background (each fetched once at a time). */
  private readonly autoCaching = new Set<string>();

  readonly cacheApiAvailable = isBrowserMediaCacheAvailable();

  static fromInner(inner: MediaApi): WebMediaApi {
    return new WebMediaApi(inner);
  }

  async uploadFile(request: UploadFileRequest): Promise<MediaUploadResponse> {
    return this.inner.uploadFile(request);
  }

  async uploadImage(request: UploadFileRequest): Promise<MediaUploadResponse> {
    return this.inner.uploadImage(request);
  }

  async uploadVideo(request: UploadFileRequest): Promise<MediaUploadResponse> {
    return this.inner.uploadVideo(request);
  }

  async uploadBytes(request: UploadBytesRequest): Promise<MediaUploadResponse> {
    return this.inner.uploadBytes(request);
  }

  async deleteFile(request: DeleteMediaFileRequest): Promise<DeleteMediaFileResponse> {
    return this.inner.deleteFile(request);
  }

  async getMediaUrl(request: GetMediaUrlRequest): Promise<MediaAccessUrl> {
    return this.inner.getMediaUrl(request);
  }

  async getTempDownloadUrl(request: TempDownloadUrlRequest): Promise<MediaAccessUrl> {
    return this.inner.getTempDownloadUrl(request);
  }

  async resolveMediaAccess(request: ResolveMediaAccessRequest): Promise<MediaResolvedAccess> {
    const resolved = await this.inner.resolveMediaAccess(request);
    if (request.autoCache === true) {
      const url = pickDisplayUrlFromResolved(resolved);
      if (url) this.autoCache(String(request.fileId ?? ''), url);
    }
    return resolved;
  }

  /** Caches [fileId] from [url] in the background, once; failures only mean "not cached". */
  private autoCache(fileId: string, url: string): void {
    const fid = fileId.trim();
    if (!fid || !isBrowserMediaCacheAvailable() || this.autoCaching.has(fid)) return;
    this.autoCaching.add(fid);
    void (async () => {
      try {
        if (await hasBrowserMedia(fid)) return;
        // Presigned URLs are signed for GET only, so the size is checked on the response itself.
        await cacheBrowserMedia(fid, url, AUTO_CACHE_MAX_BYTES);
      } catch {
        // Not cached this time; the picture still shows from its URL.
      } finally {
        this.autoCaching.delete(fid);
      }
    })();
  }

  /**
   * A URL an `<img>`/`<video>` can load: the cached copy (`blob:`) when there is one, else the
   * signed URL. With `autoCache: true` a miss is cached in the background for next time.
   * Release a `blob:` URL with [revokeDisplayUrl] when it is no longer shown.
   */
  async resolveDisplayUrl(request: ResolveMediaAccessRequest): Promise<string> {
    const fileId = String(request.fileId ?? '').trim();
    if (fileId && (await hasBrowserMedia(fileId))) {
      const blobUrl = await openBrowserMediaBlobUrl(fileId);
      if (blobUrl) return blobUrl;
    }
    const resolved = await this.resolveMediaAccess(request);
    const url = pickDisplayUrlFromResolved(resolved);
    if (!url) {
      throw new FlareSdkException('generalError', 'empty media display url', 'media.resolve_display_url');
    }
    return url;
  }

  revokeDisplayUrl(url: string): void {
    revokeBrowserMediaBlobUrl(url);
  }

  async cacheRemoteMedia(request: CacheRemoteMediaRequest): Promise<MediaCacheEntry> {
    return this.cacheRemoteWithBrowserCache(request);
  }

  async getMediaCacheStats(): Promise<MediaCacheStats> {
    return browserMediaCacheStats() as Promise<MediaCacheStats>;
  }

  async setMediaCacheMaxBytes(_request: SetMediaCacheMaxBytesRequest): Promise<void> {
    unsupported('media.set_cache_max_bytes');
  }

  async setMediaCacheRoot(_request: SetMediaCacheRootRequest): Promise<void> {
    unsupported('media.set_cache_root');
  }

  async clearMediaCache(): Promise<void> {
    await clearBrowserMediaCache();
  }

  async getUserDownloadSubfolder(): Promise<UserDownloadSubfolderResponse> {
    unsupported('media.user_download_get_subfolder');
  }

  async setUserDownloadSubfolder(_request: SetUserDownloadSubfolderRequest): Promise<void> {
    unsupported('media.user_download_set_subfolder');
  }

  /**
   * Where [downloadKey] was saved in the picked folder: `{path, directory, fileName, verified}`, or `{path: null}` when
   * it was never saved there or the file is gone (its record is dropped then, as the native core does). A file the
   * browser saved through its own download flow is not tracked. `interactive: true` (from a click) lets the check ask
   * for read access to the folder; without access the answer is the record, `verified: false`.
   */
  async getUserDownloadSavedPath(request: GetUserDownloadSavedPathRequest): Promise<UserDownloadSavedPathResponse> {
    const key = stringField(request, 'downloadKey');
    const record = await savedDownloadRecord(key);
    if (!record) return { path: null };
    const presence = await savedDownloadPresence(record, request.interactive === true);
    if (presence === 'missing') {
      await forgetSavedDownload(key);
      return { path: null };
    }
    return {
      path: record.directory ? `${record.directory}/${record.fileName}` : record.fileName,
      directory: record.directory,
      fileName: record.fileName,
      savedVia: 'directory',
      verified: presence === 'present',
    };
  }

  async deleteUserDownloadRecord(request: DeleteUserDownloadRecordRequest): Promise<void> {
    await forgetSavedDownload(stringField(request, 'downloadKey'));
  }

  async cancelUserFileDownload(request: CancelUserFileDownloadRequest): Promise<boolean> {
    const key = stringField(request, 'downloadKey');
    const controller = this.downloads.get(key);
    if (!controller) return false;
    controller.abort();
    return true;
  }

  async downloadFileToDownloads(request: DownloadFileToDownloadsRequest): Promise<UserDownloadSavedPathResponse> {
    return this.downloadToUserDirectory(request);
  }

  /**
   * The download location on web: the folder the user picked (browsers with the File System
   * Access API), otherwise the browser's own download folder, which a page cannot see or change.
   */
  async getUserDownloadDirectory(): Promise<UserDownloadDirectory> {
    const picked = await storedDownloadDirectory();
    return {
      directory: picked?.name ?? '',
      defaultDirectory: '',
      customDirectory: picked?.name ?? null,
      isCustom: picked !== undefined,
      subfolder: '',
      managedByBrowser: picked === undefined,
      supportsPicker: supportsDownloadDirectoryPicker(),
    };
  }

  /** Web can only forget a picked folder here (`directory: null`); pick one with [pickUserDownloadDirectory]. */
  async setUserDownloadDirectory(request: SetUserDownloadDirectoryRequest): Promise<UserDownloadDirectory> {
    const directory = request.directory ?? request.path;
    if (typeof directory === 'string' && directory.trim()) {
      throw new FlareSdkException(
        'invalidParameter',
        'a web page cannot name a folder; call pickUserDownloadDirectory() from a click',
        'media.user_download_set_directory',
      );
    }
    await forgetDownloadDirectory();
    return this.getUserDownloadDirectory();
  }

  /** Lets the user pick the download folder. Call it from a click (the browser requires a gesture). */
  async pickUserDownloadDirectory(): Promise<UserDownloadDirectory> {
    if (!supportsDownloadDirectoryPicker()) {
      throw new FlareSdkException(
        'operation.not_supported',
        'this browser cannot pick a download folder',
        'media.user_download_pick_directory',
      );
    }
    await pickDownloadDirectory();
    return this.getUserDownloadDirectory();
  }

  /**
   * Saves a file to the device: `fileId` (cached copy, else the attachment URL), `sourceUrl`,
   * with `fileName`. Goes into the picked folder when there is one and the browser allows it,
   * otherwise through the browser's download flow (`savedVia`). Pictures fetched here are cached.
   */
  async downloadToUserDirectory(request: DownloadToUserDirectoryRequest): Promise<UserFileDownloadResult> {
    const fileId = stringField(request, 'fileId', 'remoteFileId', 'mediaId');
    const sourceUrl = stringField(request, 'sourceUrl', 'sourceHttpUrl');
    if (!fileId && !sourceUrl) {
      throw new FlareSdkException(
        'invalidParameter',
        'provide fileId or sourceUrl',
        'media.download_to_user_directory',
      );
    }
    const key = stringField(request, 'downloadKey') || fileId || sourceUrl;
    const wanted = sanitizeDownloadFileName(
      stringField(request, 'fileName', 'displayFileName', 'name') ||
        fileNameFromUrl(sourceUrl) ||
        fileId ||
        'download',
    );
    const onProgress =
      typeof request.onProgress === 'function' ? (request.onProgress as WebDownloadProgress) : undefined;

    const controller = new AbortController();
    this.downloads.set(key, controller);
    try {
      let blob = fileId ? await readBrowserMediaBlob(fileId) : undefined;
      const fromCache = blob !== undefined;
      let url = sourceUrl;
      if (!blob) {
        if (!url) {
          const access = await this.inner.getTempDownloadUrl({
            fileId, expiresIn: 3600,
            ...(request.messageId !== undefined ? { messageId: request.messageId } : {}),
            ...(request.conversationId !== undefined ? { conversationId: request.conversationId } : {}),
            ...(request.messageSeq !== undefined ? { messageSeq: request.messageSeq } : {}),
          });
          url = String(access.url ?? access.cdnUrl ?? '').trim();
        }
        if (!url) {
          throw new FlareSdkException(
            'generalError',
            'empty download url from gateway',
            'media.download_to_user_directory',
          );
        }
        try {
          blob = await fetchBlob(url, controller.signal, onProgress);
        } catch (error) {
          if (controller.signal.aborted) throw error;
          // The storage does not allow this origin to read it (CORS): the browser can still
          // download the attachment URL itself.
          await forgetSavedDownload(key);
          saveThroughBrowser(url, wanted);
          return this.savedResult(key, '', wanted, 0, false, 'browser');
        }
        if (fileId && blob.type.startsWith('image/') && blob.size <= AUTO_CACHE_MAX_BYTES) {
          void cacheBrowserMediaBlob(fileId, blob).catch(() => undefined);
        }
      } else {
        onProgress?.(blob.size, blob.size);
      }
      const named = withExtensionFor(wanted, blob.type);
      const saved = await saveBlobToPickedDirectory(blob, named).catch(() => undefined);
      if (saved) {
        await recordSavedDownload(key, saved).catch(() => undefined);
        return this.savedResult(key, saved.directory, saved.fileName, blob.size, fromCache, 'directory');
      }
      await forgetSavedDownload(key);
      saveThroughBrowser(blob, named);
      return this.savedResult(key, '', named, blob.size, fromCache, 'browser');
    } finally {
      this.downloads.delete(key);
    }
  }

  private savedResult(
    downloadKey: string,
    directory: string,
    fileName: string,
    sizeBytes: number,
    fromCache: boolean,
    savedVia: 'directory' | 'browser',
  ): UserFileDownloadResult {
    return {
      path: directory ? `${directory}/${fileName}` : fileName,
      directory,
      fileName,
      sizeBytes,
      fromCache,
      downloadKey,
      savedVia,
    };
  }

  private async cacheRemoteWithBrowserCache(request: CacheRemoteMediaRequest): Promise<MediaCacheEntry> {
    const fileId = String(request.fileId ?? '').trim();
    if (!fileId) {
      throw new FlareSdkException('invalidParameter', 'fileId is required', 'media.cache_remote');
    }
    if (!isBrowserMediaCacheAvailable()) {
      throw new FlareSdkException(
        'operation.not_supported',
        'Cache API is unavailable in this environment',
        'media.cache_remote',
      );
    }
    const resolved = await this.resolveMediaAccess(request);
    const url = pickDisplayUrlFromResolved(resolved);
    if (!url) {
      throw new FlareSdkException('generalError', 'empty media download url', 'media.cache_remote');
    }
    await cacheBrowserMedia(fileId, url);
    return {
      fileId,
      localPath: `cache-api://${fileId}`,
      mimeType: '',
      sizeBytes: 0,
      updatedAtMs: Date.now(),
    };
  }
}
