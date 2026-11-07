# Client Model Reference

> Generated from split sdk-spec files

Models are generated from `sdk-spec/models/*.json` and mirror stable message/conversation fields from `flare-im-core-sdk`.
Field names shown here are SDK-facing lowerCamelCase names; `wireName` records the current core JSON field.

## Conversations

Core-owned conversation DTOs derived from Rust JsonSchema.

### Enums

- `ConversationType`: ConversationType Values: `unspecified`, `single`, `group`, `ai`, `system`, `customer`, `temp`, `channel`, `broadcast`

- `TimelineSyncState`: TimelineSyncState Values: `localReady`, `synced`, `partial`

### ConversationParticipant

SDK 本地会话参与者快照。单聊不依赖该结构；群聊/频道/客服等非单聊用它支撑群通话、成员面板和后续设置页。

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `attributes` | `attributes` | `StringMap` | yes |  |
| `joinedAt` | `joinedAt` | `UInt64` | yes |  |
| `muted` | `muted` | `Boolean` | yes |  |
| `name` | `name` | `DisplayName` | yes | 成员在这个会话里显示成什么（成员列表、@ 选择用）：别名、会话内昵称、资料名， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的成员都带它。 |
| `nickname` | `nickname` | `String` | yes |  |
| `pinned` | `pinned` | `Boolean` | yes |  |
| `roles` | `roles` | `StringList` | yes |  |
| `userId` | `userId` | `String` | yes |  |

### MessagePreview

MessagePreview

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `messageId` | `messageId` | `String` | yes |  |
| `senderId` | `senderId` | `String` | yes |  |
| `text` | `text` | `String` | yes |  |
| `time` | `time` | `UInt64` | yes | 毫秒时间戳 |
| `type` | `type` | `Int32` | yes |  |

### Conversation

SDK 层会话类型：内部统一使用，从 proto ConversationSummary 获取后即转换为此类型。 与 message.rs 的 IMMessage 一致：扁平字段、serde camelCase。

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `avatarUrl` | `avatarUrl` | `String` | yes |  |
| `badge` | `badge` | `String` | no |  |
| `businessType` | `businessType` | `String` | yes |  |
| `channelId` | `channelId` | `String` | yes | 会话路由 ID：单聊为对方 user_id；群/频道为业务 channel（与 proto `channel_id` 一致） |
| `conversationId` | `conversationId` | `String` | yes |  |
| `conversationType` | `conversationType` | `ConversationType` | yes |  |
| `createdAt` | `createdAt` | `UInt64` | yes |  |
| `description` | `description` | `String` | no |  |
| `displayName` | `displayName` | `String` | yes | 业务名（服务端或业务 SDK 给的会话名），可为空，永不为 id；列表标题读 `title`。 |
| `draft` | `draft` | `String` | no |  |
| `ext` | `ext` | `StringMap` | yes | 扩展键值（与 proto ext 对应） |
| `isArchived` | `isArchived` | `Boolean` | yes |  |
| `isMentionOnly` | `isMentionOnly` | `Boolean` | no | Notification preference. None means the sync source did not supply it. |
| `isMuted` | `isMuted` | `Boolean` | yes |  |
| `isPinned` | `isPinned` | `Boolean` | yes |  |
| `lastMessage` | `lastMessage` | `MessagePreview` | no |  |
| `lastMessageAt` | `lastMessageAt` | `UInt64` | no |  |
| `lastMessageId` | `lastMessageId` | `String` | no |  |
| `lastMessagePreview` | `lastMessagePreview` | `String` | no |  |
| `lastReadSeq` | `lastReadSeq` | `UInt64` | yes | 已读序列号（与 read_seq 同义） |
| `lastSender` | `lastSender` | `DisplayName` | no | 最后一条消息的发送者名（人名解析链，群会话含会话内昵称）；没有最后一条消息时缺省。 读取时由核心投影，不落库。 |
| `lastSenderAvatarUrl` | `lastSenderAvatarUrl` | `String` | yes | 最后一条消息发送者头像 URL |
| `lastSenderId` | `lastSenderId` | `String` | no |  |
| `lastSenderNickname` | `lastSenderNickname` | `String` | yes | 旧字段：最后一条消息发送者在身份缓存里的资料名（是真名字时），否则为本地已存的名字或空串， 永不为 id。列表读 `last_sender`。 |
| `maxSeq` | `maxSeq` | `UInt64` | yes |  |
| `memberPreview` | `memberPreview` | `ConversationParticipantList` | yes | 摘要级成员预览，最多少量成员，不能作为完整成员列表使用。 |
| `membersCount` | `membersCount` | `UInt32` | yes |  |
| `mentionCount` | `mentionCount` | `UInt32` | yes |  |
| `mentionMe` | `mentionMe` | `Boolean` | yes |  |
| `participantVersion` | `participantVersion` | `UInt64` | yes | 服务端成员读模型版本。完整成员通过独立 participants 同步拉取。 |
| `participants` | `participants` | `ConversationParticipantList` | yes | 已按需同步到本地的完整成员快照；会话摘要同步不会填充该字段。 |
| `peerReadSeq` | `peerReadSeq` | `UInt64` | yes | 对端（其他成员）最大已读序列号；用于发送方已读双勾在重连/重登后恢复。 由服务端同步摘要 `ext.peer_read_seq` 下发并持久化。 |
| `remark` | `remark` | `String` | no |  |
| `role` | `role` | `String` | no |  |
| `title` | `title` | `DisplayName` | yes | 列表与聊天头显示的会话标题：备注、单聊对端人名、业务名、无名群的成员名拼接， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的会话都带它。 |
| `unreadCount` | `unreadCount` | `UInt32` | yes |  |
| `updatedAt` | `updatedAt` | `UInt64` | yes |  |
| `updatedAtTs` | `updatedAtTs` | `UInt64` | no | 更新时间戳（毫秒，用于排序/筛选） |
| `version` | `version` | `UInt64` | yes |  |
| `visibleAfterSeq` | `visibleAfterSeq` | `UInt64` | yes | 当前用户的历史可见边界；seq <= visible_after_seq 的消息不可见，不参与冷启动回灌。 |

### BootstrapHomeTimelineRequest

BootstrapHomeTimelineRequest

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationLimit` | `conversationLimit` | `UInt32` | yes |  |

### OpenConversationTimelineRequest

OpenConversationTimelineRequest

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes |  |
| `messageLimit` | `messageLimit` | `UInt32` | yes |  |

### HomeTimelineSnapshot

HomeTimelineSnapshot

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversations` | `conversations` | `ConversationList` | yes |  |
| `syncState` | `syncState` | `TimelineSyncState` | yes |  |
| `totalUnread` | `totalUnread` | `UInt64` | yes | Unread total across all conversations, not only the returned ones (the rule of `conversation.total_unread`). |

### ConversationTimelineSnapshot

ConversationTimelineSnapshot

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversation` | `conversation` | `Conversation` | no |  |
| `hasMore` | `hasMore` | `Boolean` | yes |  |
| `messages` | `messages` | `MessageList` | yes |  |

### ConversationListQuery

ConversationListQuery

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationTypes` | `conversationTypes` | `ConversationTypeList` | yes |  |
| `cursor` | `cursor` | `String` | no | cursor 为会话 ID，表示从该会话之后开始。 |
| `hasDraftOnly` | `hasDraftOnly` | `Boolean` | yes |  |
| `hasMarkedMessages` | `hasMarkedMessages` | `Boolean` | yes | 标记消息所在会话。core 当前没有“会话标签”模型，因此只支持消息标记聚合。 |
| `includeArchived` | `includeArchived` | `Boolean` | yes |  |
| `keyword` | `keyword` | `String` | no |  |
| `limit` | `limit` | `UInt32` | no |  |
| `mentionMeOnly` | `mentionMeOnly` | `Boolean` | yes |  |
| `mutedOnly` | `mutedOnly` | `Boolean` | no |  |
| `pinnedOnly` | `pinnedOnly` | `Boolean` | yes |  |
| `unreadOnly` | `unreadOnly` | `Boolean` | yes |  |

## Messages

Core-owned message DTOs derived from Rust JsonSchema.

### Enums

- `MessageSearchKind`: MessageSearchKind Values: `image`, `video`, `audio`, `message`, `text`, `media`, `file`

### ReactionEntry

ReactionEntry

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `count` | `count` | `UInt32` | yes |  |
| `emoji` | `emoji` | `String` | yes |  |
| `userIds` | `userIds` | `StringList` | yes |  |

### MessageLocalState

MessageLocalState

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `failed` | `failed` | `Boolean` | yes | 是否失败 |
| `isLocal` | `isLocal` | `Boolean` | yes | 本地消息 |
| `sending` | `sending` | `Boolean` | yes | 是否发送中 |
| `sortTs` | `sortTs` | `UInt64` | yes | 本地列表排序时间（毫秒），**不是**服务端会话 `conversation_seq`。 用途：待发/未 ACK 消息常保持 `conversation_seq == 0`，可用本字段稳定停留在本地时间线尾部。 已分配 `conversation_seq` 的服务端消息必须回到 seq 优先排序，避免设备时钟偏移污染权威顺序。 |
| `uploadProgress` | `uploadProgress` | `UInt32` | yes | 本地媒体上传进度，范围 0..=100。 |
| `uploading` | `uploading` | `Boolean` | yes | 本地媒体上传中；仅用于 SDK 本地时间线展示，不写入服务端协议语义。 |

### Message

SDK 层消息类型：与 message.proto 的 Message 属性一致，content 为解码后的 Elem； 另保留 raw_content 与 proto 一致用于持久化/网络，并增加发送者展示字段。

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `attributes` | `attributes` | `StringMap` | yes |  |
| `channelId` | `channelId` | `String` | yes | 会话频道 ID：单聊=对方 user_id，群聊=群 ID，频道/话题=对应 ID |
| `clientCreatedAt` | `clientCreatedAt` | `UInt64` | yes | 客户端本地创建时间，Unix epoch millis。 |
| `clientMsgId` | `clientMsgId` | `String` | yes | 客户端生成ID（去重） |
| `content` | `content` | `MessageContent` | no | proto结构 |
| `conversationId` | `conversationId` | `String` | yes | 会话ID |
| `conversationSeq` | `conversationSeq` | `UInt64` | yes | 会话内持久化 replay 序列号。 |
| `conversationType` | `conversationType` | `Int32` | yes | 会话类型 |
| `createdAt` | `createdAt` | `UInt64` | yes | 消息创建时间，Unix epoch millis。 |
| `extensions` | `extensions` | `BinaryMap` | yes | 扩展数据；未提供时为空。 |
| `isEdited` | `isEdited` | `Boolean` | yes |  |
| `isRead` | `isRead` | `Boolean` | yes |  |
| `isRecalled` | `isRecalled` | `Boolean` | yes |  |
| `localState` | `localState` | `MessageLocalState` | no |  |
| `mentionAll` | `mentionAll` | `Boolean` | yes |  |
| `mentionUsers` | `mentionUsers` | `StringList` | yes |  |
| `messageType` | `messageType` | `Int32` | yes | 消息类型 |
| `quotePreview` | `quotePreview` | `String` | no |  |
| `reactions` | `reactions` | `ReactionEntryList` | yes | 表情反应快照（由 ReactionEvent 驱动更新并持久化） |
| `replyTo` | `replyTo` | `String` | no |  |
| `sender` | `sender` | `DisplayName` | yes | 发送者名：别名、群会话里的会话内昵称、资料名、发送时快照（`sender_name`），都没有时为 结构化的「无名」。读取时由核心投影，不落库；SDK 交出的消息都带它。 |
| `senderAvatar` | `senderAvatar` | `String` | yes |  |
| `senderDisplayName` | `senderDisplayName` | `String` | yes | 旧字段：身份缓存里发送者的资料名（是真名字时），否则为空，永不为 id。读发送者名用 `sender`。 |
| `senderId` | `senderId` | `String` | yes | 发送者 |
| `senderName` | `senderName` | `String` | yes |  |
| `serverId` | `serverId` | `String` | yes | 服务端唯一ID |
| `source` | `source` | `Int32` | yes | 消息来源 |
| `status` | `status` | `Int32` | yes |  |
| `textPreview` | `textPreview` | `String` | yes | 列表、搜索、绑定层使用的纯文本预览。 |
| `threadId` | `threadId` | `String` | no | 话题/线程根消息 ID；普通消息为空，话题回复使用该 typed field。 |
| `updatedAt` | `updatedAt` | `UInt64` | yes |  |
| `version` | `version` | `UInt64` | yes |  |
| `timelineKey` | `timelineKey` | `String` | yes | Core-computed stable row key for timeline rendering. |
| `timelineSortTs` | `timelineSortTs` | `UInt64` | yes | Core-computed timeline sort timestamp in milliseconds. |
| `receipt` | `receipt` | `MessageReceiptView` | no | Core-computed receipt projection (status and, on the viewer's own group messages, the read summary); always present on messages the SDK returns. |

### MessageSearchQuery

MessageSearchQuery

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | no |  |
| `fromTime` | `fromTime` | `UInt64` | no | 起始消息时间（毫秒，含）。 |
| `includeRecalled` | `includeRecalled` | `Boolean` | yes | 默认排除已撤回消息。 |
| `keyword` | `keyword` | `String` | no |  |
| `kinds` | `kinds` | `MessageSearchKindList` | yes |  |
| `limit` | `limit` | `UInt32` | yes |  |
| `senderId` | `senderId` | `String` | no |  |
| `toTime` | `toTime` | `UInt64` | no | 截止消息时间（毫秒，含）。 |

## Session

Core-owned DTOs derived from Rust JsonSchema.

### PushTokenInput

PushTokenInput

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `platform` | `platform` | `String` | yes | Native platform: android, ios or harmony. |
| `provider` | `provider` | `String` | yes | OS delivery provider: fcm, apns or getui. |
| `token` | `token` | `String` | yes | OS-issued token. Never log or persist outside protected native storage. |

### ClearPushTokenRequest

ClearPushTokenRequest

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `provider` | `provider` | `String` | yes | Provider whose current desired OS token is invalidated. |

### SetPushPermissionRequest

SetPushPermissionRequest

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `allowed` | `allowed` | `Boolean` | yes | Current OS permission, including explicit denial or revocation. |

### PushLifecycleStatus

PushLifecycleStatus

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `configuredProviders` | `configuredProviders` | `UInt32` | yes | Number of OS providers configured in memory. |
| `lastError` | `lastError` | `String` | no | Fixed safe error category; no token, URL, bearer or driver detail. |
| `pendingRevocations` | `pendingRevocations` | `UInt32` | yes | Unresolved revoke intents, including writes with an unknown result. |
| `registeredProviders` | `registeredProviders` | `UInt32` | yes | Providers confirmed for the current session, not vendor delivery. |
| `state` | `state` | `String` | yes | disabled, waitingForSession, waitingForToken, pending or registered. |

## Sync

Core-owned sync DTOs derived from Rust JsonSchema.

### ConversationVersion

Version stamp used by sync summary reconciliation.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes |  |
| `version` | `version` | `UInt64` | yes |  |

### SyncConversationSummariesRequest

Request for summary sync with client-known conversation versions.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `knownVersions` | `knownVersions` | `ConversationVersionList` | yes |  |

### SyncConversationSummariesResponse

Conversations whose local version is missing or newer than the caller's snapshot.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `changedConversations` | `changedConversations` | `ConversationVersionList` | yes |  |

### StartupHomeSyncRequest

Core-owned startup sync policy shared by all platform SDKs.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `backfillVisibleHistories` | `backfillVisibleHistories` | `Boolean` | yes |  |
| `conversationLimit` | `conversationLimit` | `UInt32` | yes |  |
| `historyBackfillLimit` | `historyBackfillLimit` | `Int32` | yes |  |
| `historyBackfillMaxConversations` | `historyBackfillMaxConversations` | `UInt32` | yes |  |
| `historyBackfillMaxPagesPerConversation` | `historyBackfillMaxPagesPerConversation` | `UInt32` | yes |  |
| `startBackgroundConvergence` | `startBackgroundConvergence` | `Boolean` | yes |  |

### StartupHomeSyncResponse

First usable home snapshot plus diagnostics about the startup sync path.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `backgroundConvergenceStarted` | `backgroundConvergenceStarted` | `Boolean` | yes |  |
| `coldSyncPerformed` | `coldSyncPerformed` | `Boolean` | yes |  |
| `degradedReason` | `degradedReason` | `String` | no |  |
| `servedFromLocal` | `servedFromLocal` | `Boolean` | yes |  |
| `snapshot` | `snapshot` | `HomeTimelineSnapshot` | yes |  |

## Session

Session utility request and response models.

### SetHeartbeatNatTimeoutRequest

Runtime NAT timeout hint for adaptive heartbeat scheduling. Omit or pass null to clear the hint.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `natTimeoutSecs` | `natTimeoutSecs` | `UInt32` | no | Observed NAT idle timeout in seconds. |

### HeartbeatEffectiveIntervalResponse

Currently effective heartbeat interval for diagnostics and platform observability.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `connected` | `connected` | `Boolean` | yes | Whether a live transport is available. |
| `intervalMs` | `intervalMs` | `UInt64` | no | Effective heartbeat interval in milliseconds when connected. |
| `intervalSecs` | `intervalSecs` | `UInt64` | no | Effective heartbeat interval in seconds when connected. |

### SetConnectTokenRefresherRequest

Installs or removes the host's connect token refresher at the native boundary. Platform packages build it from their one host function; hosts do not send it themselves.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `enabled` | `enabled` | `Boolean` | yes | Whether a refresher is installed. |

### CompleteConnectTokenRefreshRequest

Answer to one connect token refresh request.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `requestId` | `requestId` | `UInt64` | yes | Request id the core asked with. |
| `token` | `token` | `String` | no | The new connect token; omitted or empty when none could be obtained. |

## Connection

Connection status, network-change notifications and the server clock.

### Enums

- `NetworkInterfaceKind`: Standardized platform network interface kind, part of the local network fingerprint. Values: `unknown`, `wifi`, `cellular`, `ethernet`, `other`

- `ConnectionPhase`: Where the link supervisor is: the one connection state hosts and the Kit ConnectionNotice read. Values: `idle`, `connecting`, `syncing`, `online`, `switching`, `reconnecting`, `waitingForNetwork`, `serviceUnavailable`, `actionRequired`

- `ConnectionQuality`: Line quality while online. Neither value shows a banner; poor shows on the diagnostics page. Values: `good`, `poor`

### NetworkChangeRequest

Platform network-change notification. The link supervisor alone decides whether and how to reconnect.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `available` | `available` | `Boolean` | no | Whether a network route is currently available. Omitted means available. |
| `interface` | `interface` | `NetworkInterfaceKind` | no | Standardized platform network interface hint. |
| `expensive` | `expensive` | `Boolean` | no | Whether the active route is considered expensive by the platform. |
| `metered` | `metered` | `Boolean` | no | Whether the active route is metered. |
| `reason` | `reason` | `String` | no | Optional platform reason string for diagnostics. |
| `fingerprintHint` | `fingerprintHint` | `String` | no | Coarse network identity (native: Wi-Fi gateway prefix or cellular MCC-MNC; web: navigator.connection.type). Hashed locally with interface into the network fingerprint that keys access point health; never sent anywhere. Never pass an SSID. |

### ConnectionStatus

Payload of connection://status and the value of connection.getStatus. Every field is present (null without a value): hosts replace their copy whole on every event and hand it to the Kit ConnectionNotice unchanged.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `phase` | `phase` | `ConnectionPhase` | yes | Where the link supervisor is. |
| `quality` | `quality` | `ConnectionQuality` | no | Line quality; set only while online. |
| `accessPointId` | `accessPointId` | `String` | no | Current (or connecting) access point. |
| `cellId` | `cellId` | `String` | no | Cell of the current access point. |
| `regionId` | `regionId` | `String` | no | Region of the current access point. |
| `protocol` | `protocol` | `String` | no | Transport of the current connection: quic or ws. |
| `rttMs` | `rttMs` | `UInt32` | no | Latest heartbeat round trip (the handshake time before the first sample). |
| `attempt` | `attempt` | `UInt32` | yes | Which round of the current recovery this is; zero once online. |
| `nextRetryAt` | `nextRetryAt` | `Int64` | no | When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay). |
| `reason` | `reason` | `String` | no | actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: failure, drain, failback, manual or manifest. |
| `developmentMode` | `developmentMode` | `Boolean` | yes | Endpoints come from development-mode configuration: the Kit shows its development badge in every phase. |

### ServerClockResponse

The core's estimate of how far the server clock is from this device's.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `offsetMs` | `offsetMs` | `Int64` | yes | Server clock minus device clock, in milliseconds; 0 until estimated. |
| `estimated` | `estimated` | `Boolean` | yes | Whether the offset rests on a server frame received this session. |

## Access

Access directory status, access point health, manual pinning, manifest refresh, recovery links and access events.

### AccessPin

A manual access point pin.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `accessPointId` | `accessPointId` | `String` | yes | The pinned access point. |
| `expiresAtMs` | `expiresAtMs` | `Int64` | yes | When the pin lapses, Unix milliseconds; an app restart also clears it. |

### AccessPinRequest

Pins one access point of the home cell.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `accessPointId` | `accessPointId` | `String` | yes | Access point to pin, as listed by access.listAccessPoints. |

### AccessConnectAck

Diagnostics the gateway returned in CONNECT_ACK for the current connection; shown only, nothing acts on them.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `gatewayId` | `gatewayId` | `String` | no | Gateway instance serving the connection. |
| `accessPointId` | `accessPointId` | `String` | no | Access point the server reports for the connection, when its gateway is configured with one. |
| `accessSerial` | `accessSerial` | `UInt64` | no | Newest access manifest serial the server knows. |
| `heartbeatIntervalHintSec` | `heartbeatIntervalHintSec` | `UInt32` | no | Gateway heartbeat interval in seconds; the heartbeat itself follows the access policy. |
| `accessPointMismatch` | `accessPointMismatch` | `Boolean` | yes | The server reports a different access point than the client chose; logged and counted, the connection stays up. |

### AccessStatus

Access directory and current link summary for the diagnostics page.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `loaded` | `loaded` | `Boolean` | yes | Whether the directory holds a usable manifest. False means there is no access point to connect to until bootstrap or a recovery link brings one. |
| `serial` | `serial` | `UInt64` | yes | Serial of the loaded access manifest; 0 before loading. |
| `source` | `source` | `String` | no | Where the manifest came from: seed, https:<mirror base>, wellKnown:<apId>, recovery, development, or none when the directory is empty. A restart keeps the original source. |
| `stale` | `stale` | `Boolean` | yes | Whether the manifest is past expiresAtMs: it still connects, and refresh retries every 10 minutes. |
| `developmentMode` | `developmentMode` | `Boolean` | yes | Endpoints come from development-mode configuration. |
| `issuedAtMs` | `issuedAtMs` | `Int64` | no | When the manifest was issued, Unix milliseconds; absent with an empty directory. |
| `expiresAtMs` | `expiresAtMs` | `Int64` | no | When the manifest expires, Unix milliseconds; absent with an empty directory. |
| `fetchedAtMs` | `fetchedAtMs` | `Int64` | no | When the manifest reached this device, Unix milliseconds; absent for a seed or development mode. |
| `regionId` | `regionId` | `String` | no | Home region. |
| `cellId` | `cellId` | `String` | no | Home cell. |
| `keystateSerial` | `keystateSerial` | `UInt64` | no | Serial of the loaded signing key state. |
| `accessPointId` | `accessPointId` | `String` | no | Access point the IM connection is on. |
| `protocol` | `protocol` | `String` | no | Transport of the IM connection: quic or ws. |
| `pinned` | `pinned` | `AccessPin` | no | The manual pin, when one is in force. |
| `connectAck` | `connectAck` | `AccessConnectAck` | no | CONNECT_ACK diagnostics of the current connection; absent without one. |
| `refresh` | `refresh` | `AccessRefreshStatus` | no | Manifest refresh progress; absent in development mode. |
| `recovering` | `recovering` | `AccessRecoveringStatus` | no | Present only while every access point has failed and recovery is running. |

### AccessRefreshStatus

Progress of the periodic manifest refresh.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `lastAttemptAtMs` | `lastAttemptAtMs` | `Int64` | no | When the last round ran, Unix milliseconds. |
| `lastSuccessAtMs` | `lastSuccessAtMs` | `Int64` | no | When a source last gave a trusted answer, Unix milliseconds. |
| `lastOutcome` | `lastOutcome` | `String` | no | Outcome of the last round: adopted, upToDate, oldValues or failed; absent before the first round. |
| `nextAtMs` | `nextAtMs` | `Int64` | no | When the next round runs, Unix milliseconds; absent while recovering without a network. |

### AccessRecoveringStatus

Recovery state while every access point has failed.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `sinceMs` | `sinceMs` | `Int64` | yes | When recovery began, Unix milliseconds. |
| `rounds` | `rounds` | `UInt32` | yes | Bootstrap rounds run so far. |
| `nextRoundAtMs` | `nextRoundAtMs` | `Int64` | no | When the next round runs, Unix milliseconds; absent while the device has no network. |

### AccessRefreshAttempt

One source tried during a refresh round. Sources the round never reached are not listed.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `source` | `source` | `String` | yes | The source: https:<base>, wellKnown:<apId> or doh:<resolver>. |
| `tier` | `tier` | `String` | yes | Tier: mirror, wellKnown, pointer (a mirror resolved through DoH) or resolver (the DoH resolver itself). |
| `document` | `document` | `String` | yes | Document fetched: access, keys or pointer. |
| `result` | `result` | `String` | yes | Result: adopted, notModified, sameSerial, olderSerial, rejected, failed or resolved. |
| `code` | `code` | `String` | no | Stable cross-platform code of a rejection or failure: badSignature, rollback, keyCert.expired, revoked, wrongPayloadType, wrongBootstrapId, tooLarge, malformedEnvelope, invalidPayload, unknownKey, unsupportedSchema, noNetwork, unreachable, tls, timeout, cancelled or http.<status>. |
| `serial` | `serial` | `UInt64` | no | Serial of the document, when one was read. |

### AccessRefreshReport

Result of one refresh round.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `outcome` | `outcome` | `String` | yes | adopted (a new manifest was taken), upToDate (a source confirmed there is no update), oldValues (notified mode only got old values; a manual refresh never reports it), failed (no source gave a trusted answer) or skipped (development mode). |
| `mode` | `mode` | `String` | yes | Round mode: background, notified or recovering. |
| `serial` | `serial` | `UInt64` | yes | Directory serial when the round ended. |
| `source` | `source` | `String` | no | Source of the adopted manifest, in the form of AccessStatus.source; absent when nothing was adopted. |
| `keystateSerial` | `keystateSerial` | `UInt64` | no | Serial of the current key state document. |
| `attempts` | `attempts` | `AccessRefreshAttemptList` | yes | Every source tried, in order. |

### AccessImportRecoveryRequest

Imports a recovery link.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `link` | `link` | `String` | yes | The flare-recover:// deep link or QR code content, verbatim. |

### AccessRecoveryImport

Result of importing a recovery link.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `outcome` | `outcome` | `String` | yes | adopted, unchanged (this link was already imported) or rejected. |
| `code` | `code` | `String` | no | Why a link was rejected: a code of AccessRefreshAttempt.code or developmentMode. Commonly rollback (the link is older than this device's manifest) or badSignature. |
| `serial` | `serial` | `UInt64` | yes | Directory serial after the import. |

### AccessPointInfo

One access point of the home cell with its health on the current network.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `accessPointId` | `accessPointId` | `String` | yes | Access point id. |
| `regionId` | `regionId` | `String` | yes | Region the access point is in. |
| `host` | `host` | `String` | yes | Host name shown on the diagnostics page. |
| `status` | `status` | `String` | yes | Manifest status: active, draining, disabled or unknown. |
| `rttMs` | `rttMs` | `Double` | no | Smoothed round trip on the current network, when measured. |
| `breaker` | `breaker` | `String` | yes | Circuit breaker state: closed, open or halfOpen. |
| `protocolWinner` | `protocolWinner` | `String` | no | Protocol that last won the race on this network: quic or ws. |
| `pinned` | `pinned` | `Boolean` | yes | Whether this access point is manually pinned. |
| `current` | `current` | `Boolean` | yes | Whether the IM connection is on this access point. |

### AccessEndpoint

One side of an access point switch.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `ap` | `ap` | `String` | yes | Access point id. |
| `protocol` | `protocol` | `String` | yes | Transport: quic or ws. |

### AccessSwitchedEvent

Payload of access://switched: the IM connection moved to another access point (sent once, when the new connection is ready).

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `from` | `from` | `AccessEndpoint` | yes | Where the connection was. |
| `to` | `to` | `AccessEndpoint` | yes | Where the connection is now. |
| `reason` | `reason` | `String` | yes | Why: failure, drain, failback, manual or manifest. |

### AccessChanges

What a newly accepted access manifest changed.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `accessPointsAdded` | `accessPointsAdded` | `StringList` | yes | Access points that appeared. |
| `accessPointsRemoved` | `accessPointsRemoved` | `StringList` | yes | Access points that disappeared. |
| `policyChanged` | `policyChanged` | `Boolean` | yes | Whether the client link policy changed. |

### AccessChangedEvent

Payload of access://changed: a new access manifest was accepted. Sent for every adoption; a periodic re-signature has empty changes.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `serial` | `serial` | `UInt64` | yes | Serial of the accepted manifest. |
| `source` | `source` | `String` | yes | Where it came from, in the form of AccessStatus.source. |
| `stale` | `stale` | `Boolean` | yes | Whether it is past its expiry. |
| `developmentMode` | `developmentMode` | `Boolean` | yes | Endpoints come from development-mode configuration. |
| `changes` | `changes` | `AccessChanges` | yes | What changed against the previous manifest. |

## Lifecycle

Platform lifecycle signals.

### Enums

- `AppState`: Whether the app is in the foreground or the background. Values: `foreground`, `background`

### SetAppStateRequest

Foreground and background notification from the platform lifecycle.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `appState` | `appState` | `AppState` | yes | Current application state. |

## Update

Update center status, install plans and update.* requests.

### UpdateGetStateRequest

Reads the update state.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `foreground` | `foreground` | `Boolean` | no | The app just returned to the foreground: count that first. |

### UpdateCheckRequest

Checks for an update.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `manual` | `manual` | `Boolean` | yes | The user asked: no frequency limit, and a failure lands in UpdateStatus.error. |

### UpdateDownloadRequest

Downloads the package of the offered release.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `allowMetered` | `allowMetered` | `Boolean` | yes | The user agreed to download on a metered network. |

### UpdateReportInstallRequest

What the platform package did with the install plan.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `outcome` | `outcome` | `String` | yes | started, completed, cancelled or failed. |
| `code` | `code` | `String` | no | update.* code when outcome is failed. |

### UpdateSkipRequest

Skips one optional version.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `build` | `build` | `UInt64` | yes | Build to skip. |

### UpdateMarkPromptedRequest

A prompt really appeared.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `build` | `build` | `UInt64` | no | Build the prompt is about; absent when a forced update has no release yet. |
| `form` | `form` | `String` | yes | sheet, modal or fullscreen. |

### UpdateSetLocaleRequest

Chooses the language of the release notes and blockReason.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `locale` | `locale` | `String` | yes | BCP 47 tag, for example zh-Hant-TW. |

### UpdateGetResourcesRequest

Reads the resource packs of this run.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|

### UpdateResourcePack

One verified resource pack. Data only; the Kit and the host interpret it.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `id` | `id` | `String` | yes | Pack id. |
| `kind` | `kind` | `String` | yes | strings, tokens, emoji or help. |
| `packVersion` | `packVersion` | `UInt64` | yes | Pack version. |
| `contentJson` | `contentJson` | `String` | yes | The pack file as text, a flare.resource.v1 document. |

### UpdateResources

The answer of update.getResources.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `packs` | `packs` | `UpdateResourcePackList` | yes | Packs of this run, sorted by id. |

### UpdateCurrentApp

The running app.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `version` | `version` | `String` | no | Display version. |
| `build` | `build` | `UInt64` | no | Build number. |
| `channel` | `channel` | `String` | yes | Update channel. |
| `distribution` | `distribution` | `String` | no | Distribution channel. |

### UpdateReleaseSummary

The release on offer.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `releaseId` | `releaseId` | `String` | yes | Release id. |
| `version` | `version` | `String` | yes | Display version. |
| `build` | `build` | `UInt64` | yes | Build number. |
| `notes` | `notes` | `StringList` | yes | Release notes, already in the chosen language. |
| `sizeBytes` | `sizeBytes` | `UInt64` | no | Size to download; absent for a store. |
| `mandatory` | `mandatory` | `Boolean` | yes | Forced update. |
| `recommended` | `recommended` | `Boolean` | yes | Recommended update. |
| `kind` | `kind` | `String` | yes | store, package, webBundle or desktop. |

### UpdateProgress

Download progress.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `received` | `received` | `UInt64` | yes | Bytes received. |
| `total` | `total` | `UInt64` | yes | Bytes in all. |

### UpdateErrorInfo

Why the last update action did not go through.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `code` | `code` | `String` | yes | update.* code. |
| `retryable` | `retryable` | `Boolean` | yes | Retrying can help. |
| `fallbackUrl` | `fallbackUrl` | `String` | no | Page to send the user to; absent on the web. |

### UpdateStatus

Update center state: the update://state payload and the answer of every update.* call but install.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `state` | `state` | `String` | yes | idle, checking, upToDate, available, required, downloading, verifying, readyToInstall, installing or failed. |
| `current` | `current` | `UpdateCurrentApp` | yes | The running app. |
| `release` | `release` | `UpdateReleaseSummary` | no | The release on offer. Can be absent in required: the server rejected this build and no manifest arrived yet. |
| `progress` | `progress` | `UpdateProgress` | no | Present while downloading. |
| `prompt` | `prompt` | `String` | yes | none, badge, sheet, modal or fullscreen. The core keeps it through the whole flow; bind to it directly. |
| `blockUi` | `blockUi` | `Boolean` | yes | A forced update blocks the interface. |
| `readOnly` | `readOnly` | `Boolean` | yes | The connection was refused with UPGRADE_REQUIRED or REST answered 426. |
| `lastCheckedAt` | `lastCheckedAt` | `Int64` | no | Last successful check, Unix milliseconds. |
| `error` | `error` | `UpdateErrorInfo` | no | Why the last action did not go through. |
| `blockReason` | `blockReason` | `String` | no | Why this build is blocked, in the chosen language. Present when the current build falls in blockedBuilds and the range gives a reason; a forced prompt shows it ahead of the fixed text. |

### UpdateInstallPlan

What the platform package has to do. kind selects the fields that apply.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `kind` | `kind` | `String` | yes | openStore, installPackage, activateWebBundle or desktopUpdater. |
| `store` | `store` | `String` | no | openStore: play, appstore, testflight, appgallery or a store channel name. |
| `url` | `url` | `String` | no | openStore: the store page. |
| `packageName` | `packageName` | `String` | no | openStore: package name. |
| `appId` | `appId` | `String` | no | openStore: app id in the store. |
| `immediate` | `immediate` | `Boolean` | no | openStore: the Play immediate flow. |
| `path` | `path` | `String` | no | installPackage: the verified file. |
| `sha256` | `sha256` | `String` | no | installPackage and desktopUpdater: lowercase hex. |
| `signingCertSha256` | `signingCertSha256` | `String` | no | installPackage: expected signing certificate. |
| `build` | `build` | `UInt64` | no | installPackage: build number. |
| `sizeBytes` | `sizeBytes` | `UInt64` | no | installPackage: file size. |
| `buildId` | `buildId` | `String` | no | activateWebBundle: target build. |
| `assetManifestUrls` | `assetManifestUrls` | `StringList` | no | activateWebBundle: asset manifest addresses. |
| `assetManifestSha256` | `assetManifestSha256` | `String` | no | activateWebBundle: asset manifest hash. |
| `mandatory` | `mandatory` | `Boolean` | no | activateWebBundle: forced update. |
| `blockUi` | `blockUi` | `Boolean` | no | activateWebBundle: blocks the interface. |
| `version` | `version` | `String` | no | desktopUpdater: target version. |
| `target` | `target` | `String` | no | desktopUpdater: desktop target. |

## Diagnostics

Runtime diagnostics and observability models.

### RuntimeHealthResponse

Runtime health snapshot including metrics and event drop counters.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `metricsEnabled` | `metricsEnabled` | `Boolean` | yes | Whether SDK metrics collection is enabled for this session. |
| `state` | `state` | `String` | yes | Current SDK connection state. |
| `stateCode` | `stateCode` | `Int32` | yes | Numeric SDK state code used by lower-level FFI state calls. |
| `sessionGeneration` | `sessionGeneration` | `UInt64` | yes | Current SDK session generation. |
| `rawSubscriberDroppedTotal` | `rawSubscriberDroppedTotal` | `UInt64` | yes | Total raw subscriber events dropped because bounded queues were full. |
| `metricsJson` | `metricsJson` | `String` | yes | JSON string for the metrics snapshot containing counters, gauges, and histograms. |

## Conversations

Conversation models mirrored from flare-core-sdk-engine/src/model/conversation.rs.

### Enums

- `DisplayNameKind`: Shape of a projected DisplayName. Values: `named`, `members`, `unnamed`

- `NameSource`: Where a named DisplayName came from; for tests and diagnostics, never rendered differently. Values: `alias`, `memberNickname`, `profile`, `snapshot`, `remark`, `name`

- `NameEntity`: What an unnamed DisplayName names; follows ConversationType (single chats and unknown types are a person). Values: `person`, `group`, `system`, `ai`, `customer`, `channel`, `broadcast`, `temp`

### DisplayName

Final name of a person or conversation projected by core-sdk (title-and-name-projection). Tagged by kind: named {text, source}; members {names, total} for an unnamed group titled by up to three named members other than the current user (total counts every member, the current user included); unnamed {entity, idTail} where idTail is the last four characters of the id (empty when there is none). Hosts render it with the kit's flareDisplayNameText; an id is never a name.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `kind` | `kind` | `DisplayNameKind` | yes | named, members or unnamed. |
| `text` | `text` | `String` | no | The name; present when kind is named. |
| `source` | `source` | `NameSource` | no | Where the name came from; present when kind is named. |
| `names` | `names` | `StringList` | no | Up to three member names in server order; present when kind is members. |
| `total` | `total` | `UInt32` | no | Member count including the current user; present when kind is members. |
| `entity` | `entity` | `NameEntity` | no | What is unnamed; present when kind is unnamed. |
| `idTail` | `idTail` | `String` | no | Last four characters of the id, empty without an id; present when kind is unnamed. |

### UpdateConversationDraftRequest

Typed request for updating the current user's synced conversation draft.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Conversation id whose draft is being updated. |
| `draft` | `draft` | `String` | no | Draft text. Omit or set null to clear the draft. |

### ListConversationsResponse

Conversation list response.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversations` | `conversations` | `ConversationList` | yes | Returned conversations. |

### ConversationTotalUnreadResponse

Core-owned unread total for the conversations tab badge.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `totalUnread` | `totalUnread` | `UInt64` | yes | Unread total across all conversations: archived ones count nothing, muted ones count only their mentions. |

## Views

Core observable view models.

### OpenTimelineViewRequest

Request for opening an observable conversation timeline view.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Conversation id to observe. |
| `messageLimit` | `messageLimit` | `UInt32` | yes | Page size: rows in the initial window and in each older or newer page when a paging request does not give its own (core default 40, at most 100). |
| `anchor` | `anchor` | `TimelineAnchor` | no | Open around this message instead of at the latest messages; the window holds half a page on each side of it. |

### TimelineAnchor

The message a timeline view opens around (a search result, a quote, a pinned message).

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `messageId` | `messageId` | `String` | no | Server id or client id of the target. Its local seq is used when the message is stored locally. |
| `seq` | `seq` | `UInt64` | no | Conversation seq of the target, used when the message is not stored locally. With neither the open fails with sdk.view.anchor_not_found. |

### OpenConversationListViewRequest

Request for opening an observable conversation list view.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationLimit` | `conversationLimit` | `UInt32` | yes | Maximum conversations to include in the initial snapshot. |

### LoadOlderTimelineViewRequest

Request for extending an open timeline view with older messages.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewId` | `viewId` | `String` | yes | Timeline view id returned from openTimeline. |
| `messageLimit` | `messageLimit` | `UInt32` | yes | Maximum older messages to load in this page. |

### LoadNewerTimelineViewRequest

Request for extending a timeline view that is not attached to the latest with newer messages.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewId` | `viewId` | `String` | yes | Timeline view id returned from openTimeline. |
| `messageLimit` | `messageLimit` | `UInt32` | yes | Maximum newer messages to load in this page. |

### TimelineViewRequest

Request naming an open timeline view (jumpToLatestTimeline, timelineSnapshot).

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewId` | `viewId` | `String` | yes | Timeline view id returned from openTimeline. |

### CloseViewRequest

Request for closing an observable view.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewId` | `viewId` | `String` | yes | View id returned from an open view call. |

### TimelineViewSnapshot

The window of a timeline view: rows in timeline order and where it stands.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversation` | `conversation` | `Conversation` | no | Conversation header. |
| `messages` | `messages` | `MessageList` | yes | Rows in timeline order (oldest first); pending rows trail when the window is attached to the latest. |
| `hasOlder` | `hasOlder` | `Boolean` | yes | More visible messages exist below the oldest row; answered by the proven seq ranges only. |
| `hasNewer` | `hasNewer` | `Boolean` | yes | More messages exist above the newest row; true exactly when attachedToLatest is false. |
| `attachedToLatest` | `attachedToLatest` | `Boolean` | yes | The newest row is the latest local message and live messages are appended. |
| `anchorKey` | `anchorKey` | `String` | no | Row key of the target when the view was opened around a message. |

### ViewSnapshot

Tagged snapshot emitted by core observable views.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewType` | `viewType` | `String` | yes | Snapshot tag: timeline or conversationList. |
| `data` | `data` | `JsonObject` | yes | Snapshot payload selected by viewType: TimelineViewSnapshot for timeline, HomeTimelineSnapshot for conversationList. |

### ViewOpenResponse

Response returned when opening an observable view and by timelineSnapshot.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewId` | `viewId` | `String` | yes | View id. |
| `revision` | `revision` | `UInt64` | yes | Revision of this snapshot; every later view.updated event for the view carries the next revision. |
| `snapshot` | `snapshot` | `ViewSnapshot` | yes | Snapshot of the view at that revision. |

### ViewDeltaOp

One operation in a conversation-list view delta.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `op` | `op` | `String` | yes | Delta operation: insert, update, remove, or move. |
| `key` | `key` | `String` | yes | Stable item key owned by core. |
| `index` | `index` | `UInt32` | yes | Target index after applying the operation. |
| `fromIndex` | `fromIndex` | `UInt32` | no | Previous index for move operations. |
| `item` | `item` | `JsonObject` | no | Inserted or updated item payload. |

### ViewDelta

Typed delta emitted by core observable views. A timeline delta works by row key (clientMsgId, else serverId, else seq:<conversationId>:<conversationSeq>): remove the keys in remove, replace the rows in upsert in place, put prepend first and append last, reorder by every key when reorder is present, then take the three state fields and conversation. A conversation-list delta is the indexed ops list.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewType` | `viewType` | `String` | yes | Delta tag: timeline or conversationList. |
| `prepend` | `prepend` | `MessageList` | no | Timeline: older rows to put before the first row, in timeline order. |
| `append` | `append` | `MessageList` | no | Timeline: newer rows to put after the last row, in timeline order. |
| `upsert` | `upsert` | `MessageList` | no | Timeline: new content of rows already in the window, replaced in place by row key. |
| `remove` | `remove` | `StringList` | no | Timeline: row keys leaving the window. |
| `reorder` | `reorder` | `StringList` | no | Timeline: every row key in the new order; only when the order changed in a way the other steps cannot express. |
| `hasOlder` | `hasOlder` | `Boolean` | no | Timeline: whether more visible messages exist below the window. |
| `hasNewer` | `hasNewer` | `Boolean` | no | Timeline: whether more messages exist above the window. |
| `attachedToLatest` | `attachedToLatest` | `Boolean` | no | Timeline: whether the window is attached to the latest. |
| `conversation` | `conversation` | `Conversation` | no | Timeline: the conversation header, only when it changed. |
| `ops` | `ops` | `ViewDeltaOpList` | no | Conversation list: ordered indexed operations. |
| `totalUnread` | `totalUnread` | `UInt64` | no | Conversation list: latest total unread value. |
| `syncState` | `syncState` | `String` | no | Conversation list: latest sync state. |

### ViewUpdate

Observable view update event payload (view.updated). Every update a view publishes carries the next revision; a host that sees a revision that is not its applied revision plus 1 drops it when it is not newer, otherwise replaces its window with timelineSnapshot.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewId` | `viewId` | `String` | yes | Updated view id. |
| `revision` | `revision` | `UInt64` | yes | Revision this update brings the view to. |
| `kind` | `kind` | `String` | yes | Update kind: snapshot or delta. |
| `snapshot` | `snapshot` | `ViewSnapshot` | no | Whole view when kind is snapshot. |
| `delta` | `delta` | `ViewDelta` | no | View delta when kind is delta. |

### TimelineViewPageResponse

Response of loadOlderTimeline, loadNewerTimeline and jumpToLatestTimeline. The rows themselves arrive only through view.updated.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `viewId` | `viewId` | `String` | yes | Timeline view id. |
| `loadedCount` | `loadedCount` | `UInt32` | yes | Rows this call added to the window. |
| `revision` | `revision` | `UInt64` | yes | Revision that contains this page (0 when the view was already closed). |

### CloseViewResponse

Response returned when closing an observable view.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `closed` | `closed` | `Boolean` | yes | Whether a view registration was closed. |

## Sync

Explicit sync reconciliation models.

### ConversationHistoryBackfillRequest

Request to backfill one conversation's historical messages into the local store.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Stable conversation id. |
| `limit` | `limit` | `Int32` | no | Maximum messages per backfill page. |
| `maxPages` | `maxPages` | `UInt32` | no | Maximum historical pages to request for this call. |

### ConversationHistoryBackfillResponse

Result of direct local-store historical backfill for one conversation.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Stable conversation id. |
| `pagesLoaded` | `pagesLoaded` | `UInt32` | yes | Number of older pages that advanced the local oldest seq. |
| `oldestSeqBefore` | `oldestSeqBefore` | `UInt64` | yes | Oldest local conversation seq before backfill. |
| `oldestSeqAfter` | `oldestSeqAfter` | `UInt64` | yes | Oldest local conversation seq after backfill. |
| `hasMore` | `hasMore` | `Boolean` | yes | Whether the server reported more history remains. |
| `completed` | `completed` | `Boolean` | yes | True when this call reached the earliest visible history or the server reported no more pages. |

## Messages

Message models mirrored from flare-core-sdk-engine/src/model/message.rs and message_elem.rs.

### Enums

- `MessageContentType`: Decoded message content discriminator. Values: `text`, `image`, `video`, `audio`, `file`, `location`, `card`, `sticker`, `emoji`, `quote`, `link_card`, `forward`, `thread`, `mini_program`, `rich_text`, `image_group`, `system`, `notification`, `vote`, `task`, `schedule`, `announcement`, `custom`, `placeholder`

- `MessageReceiptStatus`: Receipt state the core SDK projects for a message: pending (built locally, not yet sending), sending (no server sequence yet, media uploading included), sent (the server has it), read (single chat: the peer read it; group: the read summary says all members read it), failed (retryable). There is no delivered state. Values: `pending`, `sending`, `sent`, `read`, `failed`

### MessageContent

Decoded content envelope. Type-specific payload lives in `data` until per-content models are generated.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `contentType` | `contentType` | `MessageContentType` | yes | Content discriminator. |
| `data` | `data` | `JsonObject` | yes | Content payload object. |

### MessageReadSummary

Who read one of the viewer's own messages in a group, the sender excluded: total = readCount + unreadCount, always above 0.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `readCount` | `readCount` | `UInt32` | yes | Members who read the message. |
| `unreadCount` | `unreadCount` | `UInt32` | yes | Members who have not read it yet. |
| `total` | `total` | `UInt32` | yes | Members the message counts, the sender excluded. |

### MessageReceiptView

The receipt projection of a message, computed by the core SDK; kits draw it as is (no host mapping from status, isRead or localState). Incoming messages carry one too, kits show no receipt for them.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `status` | `status` | `MessageReceiptStatus` | yes | Receipt state. |
| `readSummary` | `readSummary` | `MessageReadSummary` | no | Only on the viewer's own messages in groups, once the core SDK has read it from Core for a message a view shows (and refreshed on read receipts); absent in single chats, in groups above the large-group threshold, and before it is known. Never a made-up number. |

### CreateTextMessageRequest

Create a text message draft for a conversation.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `text` | `text` | `String` | yes | Text body. |

### SendMessageRequest

Send a fully built message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `message` | `message` | `Message` | yes | Message to send. |
| `expectedUserId` | `expectedUserId` | `String` | no | Optional active-user precondition; cannot override the authenticated sender. |

### SendMessageResponse

Send acknowledgement returned by core-sdk.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `ackId` | `ackId` | `String` | yes | ACK id assigned by the transport layer, if present. |
| `serverId` | `serverId` | `String` | yes | Server-assigned message id. |
| `clientMsgId` | `clientMsgId` | `String` | yes | Client message id acknowledged by the server. |
| `conversationId` | `conversationId` | `String` | yes | Conversation id. |
| `seq` | `seq` | `UInt64` | yes | Assigned conversation sequence. |
| `timestamp` | `timestamp` | `UInt64` | yes | Server send time in milliseconds. |
| `success` | `success` | `Boolean` | yes | Whether this response contains a final accepted send ACK. |
| `errorCode` | `errorCode` | `Int32` | yes | Core ACK error code when success is false. |
| `errorMessage` | `errorMessage` | `String` | yes | Core ACK error message when success is false. |

### ListMessagesRequest

Page messages before a sequence in a conversation.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Conversation id. |
| `beforeSeq` | `beforeSeq` | `UInt64` | yes | Fetch messages before this sequence; 0 means latest page. |
| `limit` | `limit` | `UInt32` | yes | Page size. |

### ListMessagesResponse

Message page response.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `messages` | `messages` | `MessageList` | yes | Returned messages. |

### MessageReadReceiptMembersRequest

One page of the members who read, or have not yet read, one of the viewer's own group messages (the read receipt sheet).

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `payload` | `payload` | `JsonObject` | yes | {conversationId, serverMsgId, state: "read" \| "unread", cursor?, limit?}; limit 1..=200 (default 50), cursor the previous page's nextCursor (absent for the first page). |

## MessageContentElems

Typed message content payloads mirrored from flare_proto message_content.proto. Use these instead of ad-hoc JsonObject in adapters.

### MediaSourceInfo

Image/video/audio/file source descriptor (uuid, url, dimensions).

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `uuid` | `uuid` | `String` | no | Stable media uuid. |
| `imageId` | `imageId` | `String` | no | Image id when applicable. |
| `url` | `url` | `String` | no | Resolved URL. |
| `mimeType` | `mimeType` | `String` | no | MIME type. |
| `size` | `size` | `UInt64` | no | Byte size. |
| `width` | `width` | `Int32` | no | Width in pixels. |
| `height` | `height` | `Int32` | no | Height in pixels. |
| `blurhash` | `blurhash` | `String` | no | Blurhash placeholder for image previews. |
| `durationMs` | `durationMs` | `Int32` | no | Duration for audio/video. |

### TextContentPayload

Text message body.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `text` | `text` | `String` | yes | Plain text body. |

### ImageContentPayload

Image message payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `imageId` | `imageId` | `String` | no | Uploaded image id. |
| `source` | `source` | `MediaSourceInfo` | no | Source descriptor. |
| `thumbnail` | `thumbnail` | `MediaSourceInfo` | no | Thumbnail descriptor. |
| `description` | `description` | `String` | no | Caption. |

### ImageGroupItem

One image inside an image group.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `imageId` | `imageId` | `String` | yes | Image id. |
| `url` | `url` | `String` | no | Resolved URL. |
| `title` | `title` | `String` | no | Item title. |
| `width` | `width` | `Int32` | no | Width. |
| `height` | `height` | `Int32` | no | Height. |

### ImageGroupContentPayload

Image group payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `images` | `images` | `ImageGroupItemList` | yes | Grouped images. |
| `title` | `title` | `String` | no | Group title. |

### VideoContentPayload

Video message payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `videoId` | `videoId` | `String` | no | Uploaded video id. |
| `source` | `source` | `MediaSourceInfo` | no | Video source. |
| `cover` | `cover` | `MediaSourceInfo` | no | Cover image. |
| `description` | `description` | `String` | no | Caption. |

### AudioContentPayload

Audio message payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `audioId` | `audioId` | `String` | no | Uploaded audio id. |
| `source` | `source` | `MediaSourceInfo` | no | Audio source. |
| `durationMs` | `durationMs` | `Int32` | no | Duration. |

### FileContentPayload

File message payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `fileId` | `fileId` | `String` | no | Uploaded file id. |
| `name` | `name` | `String` | no | Display name. |
| `url` | `url` | `String` | no | Download URL. |
| `mimeType` | `mimeType` | `String` | no | MIME type. |
| `size` | `size` | `UInt64` | no | Byte size. |

### EmojiContentPayload

Emoji message payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `emoji` | `emoji` | `String` | yes | Emoji key or unicode. |

### StickerContentPayload

Sticker message payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `stickerId` | `stickerId` | `String` | yes | Sticker id. |
| `packageId` | `packageId` | `String` | no | Sticker package id. |
| `url` | `url` | `String` | no | Sticker URL. |
| `width` | `width` | `Int32` | no | Width. |
| `height` | `height` | `Int32` | no | Height. |
| `format` | `format` | `String` | no | webp/gif/png. |

### ForwardSourceMessage

One source message inside a forward bundle.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `sourceMessageId` | `sourceMessageId` | `String` | yes | Original message id. |
| `sourceConversationId` | `sourceConversationId` | `String` | no | Original conversation id. |
| `sourceSenderId` | `sourceSenderId` | `String` | no | Original sender id. |
| `plainText` | `plainText` | `String` | no | Preview text. |

### ForwardContentPayload

Forward message payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `merge` | `merge` | `Boolean` | no | Merge forwarded messages into one card. |
| `title` | `title` | `String` | no | Forward title. |
| `sourceMessages` | `sourceMessages` | `ForwardSourceMessageList` | yes | Forwarded sources. |

## MessageBuilder

Typed requests for messageBuilder quick-build APIs and catalog metadata.

### Enums

- `MessageBuildOp`: Dispatch op passed to flare_message_build_json. Values: `create_text`, `create_quote`, `create_thread_reply`, `create_forward`, `create_image`, `create_image_group`, `create_video`, `create_audio`, `create_file`, `create_emoji`, `create_location`, `create_sticker`, `create_link_card`, `create_card`, `create_mini_program`, `create_rich_doc`, `create_system`, `create_notification`, `create_vote`, `create_task`, `create_schedule`, `create_announcement`, `create_custom`, `create_placeholder`, `create_with_content`

### MessageBuildCatalogEntry

One supported quick-build operation exposed on MessageBuilderApi.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `op` | `op` | `MessageBuildOp` | yes | Build dispatch op. |
| `method` | `method` | `String` | yes | Facade method name, e.g. buildText. |
| `requestType` | `requestType` | `String` | yes | Typed request model name. |
| `contentType` | `contentType` | `MessageContentType` | yes | Decoded content discriminator. |
| `messageType` | `messageType` | `Int32` | yes | Core message type integer. |
| `summary` | `summary` | `String` | yes | Human-readable summary for UI/docs. |
| `stability` | `stability` | `String` | yes | stable \| beta \| experimental |

### ListMessageBuildCatalogResponse

Catalog of all supported message build operations.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `entries` | `entries` | `MessageBuildCatalogEntryList` | yes | Supported build operations. |

### BuildTypedMessageRequest

Generic typed build request used by composer helpers.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `op` | `op` | `MessageBuildOp` | yes | Build operation. |
| `data` | `data` | `JsonObject` | no | Operation-specific payload; prefer typed buildXxx requests. |

### BuildTextMessageRequest

Build a text message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `text` | `text` | `String` | yes | Text body. |
| `mentionUsers` | `mentionUsers` | `StringList` | no | User ids mentioned in the text body. The core builder resolves @userId spans into typed mentions. |
| `mentionAll` | `mentionAll` | `Boolean` | no | Whether the message mentions every member in the target conversation. |

### BuildQuoteMessageRequest

Build a quote/reply message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `quotedMessageId` | `quotedMessageId` | `String` | yes | Quoted message id. |
| `text` | `text` | `String` | yes | Reply text. |
| `quotedSenderId` | `quotedSenderId` | `String` | no | Quoted sender id. |
| `quotedTextPreview` | `quotedTextPreview` | `String` | no | Quoted preview text. |
| `quotedContent` | `quotedContent` | `MessageContent` | yes | Quoted message content element. |

### BuildThreadReplyMessageRequest

Build a thread reply message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `threadId` | `threadId` | `String` | yes | Thread root message id. |
| `text` | `text` | `String` | yes | Reply text. |

### BuildForwardMessageRequest

Build a forward message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `merge` | `merge` | `Boolean` | no | Merge into one card. |
| `title` | `title` | `String` | yes | Forward title. |
| `sourceMessages` | `sourceMessages` | `MessageList` | yes | Messages to forward. Full messages, not id stubs: the forward payload embeds the original content, so the core needs content/senderId/conversationId of each source. |

### BuildImageMessageRequest

Build an image message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `imageId` | `imageId` | `String` | yes | Uploaded image id. |
| `payload` | `payload` | `ImageContentPayload` | no | Optional rich image payload for UI preview. |

### BuildImageGroupMessageRequest

Build an image group message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `payload` | `payload` | `ImageGroupContentPayload` | yes | Image group payload. |

### BuildVideoMessageRequest

Build a video message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `videoId` | `videoId` | `String` | yes | Uploaded video id. |
| `payload` | `payload` | `VideoContentPayload` | no | Optional video payload. |

### BuildAudioMessageRequest

Build an audio message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `audioId` | `audioId` | `String` | yes | Uploaded audio id. |
| `payload` | `payload` | `AudioContentPayload` | no | Optional audio payload. |

### BuildFileMessageRequest

Build a file message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `fileId` | `fileId` | `String` | yes | Uploaded file id. |
| `payload` | `payload` | `FileContentPayload` | no | Optional file payload. |

### BuildEmojiMessageRequest

Build an emoji message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `emoji` | `emoji` | `String` | yes | Emoji key. |

### BuildLocationMessageRequest

Build a location message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `latitude` | `latitude` | `Double` | yes | Latitude. |
| `longitude` | `longitude` | `Double` | yes | Longitude. |
| `title` | `title` | `String` | no | Place title. |
| `address` | `address` | `String` | no | Address. |

### BuildStickerMessageRequest

Build a sticker message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `stickerId` | `stickerId` | `String` | yes | Sticker id. |
| `packageId` | `packageId` | `String` | no | Sticker package id. |
| `payload` | `payload` | `StickerContentPayload` | no | Optional sticker payload. |

### BuildLinkCardMessageRequest

Build a link card message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `url` | `url` | `String` | yes | Link URL. |
| `title` | `title` | `String` | no | Card title. |
| `description` | `description` | `String` | no | Card description. |
| `thumbnailUrl` | `thumbnailUrl` | `String` | no | Thumbnail URL. |
| `siteName` | `siteName` | `String` | no | Site name. |

### BuildCardMessageRequest

Build a structured card message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `id` | `id` | `String` | yes | Card target id. |
| `cardType` | `cardType` | `String` | no | Card type key. |
| `title` | `title` | `String` | no | Display title. |
| `subtitle` | `subtitle` | `String` | no | Display subtitle. |
| `avatar` | `avatar` | `String` | no | Avatar URL or media id. |
| `attributes` | `attributes` | `StringMap` | no | Card attributes, the card elem's extra (CardContent.attributes), such as cardType and a shared person's referrerId. Blank keys are dropped. |

### BuildMiniProgramMessageRequest

Build a mini program message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `appId` | `appId` | `String` | yes | Mini program app id. |
| `pagePath` | `pagePath` | `String` | no | Entry path. |
| `title` | `title` | `String` | no | Display title. |
| `thumbnailUrl` | `thumbnailUrl` | `String` | no | Thumbnail URL. |
| `extra` | `extra` | `StringMap` | no | Mini program extension fields. |

### BuildRichDocMessageRequest

Build a rich document message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `docJson` | `docJson` | `String` | yes | RichDoc JSON document. |
| `contentSchema` | `contentSchema` | `String` | yes | Content schema, normally rich_doc. |
| `plainText` | `plainText` | `String` | yes | Human-readable plain text. |
| `inputFormat` | `inputFormat` | `String` | no | Original source format when known. |
| `inputFormatVersion` | `inputFormatVersion` | `Int32` | no | Original source format version. |
| `sourcePayload` | `sourcePayload` | `StringMap` | no | Original source payload snapshot keyed by format. |
| `title` | `title` | `String` | no | Rich document title. |
| `searchText` | `searchText` | `String` | no | Search-indexable text. |
| `renderHintsJson` | `renderHintsJson` | `String` | no | Renderer hints JSON. |

### NormalizeRichDocFromMarkdownRequest

Normalize Markdown into RichDoc v2 JSON and derived fields.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `markdown` | `markdown` | `String` | yes | Markdown source. |

### NormalizeRichDocFromHtmlRequest

Normalize an HTML fragment into RichDoc v2 JSON and derived fields.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `html` | `html` | `String` | yes | HTML fragment source. |

### NormalizeRichDocFromDocJsonRequest

Validate editor-produced RichDoc v2 JSON and derive searchable/render fields.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `docJson` | `docJson` | `String` | yes | RichDoc v2 document JSON. |

### RichDocV2Normalized

Normalized RichDoc v2 payload aligned with core NormalizeOutput.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `docJson` | `docJson` | `String` | yes | Canonical RichDoc v2 JSON document. |
| `contentSchema` | `contentSchema` | `String` | yes | Content schema, normally rich_doc. |
| `version` | `version` | `UInt32` | yes | RichDoc schema version. |
| `plainText` | `plainText` | `String` | yes | Human-readable plain text extracted from the document. |
| `searchText` | `searchText` | `String` | yes | Search-indexable text extracted from the document. |
| `renderHints` | `renderHints` | `JsonObject` | yes | Renderer hint object derived by core. |
| `inputFormat` | `inputFormat` | `String` | no | Original source format when known. |
| `sourcePayload` | `sourcePayload` | `JsonObject` | no | Original source payload snapshot keyed by format. |

### BuildSystemMessageRequest

Build a system message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `eventKind` | `eventKind` | `String` | yes | System event kind. |
| `body` | `body` | `String` | yes | System event body. |

### BuildNotificationMessageRequest

Build a notification message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `title` | `title` | `String` | yes | Notification title. |
| `body` | `body` | `String` | yes | Notification body. |

### BuildVoteMessageRequest

Build a vote message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `voteId` | `voteId` | `String` | yes | Vote id. |
| `title` | `title` | `String` | yes | Vote title. |
| `options` | `options` | `StringList` | yes | Vote options. |
| `participantUserIds` | `participantUserIds` | `StringList` | yes | Participants allowed to vote. |

### BuildTaskMessageRequest

Build a task message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `taskId` | `taskId` | `String` | yes | Task id. |
| `title` | `title` | `String` | yes | Task title. |
| `status` | `status` | `String` | no | Task status. |
| `participantUserIds` | `participantUserIds` | `StringList` | yes | Task participants. |

### BuildScheduleMessageRequest

Build a schedule message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `scheduleId` | `scheduleId` | `String` | yes | Schedule id. |
| `title` | `title` | `String` | yes | Schedule title. |
| `startTimeMs` | `startTimeMs` | `Int64` | yes | Start time in milliseconds since epoch. |
| `endTimeMs` | `endTimeMs` | `Int64` | yes | End time in milliseconds since epoch. |
| `participantUserIds` | `participantUserIds` | `StringList` | yes | Schedule participants. |

### BuildAnnouncementMessageRequest

Build an announcement message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `title` | `title` | `String` | yes | Announcement title. |
| `body` | `body` | `String` | yes | Announcement body. |

### BuildCustomMessageRequest

Build a custom extension message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `type` | `type` | `String` | yes | Extension type key. |

### BuildPlaceholderMessageRequest

Build a placeholder message.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `reason` | `reason` | `String` | yes | Placeholder reason. |

### BuildWithContentMessageRequest

Build from an existing MessageContent envelope.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Target conversation id. |
| `content` | `content` | `MessageContent` | yes | Decoded content envelope. |

## Events

Typed SDK event and notification models for cross-platform subscriptions.

### Enums

- `SdkEventKind`: Top-level event domain. Values: `lifecycle`, `connection`, `access`, `update`, `message`, `notification`, `conversation`, `sync`, `extension`, `extension_event`, `presence`, `media`, `plugin`, `view`

- `LifecycleEventName`: Client SDK lifecycle notification name. Values: `initializing`, `initialized`, `init_failed`, `login_succeeded`, `login_failed`, `logged_out`, `disposed`

- `ConnectionEventName`: Connection event name: the one status event, and the coarse sync state hint. Values: `status`, `sync_state_changed`

- `AccessEventName`: Access event name. Values: `switched`, `changed`

- `UpdateEventName`: Update event name. Values: `state`

- `MessageEventName`: Message event notification name. Values: `received`, `received_batch`, `send_ack`, `send_failed`, `recalled`, `typing`, `typing_aggregate`, `edited`, `reaction_changed`, `deleted`, `read_receipt`, `burn_scheduled`, `burned`, `hard_deleted`, `pinned`, `unpinned`, `marked`, `unmarked`, `retention_scheduled`, `retention_expired`, `retention_purged`, `presence_changed`, `custom`, `plugin_state_changed`, `read_summaries_changed`

- `ConversationEventName`: Conversation event notification name. Values: `synced`, `created`, `updated`, `unread_count_changed`, `deleted`

- `SyncEventName`: Sync orchestration event notification name. Values: `state_changed`, `started`, `finished`, `failed`, `progress`, `task_completed`, `resync_needed`, `readiness`

- `ProgressEventName`: Progress notification name. Values: `sync_progress`, `upload_progress`, `download_progress`

- `PluginEventName`: Plugin event notification name. Values: `realtime`, `catalog_changed`

### SdkErrorPayload

Stable error payload used by lifecycle and async notification failures.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `code` | `code` | `String` | yes | Stable machine-readable error code. |
| `machineReason` | `machineReason` | `String` | no | Server's typed reason (ErrorDetail.reason, e.g. a PreSend rejection code); empty or absent for local failures. |
| `message` | `message` | `String` | yes | Human-readable error message. |
| `operation` | `operation` | `String` | no | Operation that failed. |
| `retryable` | `retryable` | `Boolean` | no | Whether retrying may succeed. |
| `details` | `details` | `StringMap` | yes | Opaque diagnostic details. |

### SdkEventEnvelope

Common event envelope emitted by every platform SDK event stream.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `eventId` | `eventId` | `String` | yes | Unique event id generated by the SDK adapter. |
| `kind` | `kind` | `SdkEventKind` | yes | Top-level event domain. |
| `name` | `name` | `String` | yes | Domain-specific event name. |
| `occurredAt` | `occurredAt` | `UInt64` | yes | Event time in milliseconds. |
| `traceId` | `traceId` | `String` | no | Trace id for diagnostics when available. |
| `payload` | `payload` | `JsonObject` | yes | Raw event payload for forward-compatible consumers. |

### LifecycleEvent

Lifecycle notification. Method return values remain the primary success/failure contract.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `name` | `name` | `LifecycleEventName` | yes | Lifecycle event name. |
| `operation` | `operation` | `String` | yes | Operation associated with this lifecycle event. |
| `userId` | `userId` | `String` | no | Current user id when known. |
| `sessionId` | `sessionId` | `String` | no | SDK session id when available. |
| `error` | `error` | `SdkErrorPayload` | no | Failure details for *_failed events. |

### ConnectionSyncStateEvent

Payload of the coarse sync state hint (connection.sync_state_changed). Connection status itself arrives as ConnectionStatus.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `state` | `state` | `String` | yes | The core sync state name. |

### MessageReceivedEvent

Single message received notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `message` | `message` | `Message` | yes | Received message. |

### MessageReceivedBatchEvent

Batch message received notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `messages` | `messages` | `MessageList` | yes | Received messages. |

### MessageSendAckEvent

Message send acknowledgement notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `ack` | `ack` | `SendMessageResponse` | yes | Send acknowledgement. |

### MessageSendFailedEvent

Message send failure notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `clientMsgId` | `clientMsgId` | `String` | yes | Client message id that failed. |
| `reason` | `reason` | `String` | yes | Failure reason text for people; use error.code and error.machineReason to act on it. |
| `error` | `error` | `SdkErrorPayload` | no | Structured failure: code, machineReason (ErrorDetail.reason when the server rejected), message, operation, retryable, details. |

### MessageMutationEvent

Message mutation notification for recall, edit, delete, pin, mark, burn and plugin card state events.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `name` | `name` | `MessageEventName` | yes | Mutation event name. |
| `conversationId` | `conversationId` | `String` | yes | Conversation id. |
| `messageId` | `messageId` | `String` | no | Client or server message id. |
| `serverMsgId` | `serverMsgId` | `String` | no | Server message id. |
| `userId` | `userId` | `String` | no | User associated with the mutation. |
| `reason` | `reason` | `String` | no | Mutation reason when available. |

### TypingEvent

Typing/input-state notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Conversation id. |
| `userId` | `userId` | `String` | yes | Typing user id. |
| `typing` | `typing` | `Boolean` | yes | Whether user is typing. |

### TypingAggregateEvent

Aggregated typing/input-state notification for large conversations.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Conversation id. |
| `typingUserIds` | `typingUserIds` | `StringList` | yes | Users currently typing in the aggregation window. |
| `typingCount` | `typingCount` | `UInt32` | yes | Number of users currently typing in the aggregation window. |

### ReadReceiptEvent

Read receipt notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Conversation id. |
| `userId` | `userId` | `String` | yes | Reader user id. |
| `readSeq` | `readSeq` | `UInt64` | yes | Read sequence. |

### ReactionChangedEvent

Message reaction changed notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | yes | Conversation id. |
| `serverMsgId` | `serverMsgId` | `String` | yes | Server message id. |
| `userId` | `userId` | `String` | yes | User who changed the reaction. |
| `emoji` | `emoji` | `String` | yes | Reaction emoji. |
| `action` | `action` | `Int32` | yes | Reaction action integer from core. |

### ConversationEvent

Conversation notification payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `name` | `name` | `ConversationEventName` | yes | Conversation event name. |
| `conversationId` | `conversationId` | `String` | no | Affected conversation id. |
| `conversationIds` | `conversationIds` | `StringList` | yes | Affected conversation ids for sync events. |
| `unreadCount` | `unreadCount` | `UInt32` | no | Unread count for unread-count changes. |

### PresenceChangedEvent

Presence notification payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `conversationId` | `conversationId` | `String` | no | Conversation id when presence is scoped to a conversation. |
| `userId` | `userId` | `String` | yes | User id. |
| `status` | `status` | `String` | yes | Presence status. |
| `extra` | `extra` | `StringMap` | yes | Opaque presence details. |

### ProgressEvent

Generic sync, upload or download progress notification.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `name` | `name` | `ProgressEventName` | yes | Progress event name. |
| `operation` | `operation` | `String` | yes | Operation being tracked. |
| `current` | `current` | `UInt64` | yes | Current progress units. |
| `total` | `total` | `UInt64` | yes | Total progress units. |
| `taskId` | `taskId` | `String` | no | Task identifier when available. |
| `detail` | `detail` | `String` | no | Human-readable progress detail. |

### SyncEvent

Sync orchestration notification payload.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `name` | `name` | `SyncEventName` | yes | Sync event name. |
| `runId` | `runId` | `String` | no | Stable sync run id used to correlate readiness, progress, and completion. |
| `trigger` | `trigger` | `String` | no | Sync trigger. |
| `scope` | `scope` | `String` | no | Sync scope. |
| `visibility` | `visibility` | `String` | no | Sync visibility policy. |
| `reason` | `reason` | `String` | no | Sync reason for diagnostics and startup wait reports. |
| `phase` | `phase` | `String` | no | Sync phase. |
| `task` | `task` | `String` | no | Sync task name. |
| `stage` | `stage` | `String` | no | Readiness stage for sync.readiness events. |
| `progress` | `progress` | `UInt32` | no | Progress percentage from 0 to 100. |
| `error` | `error` | `SdkErrorPayload` | no | Failure details for failed sync events. |

### PluginRealtimeEvent

A plugin realtime packet (im.realtime.deliver). Online only, at most once, never stored; the SDK drops expired packets and payloads that are not JSON objects.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `pluginId` | `pluginId` | `String` | yes | Delivering plugin id, e.g. flare.call. |
| `packetType` | `packetType` | `String` | yes | Plugin packet type, e.g. call.snapshot. |
| `conversationId` | `conversationId` | `String` | yes | Conversation the plugin delivered to. |
| `payload` | `payload` | `JsonObject` | yes | Plugin-defined JSON object payload. |
| `deliveryId` | `deliveryId` | `String` | yes | Core delivery id of this packet. |
| `expiresAtMs` | `expiresAtMs` | `UInt64` | yes | Wall-clock milliseconds after which the packet is stale. |

### PluginCatalogChangedEvent

The tenant's plugin catalog changed; the SDK has already invalidated its plugin catalog.

| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `version` | `version` | `String` | yes | Plugin authorization projection version Core announced. |

## PluginUi

Data-only plugin UI evaluation, authoritative types and bounds live in flare-plugin-protocol/ui.rs.

### PluginUiEvaluationRequest



| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `payload` | `payload` | `JsonObject` | yes | Typed UI evaluation envelope defined by the shared UI protocol. presentPluginMessage, invokePluginAction and pluginDetail accept an optional messageId (server id or clientMsgId) of the message the card belongs to: the card resolves over the shared and local state layers stored on that message, and invoke stores a successful operation's data.sharedState and data.messageState on it. invokePluginAction also takes formValues and selection; pluginDetail also takes cursor and previous for the next page of a paged detail, and refresh with previous to re-read a shown sheet keeping the pages it had loaded. pluginPage takes {pluginId, page, platform, locale?, arguments?, filters?, cursor?, previous?, refresh?}; invokePluginAction takes page {pluginId, page}, data and row {key, input} instead of message for a page action. |

## PluginCommand

Durable idempotent plugin intent; Rust PluginCommand and strict request parsers own semantics.

### PluginCommandRequest



| Field | Wire name | Type | Required | Description |
|-------|-----------|------|----------|-------------|
| `payload` | `payload` | `JsonObject` | yes | prepare: slot + command; pending: slot; submit/acknowledge: slot + commandId. Scope is inferred from the active SDK session. |
