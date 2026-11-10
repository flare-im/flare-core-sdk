# Flutter SDK API Coverage Matrix

This matrix tracks how `flare-core-flutter-app` exercises the public `flare_core_flutter_sdk` API surface. The example is a reference workbench: every supported API family should have either a real interactive entry point or an explicit unavailable/diagnostic state.

Legend:

| Status | Meaning |
|--------|---------|
| Real | Backed by a visible interactive flow. |
| Lab | Exposed through SDK Lab for direct probing. |
| Partial | Some APIs are covered, but the family needs more complete UI coverage. |
| Missing | No visible example entry point yet. |
| Optional | Depends on plugin/runtime capability discovery. |

## Lifecycle, Auth, Session, Connection

| API | Status | Entry point |
|-----|--------|-------------|
| `create`, `init` | Real | Login flow and SDK wrapper. |
| `login`（token 由网关签发或应用传入）, `currentUserId` | Real | Login flow and diagnostics. |
| `updateAccessToken` | Lab | SDK Lab token renewal control generates a fresh core token and updates the session. |
| `logout` | Real | Auth state / settings flow. |
| `isConnected`, `sessionActive`, `connection.getConnectionState` | Lab | SDK Lab diagnostics. |
| `connection.disconnect` | Lab | SDK Lab reset/lifecycle controls. |
| `events.unsubscribe`, `events.unsubscribeAll` | Lab | SDK Lab reset/lifecycle controls. |
| `dispose`, `uninit`, `hardReset` | Lab | SDK Lab reset/lifecycle controls. |

## Conversations

| API | Status | Entry point |
|-----|--------|-------------|
| `listConversations`, `listConversationsByQuery` | Real | Conversation list filters. |
| `listConversationsIncludingArchived` | Real | Archived filter. |
| `listConversationsPaginated` | Lab | SDK Lab raw operations. |
| `listRawConversations` | Lab | SDK Lab raw operations. |
| `getConversation`, `getOneConversation` | Real | Chat/details/start single chat flow. |
| `getGroupConversationByUserIds` | Real | Start Chat dialog supports group user-id lists and routes to the group conversation. |
| `getMultipleConversations` | Real | Conversation list More sheet exposes bulk hydrate by conversation id. |
| `bootstrapHomeTimeline`, `openConversationTimeline` | Real | Core home snapshot action and chat enter/open timeline path. |
| `markConversationRead`, `markConversationUnread` | Real | Chat enter/read actions and conversation actions. |
| `setConversationPinned`, `setConversationMuted`, `setConversationArchived` | Real | Conversation actions/details. |
| `updateConversationDraft`, `clearLocalChatHistory`, `deleteConversation` | Real | Composer/details actions. |

## Messages And Timeline

| API | Status | Entry point |
|-----|--------|-------------|
| `createTextMessage`, `sendMessage` | Real | Chat composer. |
| `sendMessageNoOss` | Lab | SDK Lab operation template builds raw message then sends through no-OSS path. |
| `dispatchMessage` | Lab | App facade uses dispatch for several actions; SDK Lab operation templates cover typed/raw command probes. |
| `listMessages` | Real | Chat timeline. |
| `getMessage`, `getRawMessage` | Lab | Raw preview exists in state path; SDK Lab operation templates expose both decoded and raw fetch. |
| `searchMessages`, `searchMessagesByQuery`, `searchMessagesInConversation` | Real | Global and in-conversation search. |
| `recallMessage`, `editTextByMessageId`, `deleteMessage`, `deleteMessageForSelf`, `deleteMessageForEveryone` | Real | Message long-press actions. |
| `editRichDocByMessageId` | Real | Own rich-doc messages can be edited from the chat long-press menu; Markdown/HTML/doc-json input is normalized or validated through core before dispatch. |
| `addReaction`, `removeReaction` | Real | Message long-press reactions. |
| `pinMessage`, `unpinMessage`, `pinMessageById`, `unpinMessageById` | Lab | By-id path covered in chat; object path exposed through SDK Lab templates. |
| `markMessage`, `markMessageWithColor`, `unmarkMessage`, `markMessageById`, `unmarkMessageById` | Lab | Chat covers important mark by id; SDK Lab exposes color/unmark variants. |
| `setTyping` | Real | Composer typing flow. |

## Message Builder

| API family | Status | Entry point |
|------------|--------|-------------|
| `listSupportedBuildOperations` | Lab | SDK Lab builder catalog. |
| `buildText`, `buildImage`, `buildVideo`, `buildAudio`, `buildFile`, `buildLocation`, `buildCard`, `buildSticker`, `buildEmoji`, `buildQuote` | Lab | SDK Lab generates typed builder requests from the live builder catalog; composer covers common paths. |
| `buildLinkCard`, `buildForward`, `buildThreadReply`, `buildMiniProgram`, `buildImageGroup` | Lab | SDK Lab generates typed builder requests from the live builder catalog. |
| `buildRichDoc` | Real | Composer Aa flow normalizes Markdown/HTML through core RichDoc v2 APIs, builds `create_rich_doc`, and sends through the normal chat pipeline. |
| `buildSystem`, `buildNotification`, `buildVote`, `buildTask`, `buildSchedule`, `buildAnnouncement`, `buildCustom`, `buildPlaceholder`, `buildWithContent` | Lab | SDK Lab generates typed builder requests from the live builder catalog and shows request/response preview. |
| Rich-doc normalize APIs | Real | Composer Aa flow uses Markdown/HTML normalization; SDK Lab still exposes Markdown, HTML, and doc-json probes. |

## Sync And Presence

| API | Status | Entry point |
|-----|--------|-------------|
| `syncConversationSummaries` | Lab | SDK Lab raw operations. |
| `getUserPresence` | Lab | SDK Lab Presence Center. |
| `batchGetUserPresence`, `subscribeUserPresence` | Lab | Chat header/details use batch/subscribe; SDK Lab exposes current-user and editable batch probes. |

## Media

| API | Status | Entry point |
|-----|--------|-------------|
| `uploadFile`, `uploadImage`, `uploadVideo`, `uploadBytes` | Lab | Composer/media paths and SDK Lab file/image/video/bytes upload probes exist. |
| `deleteFile`, `getMediaUrl`, `getTempDownloadUrl`, `resolveMediaAccess`, `cacheRemoteMedia` | Lab | SDK Lab operation templates and wrapper probes. |
| `getMediaCacheStats`, `setMediaCacheMaxBytes`, `setMediaCacheRoot`, `clearMediaCache` | Lab | SDK Lab Media Center with runtime diagnostics for cache state, media events, and media failures. |
| `getUserDownloadSubfolder`, `setUserDownloadSubfolder`, `getUserDownloadSavedPath`, `deleteUserDownloadRecord`, `cancelUserFileDownload`, `downloadFileToDownloads` | Lab | SDK Lab Media Center includes typed user-download controls and operation templates. |

## Capabilities, Events, Diagnostics

| API | Status | Entry point |
|-----|--------|-------------|
| `listCapabilities` | Lab | SDK Lab Capability Center. |
| `dispatchCapability` | Lab | SDK Lab Capability probes. |
| `subscribeEvents`, typed listeners, local listener unsubscribe | Real | App event bridge and SDK Lab event console. |
| `unsubscribe`, `unsubscribeAll` | Lab | SDK Lab reset/lifecycle controls. |
| `getSdkVersion`, `getFfiContractVersion`, `getDataRoot` | Lab | SDK Lab diagnostics. |

## Next Coverage Priorities

1. Generate strongly typed platform forms from sdk-spec/catalog descriptors instead of using generic JSON editors.
2. Move reusable Flutter app-client/session orchestration into `packages/flare-core-flutter-sdk` when the API stabilizes.
