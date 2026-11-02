package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** SDK 层消息类型：与 message.proto 的 Message 属性一致，content 为解码后的 Elem； 另保留 raw_content 与 proto 一致用于持久化/网络，并增加发送者展示字段。 */
data class Message(
    /** wire: `attributes`.  */
    val attributes: Map<String, String> = emptyMap(),
    /** wire: `channelId`. 会话频道 ID：单聊=对方 user_id，群聊=群 ID，频道/话题=对应 ID */
    val channelId: String = "",
    /** wire: `clientCreatedAt`. 客户端本地创建时间，Unix epoch millis。 */
    val clientCreatedAt: Long = 0L,
    /** wire: `clientMsgId`. 客户端生成ID（去重） */
    val clientMsgId: String = "",
    /** wire: `content`. proto结构 */
    val content: MessageContent? = null,
    /** wire: `conversationId`. 会话ID */
    val conversationId: String = "",
    /** wire: `conversationSeq`. 会话内持久化 replay 序列号。 */
    val conversationSeq: Long = 0L,
    /** wire: `conversationType`. 会话类型 */
    val conversationType: Int = 0,
    /** wire: `createdAt`. 消息创建时间，Unix epoch millis。 */
    val createdAt: Long = 0L,
    /** wire: `extensions`. 扩展数据；未提供时为空。 */
    val extensions: Map<String, ByteArray> = emptyMap(),
    /** wire: `isEdited`.  */
    val isEdited: Boolean = false,
    /** wire: `isRead`.  */
    val isRead: Boolean = false,
    /** wire: `isRecalled`.  */
    val isRecalled: Boolean = false,
    /** wire: `localState`.  */
    val localState: MessageLocalState? = null,
    /** wire: `mentionAll`.  */
    val mentionAll: Boolean = false,
    /** wire: `mentionUsers`.  */
    val mentionUsers: List<String> = emptyList(),
    /** wire: `messageType`. 消息类型 */
    val messageType: Int = 0,
    /** wire: `quotePreview`.  */
    val quotePreview: String? = null,
    /** wire: `reactions`. 表情反应快照（由 ReactionEvent 驱动更新并持久化） */
    val reactions: List<ReactionEntry> = emptyList(),
    /** wire: `replyTo`.  */
    val replyTo: String? = null,
    /** wire: `sender`. 发送者名：别名、群会话里的会话内昵称、资料名、发送时快照（`sender_name`），都没有时为 结构化的「无名」。读取时由核心投影，不落库；SDK 交出的消息都带它。 */
    val sender: DisplayName,
    /** wire: `senderAvatar`.  */
    val senderAvatar: String = "",
    /** wire: `senderDisplayName`. 旧字段：身份缓存里发送者的资料名（是真名字时），否则为空，永不为 id。读发送者名用 `sender`。 */
    val senderDisplayName: String = "",
    /** wire: `senderId`. 发送者 */
    val senderId: String = "",
    /** wire: `senderName`.  */
    val senderName: String = "",
    /** wire: `serverId`. 服务端唯一ID */
    val serverId: String = "",
    /** wire: `source`. 消息来源 */
    val source: Int = 0,
    /** wire: `status`.  */
    val status: Int = 0,
    /** wire: `textPreview`. 列表、搜索、绑定层使用的纯文本预览。 */
    val textPreview: String = "",
    /** wire: `threadId`. 话题/线程根消息 ID；普通消息为空，话题回复使用该 typed field。 */
    val threadId: String? = null,
    /** wire: `updatedAt`.  */
    val updatedAt: Long = 0L,
    /** wire: `version`.  */
    val version: Long = 0L,
    /** wire: `timelineKey`. Core-computed stable row key for timeline rendering. */
    val timelineKey: String = "",
    /** wire: `timelineSortTs`. Core-computed timeline sort timestamp in milliseconds. */
    val timelineSortTs: Long = 0L,
    /** wire: `receipt`. Core-computed receipt projection (status and, on the viewer's own group messages, the read summary); always present on messages the SDK returns. */
    val receipt: MessageReceiptView? = null,
)
