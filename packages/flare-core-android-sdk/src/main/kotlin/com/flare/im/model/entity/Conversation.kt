package com.flare.im.model.entity

import com.flare.im.model.common.enums.ConversationType

/** GENERATED. Do not edit by hand. */
/** SDK 层会话类型：内部统一使用，从 proto ConversationSummary 获取后即转换为此类型。 与 message.rs 的 IMMessage 一致：扁平字段、serde camelCase。 */
data class Conversation(
    /** wire: `avatarUrl`.  */
    val avatarUrl: String = "",
    /** wire: `badge`.  */
    val badge: String? = null,
    /** wire: `businessType`.  */
    val businessType: String = "",
    /** wire: `channelId`. 会话路由 ID：单聊为对方 user_id；群/频道为业务 channel（与 proto `channel_id` 一致） */
    val channelId: String = "",
    /** wire: `conversationId`.  */
    val conversationId: String = "",
    /** wire: `conversationType`.  */
    val conversationType: ConversationType,
    /** wire: `createdAt`.  */
    val createdAt: Long = 0L,
    /** wire: `description`.  */
    val description: String? = null,
    /** wire: `displayName`. 业务名（服务端或业务 SDK 给的会话名），可为空，永不为 id；列表标题读 `title`。 */
    val displayName: String = "",
    /** wire: `draft`.  */
    val draft: String? = null,
    /** wire: `ext`. 扩展键值（与 proto ext 对应） */
    val ext: Map<String, String> = emptyMap(),
    /** wire: `isArchived`.  */
    val isArchived: Boolean = false,
    /** wire: `isMuted`.  */
    val isMuted: Boolean = false,
    /** wire: `isPinned`.  */
    val isPinned: Boolean = false,
    /** wire: `lastMessage`.  */
    val lastMessage: MessagePreview? = null,
    /** wire: `lastMessageAt`.  */
    val lastMessageAt: Long? = null,
    /** wire: `lastMessageId`.  */
    val lastMessageId: String? = null,
    /** wire: `lastMessagePreview`.  */
    val lastMessagePreview: String? = null,
    /** wire: `lastReadSeq`. 已读序列号（与 read_seq 同义） */
    val lastReadSeq: Long = 0L,
    /** wire: `lastSender`. 最后一条消息的发送者名（人名解析链，群会话含会话内昵称）；没有最后一条消息时缺省。 读取时由核心投影，不落库。 */
    val lastSender: DisplayName? = null,
    /** wire: `lastSenderAvatarUrl`. 最后一条消息发送者头像 URL */
    val lastSenderAvatarUrl: String = "",
    /** wire: `lastSenderId`.  */
    val lastSenderId: String? = null,
    /** wire: `lastSenderNickname`. 旧字段：最后一条消息发送者在身份缓存里的资料名（是真名字时），否则为本地已存的名字或空串， 永不为 id。列表读 `last_sender`。 */
    val lastSenderNickname: String = "",
    /** wire: `maxSeq`.  */
    val maxSeq: Long = 0L,
    /** wire: `memberPreview`. 摘要级成员预览，最多少量成员，不能作为完整成员列表使用。 */
    val memberPreview: List<ConversationParticipant> = emptyList(),
    /** wire: `membersCount`.  */
    val membersCount: Int = 0,
    /** wire: `mentionCount`.  */
    val mentionCount: Int = 0,
    /** wire: `mentionMe`.  */
    val mentionMe: Boolean = false,
    /** wire: `participantVersion`. 服务端成员读模型版本。完整成员通过独立 participants 同步拉取。 */
    val participantVersion: Long = 0L,
    /** wire: `participants`. 已按需同步到本地的完整成员快照；会话摘要同步不会填充该字段。 */
    val participants: List<ConversationParticipant> = emptyList(),
    /** wire: `peerReadSeq`. 对端（其他成员）最大已读序列号；用于发送方已读双勾在重连/重登后恢复。 由服务端同步摘要 `ext.peer_read_seq` 下发并持久化。 */
    val peerReadSeq: Long = 0L,
    /** wire: `remark`.  */
    val remark: String? = null,
    /** wire: `role`.  */
    val role: String? = null,
    /** wire: `title`. 列表与聊天头显示的会话标题：备注、单聊对端人名、业务名、无名群的成员名拼接， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的会话都带它。 */
    val title: DisplayName,
    /** wire: `unreadCount`.  */
    val unreadCount: Int = 0,
    /** wire: `updatedAt`.  */
    val updatedAt: Long = 0L,
    /** wire: `updatedAtTs`. 更新时间戳（毫秒，用于排序/筛选） */
    val updatedAtTs: Long? = null,
    /** wire: `version`.  */
    val version: Long = 0L,
    /** wire: `visibleAfterSeq`. 当前用户的历史可见边界；seq <= visible_after_seq 的消息不可见，不参与冷启动回灌。 */
    val visibleAfterSeq: Long = 0L,
)
