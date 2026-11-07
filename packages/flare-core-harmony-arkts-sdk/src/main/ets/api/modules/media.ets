// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, ConnectionStatus, ConversationEvent, LifecycleEvent, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

/** Media access URL and local cache operations. */
export interface MediaApi {
  uploadFile(request: Record<string, Object>): Promise<Record<string, Object>>;
  uploadImage(request: Record<string, Object>): Promise<Record<string, Object>>;
  uploadVideo(request: Record<string, Object>): Promise<Record<string, Object>>;
  uploadBytes(request: Record<string, Object>): Promise<Record<string, Object>>;
  deleteFile(request: Record<string, Object>): Promise<Record<string, Object>>;
  getMediaUrl(request: Record<string, Object>): Promise<Record<string, Object>>;
  getTempDownloadUrl(request: Record<string, Object>): Promise<Record<string, Object>>;
  resolveMediaAccess(request: Record<string, Object>): Promise<Record<string, Object>>;
  cacheRemoteMedia(request: Record<string, Object>): Promise<Record<string, Object>>;
  getMediaCacheStats(): Promise<Record<string, Object>>;
  setMediaCacheMaxBytes(request: Record<string, Object>): Promise<void>;
  setMediaCacheRoot(request: Record<string, Object>): Promise<void>;
  clearMediaCache(): Promise<void>;
  getUserDownloadSubfolder(): Promise<Record<string, Object>>;
  setUserDownloadSubfolder(request: Record<string, Object>): Promise<void>;
  getUserDownloadSavedPath(request: Record<string, Object>): Promise<Record<string, Object>>;
  deleteUserDownloadRecord(request: Record<string, Object>): Promise<void>;
  getUserDownloadDirectory(): Promise<Record<string, Object>>;
  setUserDownloadDirectory(request: Record<string, Object>): Promise<Record<string, Object>>;
  downloadToUserDirectory(request: Record<string, Object>): Promise<Record<string, Object>>;
  cancelUserFileDownload(request: Record<string, Object>): Promise<boolean>;
  downloadFileToDownloads(request: Record<string, Object>): Promise<Record<string, Object>>;
}
