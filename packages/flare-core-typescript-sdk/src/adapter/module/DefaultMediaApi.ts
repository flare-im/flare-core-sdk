// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { MediaApi } from '../../api/modules/media';
import { FlareSdkException } from '../../bridge/flareSdkException';
import { pickDisplayUrlFromResolved } from '../media/mediaAccess';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap } from '../codec/wireCodec';

export class DefaultMediaApi implements MediaApi {
  constructor(private readonly bridge: NativeBridge) {}

  async uploadFile(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadFile, request);
  }

  async uploadImage(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadImage, request);
  }

  async uploadVideo(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadVideo, request);
  }

  async uploadBytes(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUploadBytes, request);
  }

  async deleteFile(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaDeleteFile, request);
  }

  async getMediaUrl(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaGetUrl, request);
  }

  async getTempDownloadUrl(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaTempDownloadUrl, request);
  }

  async resolveMediaAccess(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaResolveAccess, request);
  }

  async cacheRemoteMedia(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaCacheRemote, request);
  }

  async getMediaCacheStats(): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaCacheStats);
  }

  async setMediaCacheMaxBytes(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaSetCacheMaxBytes, request);
  }

  async setMediaCacheRoot(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaSetCacheRoot, request);
  }

  async clearMediaCache(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaClearCache);
  }

  async getUserDownloadSubfolder(): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadGetSubfolder);
  }

  async setUserDownloadSubfolder(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaUserDownloadSetSubfolder, request);
  }

  async getUserDownloadSavedPath(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadGetSavedPath, request);
  }

  async deleteUserDownloadRecord(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.mediaUserDownloadDeleteRecord, request);
  }

  async getUserDownloadDirectory(): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadGetDirectory);
  }

  async setUserDownloadDirectory(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaUserDownloadSetDirectory, request);
  }

  async downloadToUserDirectory(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaDownloadToUserDirectory, request);
  }

  async cancelUserFileDownload(request: Record<string, unknown>): Promise<boolean> {
    return await invokeBool(this.bridge, NativeCallMap.mediaCancelUserFileDownload, request);
  }

  async downloadFileToDownloads(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.mediaDownloadFileToDownloads, request);
  }

  async resolveDisplayUrl(request: Record<string, unknown>): Promise<string> {
    const resolved = await this.resolveMediaAccess(request);
    const url = pickDisplayUrlFromResolved(resolved);
    if (!url) {
      throw new FlareSdkException('generalError', 'empty media display url', 'media.resolve_display_url');
    }
    return url;
  }
}
