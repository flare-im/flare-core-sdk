/**
 * GENERATED. Do not edit by hand.
 *
 * Shared request/response types for module APIs under `./modules/`.
 */
import type { FlareSdkError } from '../contract';

export type Unit = void;
export type JsonValue = unknown;
export type SdkResourceProfile = "desktop" | "mobile";
/** A root public key the access manifest signature chain is verified against. */
export interface AccessTrustRoot { keyId: string; publicKey: string; }
/** One more access point of the development cell (local dual-entry failover drills). */
export interface DevelopmentAccessPoint {
  id: string;
  wsUrl?: string;
  quicUrl?: string;
  coreApiUrl?: string;
  socialApiUrl?: string;
  mediaUrl?: string;
}
/** Development mode only: endpoints of the primary access point (id `development`), unsigned. */
export interface DevelopmentEndpoints {
  wsUrl?: string;
  quicUrl?: string;
  coreApiUrl?: string;
  socialApiUrl?: string;
  mediaUrl?: string;
  accessPoints?: DevelopmentAccessPoint[];
  /** Client link policy overrides, clamped like a signed manifest's `clientPolicy`. */
  clientPolicy?: Record<string, unknown>;
}
/** Where to connect: the signed access manifest, or development endpoints. The SDK has no other address field. */
export interface AccessConfig {
  bootstrapId?: string;
  trustRoots?: AccessTrustRoot[];
  /** Signed access manifest written at build time (DSSE envelope JSON text). */
  seed?: string;
  trustMode?: "production" | "development";
  developmentEndpoints?: DevelopmentEndpoints;
}
/** Host app identity reported on CONNECT. When given it replaces the build-time value whole. */
export interface SdkAppConfig {
  /** Version name, e.g. `3.2.1`. Web hosts inject it at build time. */
  version?: string;
  /** Monotonic integer build number; servers compare versions by it. */
  build?: number;
  /** Distribution channel reported on CONNECT (`web` when unset in the browser, `tauri` under Tauri). */
  distribution?: string;
  /** Update channel (stable, beta); not reported on CONNECT. */
  channel?: string;
  /** The web build this page runs: the update center compares it, not `build`. */
  buildId?: string;
  /** Desktop target (`darwin-aarch64`): picks the desktop artifact. */
  target?: string;
  /** Interface language (BCP-47); the release notes follow it. */
  locale?: string;
}
/**
 * SDK-managed connect tokens: with `auth` in the config (even `{}`) the core issues and refreshes
 * them through the Core API; without it the host supplies them.
 */
export interface SdkAuthConfig {
  /**
   * Path of the issuing endpoint on the Core API, starting with `/` (default `/api/v1/auth/tokens`;
   * refresh is `{tokenEndpoint}/refresh`). An absolute URL fails init with CONFIGURATION_ERROR.
   */
  tokenEndpoint?: string;
  /** Seconds before expiry to refresh the token (default 300). */
  refreshLeadSecs?: number;
}
export interface SdkConfig {
  access?: AccessConfig;
  ackMaxInFlight?: number;
  ackMaxRetries?: number;
  ackTimeoutSecs?: number;
  app?: SdkAppConfig;
  auth?: SdkAuthConfig;
  /** Local override of one handshake's timeout, clamped to 2..30; unset uses the manifest's clientPolicy. */
  connectTimeoutSecs?: number;
  dataUrl?: string;
  deviceId?: string;
  enableMetrics?: boolean;
  eventBusCapacity?: number;
  eventDedupeCapacity?: number;
  initMessageSyncConcurrency?: number;
  messageDedupeCapacity?: number;
  resourceProfile?: SdkResourceProfile;
  syncBatchSize?: number;
  tenantId?: string;
  tlsCaCert?: string;
  tlsCaCertPath?: string;
  /**
   * Platform package only, never sent to the core: init installs the PlatformLifecycle
   * (network and foreground/background wiring) unless this is false. Default true; tests turn it off.
   */
  installPlatformLifecycle?: boolean;
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
