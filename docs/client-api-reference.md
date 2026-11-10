# Client API Reference

> Generated from split sdk-spec files

All platform SDKs expose the same canonical modules and method names. Platform idioms may add wrappers, but the canonical names stay available.

## client

SDK lifecycle, authenticated session and process-level utilities.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `create` | `CreateClientRequest` | `CreateClientResponse` | `ffi-symbol` | `flare_sdk_create` |
| `init` | `SdkConfig` | `Unit` | `ffi-symbol` | `flare_sdk_init` |
| `uninit` | `Unit` | `Unit` | `ffi-symbol` | `flare_sdk_uninit` |
| `login` | `LoginRequest` | `Unit` | `ffi-symbol` | `flare_sdk_login` |
| `prepare` | `LoginRequest` | `Unit` | `ffi-symbol` | `flare_sdk_prepare` |
| `connect` | `LoginRequest` | `Unit` | `ffi-symbol` | `flare_sdk_connect` |
| `updateAccessToken` | `UpdateAccessTokenRequest` | `Unit` | `ffi-symbol` | `flare_sdk_update_access_token` |
| `setConnectTokenRefresher` | `SetConnectTokenRefresherRequest` | `Unit` | `ffi-symbol` | `flare_sdk_set_connect_token_refresher` |
| `completeConnectTokenRefresh` | `CompleteConnectTokenRefreshRequest` | `BooleanResponse` | `ffi-symbol` | `flare_sdk_complete_connect_token_refresh` |
| `setHeartbeatNatTimeout` | `SetHeartbeatNatTimeoutRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `heartbeatEffectiveInterval` | `Unit` | `HeartbeatEffectiveIntervalResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `logout` | `Unit` | `Unit` | `ffi-symbol` | `flare_sdk_logout` |
| `dispose` | `Unit` | `Unit` | `ffi-symbol` | `flare_sdk_release` |
| `hardReset` | `Unit` | `Unit` | `ffi-symbol` | `flare_sdk_hard_reset` |
| `currentUserId` | `Unit` | `CurrentUserIdResponse` | `ffi-symbol` | `flare_sdk_current_user_id` |
| `isConnected` | `Unit` | `BooleanResponse` | `ffi-symbol` | `flare_sdk_is_connected` |
| `sessionActive` | `Unit` | `BooleanResponse` | `ffi-symbol` | `flare_sdk_session_active` |
| `updatePushToken` | `PushTokenInput` | `PushLifecycleStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `clearPushToken` | `ClearPushTokenRequest` | `PushLifecycleStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `setPushPermission` | `SetPushPermissionRequest` | `PushLifecycleStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `reconcilePush` | `Unit` | `PushLifecycleStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `pushStatus` | `Unit` | `PushLifecycleStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.connection

Connection status and manual network lifecycle.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `getStatus` | `Unit` | `ConnectionStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `reconnectNow` | `Unit` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `disconnect` | `Unit` | `Unit` | `ffi-symbol` | `flare_sdk_disconnect` |
| `getServerClock` | `Unit` | `ServerClockResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `notifyNetworkChange` | `NetworkChangeRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.access

Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `getStatus` | `Unit` | `AccessStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `listAccessPoints` | `Unit` | `AccessPointInfoList` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `pin` | `AccessPinRequest` | `AccessPin` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `unpin` | `Unit` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `refresh` | `Unit` | `AccessRefreshReport` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `importRecovery` | `AccessImportRecoveryRequest` | `AccessRecoveryImport` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `exportDiagnostics` | `Unit` | `JsonValue` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.lifecycle

Platform lifecycle signals the core needs (foreground and background).

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `setAppState` | `SetAppStateRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.update

Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `getState` | `UpdateGetStateRequest` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `check` | `UpdateCheckRequest` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `download` | `UpdateDownloadRequest` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `install` | `Unit` | `UpdateInstallPlan` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `reportInstall` | `UpdateReportInstallRequest` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `defer` | `Unit` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `skip` | `UpdateSkipRequest` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `markPrompted` | `UpdateMarkPromptedRequest` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `setLocale` | `UpdateSetLocaleRequest` | `UpdateStatus` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `getResources` | `UpdateGetResourcesRequest` | `UpdateResources` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.conversations

Conversation query and local conversation state.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `listConversations` | `Unit` | `ListConversationsResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `listConversationsByQuery` | `ConversationListQuery` | `ListConversationsResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `listConversationsIncludingArchived` | `Unit` | `ListConversationsResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `getConversation` | `GetConversationRequest` | `Conversation` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `getOneConversation` | `GetOneConversationRequest` | `Conversation` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `getGroupConversationByUserIds` | `GetGroupConversationByUserIdsRequest` | `Conversation` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `getMultipleConversations` | `GetMultipleConversationsRequest` | `ListConversationsResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `listConversationsPaginated` | `ListConversationsPaginatedRequest` | `ListConversationsResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `listRawConversations` | `Unit` | `ListConversationsResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `getTotalUnread` | `Unit` | `ConversationTotalUnreadResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `bootstrapHomeTimeline` | `BootstrapHomeTimelineRequest` | `HomeTimelineSnapshot` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `openConversationTimeline` | `OpenConversationTimelineRequest` | `ConversationTimelineSnapshot` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `markConversationRead` | `MarkConversationReadRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `setConversationPinned` | `SetConversationPinnedRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `setConversationMuted` | `SetConversationMutedRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `setConversationArchived` | `SetConversationArchivedRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `markConversationUnread` | `MarkConversationUnreadRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `deleteConversation` | `DeleteConversationRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `updateConversationDraft` | `UpdateConversationDraftRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `clearLocalChatHistory` | `ClearLocalChatHistoryRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `clearChatHistoryForSelf` | `ClearLocalChatHistoryRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.messageBuilder

Typed quick-build APIs for all supported message content kinds. Prefer these over raw JSON in adapters.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `listSupportedBuildOperations` | `Unit` | `ListMessageBuildCatalogResponse` | `catalog-static` | `flare_message_build_json` |
| `normalizeRichDocFromMarkdown` | `NormalizeRichDocFromMarkdownRequest` | `RichDocV2Normalized` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `normalizeRichDocFromHtml` | `NormalizeRichDocFromHtmlRequest` | `RichDocV2Normalized` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `normalizeRichDocFromDocJson` | `NormalizeRichDocFromDocJsonRequest` | `RichDocV2Normalized` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `buildAnnouncement` | `BuildAnnouncementMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildAudio` | `BuildAudioMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildCard` | `BuildCardMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildCustom` | `BuildCustomMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildEmoji` | `BuildEmojiMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildFile` | `BuildFileMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildForward` | `BuildForwardMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildImage` | `BuildImageMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildImageGroup` | `BuildImageGroupMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildLinkCard` | `BuildLinkCardMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildLocation` | `BuildLocationMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildMiniProgram` | `BuildMiniProgramMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildNotification` | `BuildNotificationMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildPlaceholder` | `BuildPlaceholderMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildQuote` | `BuildQuoteMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildRichDoc` | `BuildRichDocMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildSchedule` | `BuildScheduleMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildSticker` | `BuildStickerMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildSystem` | `BuildSystemMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildTask` | `BuildTaskMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildText` | `BuildTextMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildThreadReply` | `BuildThreadReplyMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildVideo` | `BuildVideoMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildVote` | `BuildVoteMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |
| `buildWithContent` | `BuildWithContentMessageRequest` | `Message` | `dispatch-json` | `flare_message_build_json` |

## client.messages

Message build, send, query and mutation.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `createTextMessage` | `CreateTextMessageRequest` | `Message` | `ffi-symbol` | `flare_message_create_text` |
| `dispatchMessage` | `MessageDispatchRequest` | `JsonValue` | `dispatch-json` | `flare_message_dispatch_json` |
| `sendMessageNoOss` | `SendMessageRequest` | `SendMessageResponse` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `sendMessage` | `SendMessageRequest` | `SendMessageResponse` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `listMessages` | `ListMessagesRequest` | `ListMessagesResponse` | `ffi-symbol` | `flare_message_list` |
| `recallMessage` | `RecallMessageRequest` | `Unit` | `ffi-symbol` | `flare_message_recall` |
| `editTextByMessageId` | `EditTextByMessageIdRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `deleteMessage` | `DeleteMessageRequest` | `Unit` | `ffi-symbol` | `flare_message_delete` |
| `deleteMessageForSelf` | `DeleteMessageRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `deleteMessageForEveryone` | `DeleteMessageRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `markMessageReadAndBurn` | `MarkMessageReadAndBurnRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `addReaction` | `ReactionMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `removeReaction` | `ReactionMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `pinMessage` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `unpinMessage` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `pinMessageById` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `unpinMessageById` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `markMessage` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `markMessageWithColor` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `unmarkMessage` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `markMessageById` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `unmarkMessageById` | `MessageMutationRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `getMessage` | `GetMessageRequest` | `Message` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `getRawMessage` | `GetMessageRequest` | `JsonValue` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `searchMessages` | `MessageSearchQuery` | `ListMessagesResponse` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `searchMessagesByQuery` | `MessageSearchQuery` | `ListMessagesResponse` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `searchMessagesInConversation` | `MessageSearchQuery` | `ListMessagesResponse` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `readReceiptMembers` | `MessageReadReceiptMembersRequest` | `JsonObject` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `editRichDocByMessageId` | `EditRichDocByMessageIdRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |
| `setTyping` | `SetTypingRequest` | `Unit` | `message-dispatch-json` | `flare_message_dispatch_json` |

## client.sync

Explicit sync operations.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `syncConversationSummaries` | `Unit` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `syncConversationSummariesWithVersions` | `SyncConversationSummariesRequest` | `SyncConversationSummariesResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `bootstrapStartupHome` | `StartupHomeSyncRequest` | `StartupHomeSyncResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `backfillConversationHistory` | `ConversationHistoryBackfillRequest` | `ConversationHistoryBackfillResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `syncConversation` | `SyncConversationRequest` | `Unit` | `ffi-symbol` | `flare_sdk_sync_conversation` |
| `syncMessages` | `SyncMessagesRequest` | `Unit` | `ffi-symbol` | `flare_sdk_sync_messages` |

## client.user

User profile cache (business-fed identity for messages and conversations).

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `upsertUserProfiles` | `UpsertUserProfilesRequest` | `Unit` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.presence

Presence and input state.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `getUserPresence` | `GetUserPresenceRequest` | `UserPresence` | `ffi-symbol` | `flare_sdk_get_user_presence` |
| `batchGetUserPresence` | `BatchGetUserPresenceRequest` | `BatchGetUserPresenceResponse` | `ffi-symbol` | `flare_sdk_batch_get_user_presence` |
| `subscribeUserPresence` | `SubscribeUserPresenceRequest` | `Unit` | `ffi-symbol` | `flare_sdk_subscribe_user_presence` |

## client.media

Media access URL and local cache operations.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `uploadFile` | `UploadFileRequest` | `MediaUploadResponse` | `ffi-symbol` | `flare_media_upload_file` |
| `uploadImage` | `UploadFileRequest` | `MediaUploadResponse` | `ffi-symbol` | `flare_media_upload_image` |
| `uploadVideo` | `UploadFileRequest` | `MediaUploadResponse` | `ffi-symbol` | `flare_media_upload_video` |
| `uploadBytes` | `UploadBytesRequest` | `MediaUploadResponse` | `ffi-symbol` | `flare_media_upload_bytes` |
| `deleteFile` | `DeleteMediaFileRequest` | `DeleteMediaFileResponse` | `ffi-symbol` | `flare_media_delete_file` |
| `getMediaUrl` | `GetMediaUrlRequest` | `MediaAccessUrl` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `getTempDownloadUrl` | `TempDownloadUrlRequest` | `MediaAccessUrl` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `resolveMediaAccess` | `ResolveMediaAccessRequest` | `MediaResolvedAccess` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `cacheRemoteMedia` | `CacheRemoteMediaRequest` | `MediaCacheEntry` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `getMediaCacheStats` | `Unit` | `MediaCacheStats` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `setMediaCacheMaxBytes` | `SetMediaCacheMaxBytesRequest` | `Unit` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `setMediaCacheRoot` | `SetMediaCacheRootRequest` | `Unit` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `clearMediaCache` | `Unit` | `Unit` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `getUserDownloadSubfolder` | `Unit` | `UserDownloadSubfolderResponse` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `setUserDownloadSubfolder` | `SetUserDownloadSubfolderRequest` | `Unit` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `getUserDownloadSavedPath` | `GetUserDownloadSavedPathRequest` | `UserDownloadSavedPathResponse` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `deleteUserDownloadRecord` | `DeleteUserDownloadRecordRequest` | `Unit` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `getUserDownloadDirectory` | `Unit` | `UserDownloadDirectory` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `setUserDownloadDirectory` | `SetUserDownloadDirectoryRequest` | `UserDownloadDirectory` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `downloadToUserDirectory` | `DownloadToUserDirectoryRequest` | `UserFileDownloadResult` | `media-dispatch-json` | `flare_media_dispatch_json` |
| `cancelUserFileDownload` | `CancelUserFileDownloadRequest` | `BooleanResponse` | `ffi-symbol` | `flare_media_cancel_user_file_download` |
| `downloadFileToDownloads` | `DownloadFileToDownloadsRequest` | `UserDownloadSavedPathResponse` | `ffi-symbol` | `flare_media_download_file_to_downloads` |

## client.capabilities

Capability discovery and optional plugin dispatch through capability dispatch ops.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `preparePluginCommand` | `PluginCommandRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pendingPluginCommand` | `PluginCommandRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `reconcilePluginCommand` | `PluginCommandRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `submitPluginCommand` | `PluginCommandRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `acknowledgePluginCommand` | `PluginCommandRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `invokePluginAction` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `presentPluginMessage` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pluginUiAction` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `resolvePluginMessage` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pluginUiCatalog` | `ListCapabilitiesRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pluginComposerActions` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pluginDetail` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pluginPage` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pluginFileUpload` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `pluginAccountEntries` | `PluginUiEvaluationRequest` | `JsonObject` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `invalidatePluginCatalog` | `ListCapabilitiesRequest` | `Unit` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `listCapabilities` | `ListCapabilitiesRequest` | `ListCapabilitiesResponse` | `capability-dispatch-json` | `flare_capability_dispatch_json` |
| `dispatchCapability` | `DispatchCapabilityRequest` | `DispatchCapabilityResponse` | `capability-dispatch-json` | `flare_capability_dispatch_json` |

## client.views

Core observable message/conversation views.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `openTimeline` | `OpenTimelineViewRequest` | `ViewOpenResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `loadOlderTimeline` | `LoadOlderTimelineViewRequest` | `TimelineViewPageResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `loadNewerTimeline` | `LoadNewerTimelineViewRequest` | `TimelineViewPageResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `jumpToLatestTimeline` | `TimelineViewRequest` | `TimelineViewPageResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `timelineSnapshot` | `TimelineViewRequest` | `ViewOpenResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `openConversationList` | `OpenConversationListViewRequest` | `ViewOpenResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
| `close` | `CloseViewRequest` | `CloseViewResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |

## client.events

Typed SDK event stream.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `subscribeEvents` | `SubscribeEventsRequest` | `Subscription` | `ffi-symbol` | `flare_event_subscribe` |
| `subscribeEventsBatch` | `SubscribeEventsRequest` | `Subscription` | `ffi-symbol` | `flare_event_subscribe_batch` |
| `unsubscribe` | `UnsubscribeRequest` | `Unit` | `ffi-symbol` | `flare_event_unsubscribe` |
| `unsubscribeAll` | `Unit` | `Unit` | `ffi-symbol` | `flare_event_unsubscribe_all` |

## client.diagnostics

SDK version and FFI contract diagnostics.

| Method | Request | Response | Transport | C API |
|--------|---------|----------|-----------|-------|
| `getSdkVersion` | `Unit` | `SdkVersion` | `ffi-symbol` | `flare_sdk_version` |
| `getFfiContractVersion` | `Unit` | `FfiContractVersion` | `ffi-symbol` | `flare_sdk_ffi_contract_version` |
| `getDataRoot` | `Unit` | `DataRootResponse` | `ffi-symbol` | `flare_sdk_data_root` |
| `getRuntimeHealth` | `Unit` | `RuntimeHealthResponse` | `contract-invoke-json` | `flare_sdk_invoke_json` |
