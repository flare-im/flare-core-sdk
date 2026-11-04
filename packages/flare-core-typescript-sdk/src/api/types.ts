/**
 * GENERATED. Do not edit by hand.
 *
 * Shared request/response types for module APIs under `./modules/`.
 */
import type { FlareSdkError } from '../contract';

export type Unit = void;
export type JsonValue = unknown;
export type TransportPolicy = "auto" | "websocket_only" | "protocol_race";
export type TransportKind = "websocket" | "quic";
export type SdkResourceProfile = "desktop" | "mobile";
export interface SdkConfig {
  ackMaxInFlight?: number;
  ackMaxRetries?: number;
  ackTimeoutSecs?: number;
  /** Monotonic integer build number reported on CONNECT; servers compare versions by it. */
  appBuild?: number;
  /** Host app version name reported on CONNECT. Web hosts inject it at build time. */
  appVersion?: string;
  capabilityUrl?: string;
  connectTimeoutSecs?: number;
  dataUrl?: string;
  defaultTransport?: TransportKind;
  /** Distribution channel reported on CONNECT (`web` when unset in the browser, `tauri` under Tauri). */
  distribution?: string;
  enableMetrics?: boolean;
  eventBusCapacity?: number;
  eventDedupeCapacity?: number;
  httpUrl?: string;
  initMessageSyncConcurrency?: number;
  maxReconnectAttempts?: number;
  mediaStorageProxyPrefix?: string;
  mediaStorageProxyTargets?: string[];
  messageDedupeCapacity?: number;
  onlineUrl?: string;
  protocolRaceOrder?: TransportKind[];
  quicUrl?: string;
  reconnectIntervalSecs?: number;
  resourceProfile?: SdkResourceProfile;
  syncBatchSize?: number;
  tenantId?: string;
  tlsCaCertPath?: string;
  transportPolicy?: TransportPolicy;
  wsUrl?: string;
}
export interface CreateClientRequest { config: SdkConfig; }
export interface CreateClientResponse { handle: bigint | number; }
export interface LoginRequest { userId: string; token?: string; storeConfigJson?: string; }
export interface MessageDispatchRequest { op: string; params: Record<string, unknown>; }
export interface Subscription { id: bigint | number; }
export type FlareJsonObject = Record<string, unknown>;

export interface SdkResult<T> { value?: T; error?: FlareSdkError; }
export type BatchGetUserPresenceRequest = FlareJsonObject;
export type BatchGetUserPresenceResponse = FlareJsonObject;
export type CacheRemoteMediaRequest = FlareJsonObject;
export type CancelUserFileDownloadRequest = FlareJsonObject;
export type ClearLocalChatHistoryRequest = FlareJsonObject;
export type CurrentUserIdResponse = FlareJsonObject;
export type DataRootResponse = FlareJsonObject;
export type DeleteConversationRequest = FlareJsonObject;
export type DeleteMediaFileRequest = FlareJsonObject;
export type DeleteMediaFileResponse = FlareJsonObject;
export type DeleteMessageRequest = FlareJsonObject;
export type DeleteUserDownloadRecordRequest = FlareJsonObject;
export type DispatchCapabilityRequest = FlareJsonObject;
export type DispatchCapabilityResponse = FlareJsonObject;
export type DownloadFileToDownloadsRequest = FlareJsonObject;
export type DownloadToUserDirectoryRequest = FlareJsonObject;
export type EditRichDocByMessageIdRequest = FlareJsonObject;
export type EditTextByMessageIdRequest = FlareJsonObject;
export type FfiContractVersion = FlareJsonObject;
export type GetConversationRequest = FlareJsonObject;
export type GetGroupConversationByUserIdsRequest = FlareJsonObject;
export type GetMediaUrlRequest = FlareJsonObject;
export type GetMessageRequest = FlareJsonObject;
export type GetMultipleConversationsRequest = FlareJsonObject;
export type GetOneConversationRequest = FlareJsonObject;
export type GetUserDownloadSavedPathRequest = FlareJsonObject;
export type GetUserPresenceRequest = FlareJsonObject;
export type GrantCapabilityRequest = FlareJsonObject;
export type JsonObject = FlareJsonObject;
export type ListCapabilitiesRequest = FlareJsonObject;
export type ListCapabilitiesResponse = FlareJsonObject;
export type ListConversationsPaginatedRequest = FlareJsonObject;
export type ListUserCapabilitiesRequest = FlareJsonObject;
export type ListUserCapabilitiesResponse = FlareJsonObject;
export type MarkConversationReadRequest = FlareJsonObject;
export type MarkConversationUnreadRequest = FlareJsonObject;
export type MarkMessageReadAndBurnRequest = FlareJsonObject;
export type MediaAccessUrl = FlareJsonObject;
export type MediaCacheEntry = FlareJsonObject;
export type MediaCacheStats = FlareJsonObject;
export type MediaResolvedAccess = FlareJsonObject;
export type MediaUploadResponse = FlareJsonObject;
export type MessageMutationRequest = FlareJsonObject;
export type ReactionMutationRequest = FlareJsonObject;
export type RecallMessageRequest = FlareJsonObject;
export type ResolveMediaAccessRequest = FlareJsonObject;
export type RevokeCapabilityRequest = FlareJsonObject;
export type SdkVersion = FlareJsonObject;
export type SetConversationArchivedRequest = FlareJsonObject;
export type SetConversationMutedRequest = FlareJsonObject;
export type SetConversationPinnedRequest = FlareJsonObject;
export type SetMediaCacheMaxBytesRequest = FlareJsonObject;
export type SetMediaCacheRootRequest = FlareJsonObject;
export type SetTypingRequest = FlareJsonObject;
export type SetUserDownloadDirectoryRequest = FlareJsonObject;
export type SetUserDownloadSubfolderRequest = FlareJsonObject;
export type SubscribeEventsRequest = FlareJsonObject;
export type SubscribeUserPresenceRequest = FlareJsonObject;
export type SyncConversationRequest = FlareJsonObject;
export type SyncMessagesRequest = FlareJsonObject;
export type TempDownloadUrlRequest = FlareJsonObject;
export type UnsubscribeRequest = FlareJsonObject;
export type UpdateAccessTokenRequest = FlareJsonObject;
export type UploadBytesRequest = FlareJsonObject;
export type UploadFileRequest = FlareJsonObject;
export type UpsertUserProfilesRequest = FlareJsonObject;
export type UserDownloadDirectory = FlareJsonObject;
export type UserDownloadSavedPathResponse = FlareJsonObject;
export type UserDownloadSubfolderResponse = FlareJsonObject;
export type UserFileDownloadResult = FlareJsonObject;
export type UserPresence = FlareJsonObject;
