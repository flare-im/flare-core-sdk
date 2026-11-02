import Foundation

/// GENERATED. Do not edit by hand.
/// SDK 层消息类型：与 message.proto 的 Message 属性一致，content 为解码后的 Elem； 另保留 raw_content 与 proto 一致用于持久化/网络，并增加发送者展示字段。
public struct Message: Sendable {
    /// wire: `attributes`. 
    public let attributes: [String: String]
    /// wire: `channelId`. 会话频道 ID：单聊=对方 user_id，群聊=群 ID，频道/话题=对应 ID
    public let channelId: String
    /// wire: `clientCreatedAt`. 客户端本地创建时间，Unix epoch millis。
    public let clientCreatedAt: UInt64
    /// wire: `clientMsgId`. 客户端生成ID（去重）
    public let clientMsgId: String
    /// wire: `content`. proto结构
    public let content: MessageContent?
    /// wire: `conversationId`. 会话ID
    public let conversationId: String
    /// wire: `conversationSeq`. 会话内持久化 replay 序列号。
    public let conversationSeq: UInt64
    /// wire: `conversationType`. 会话类型
    public let conversationType: Int32
    /// wire: `createdAt`. 消息创建时间，Unix epoch millis。
    public let createdAt: UInt64
    /// wire: `extensions`. 扩展数据；未提供时为空。
    public let extensions: [String: [UInt8]]
    /// wire: `isEdited`. 
    public let isEdited: Bool
    /// wire: `isRead`. 
    public let isRead: Bool
    /// wire: `isRecalled`. 
    public let isRecalled: Bool
    /// wire: `localState`. 
    public let localState: MessageLocalState?
    /// wire: `mentionAll`. 
    public let mentionAll: Bool
    /// wire: `mentionUsers`. 
    public let mentionUsers: [String]
    /// wire: `messageType`. 消息类型
    public let messageType: Int32
    /// wire: `quotePreview`. 
    public let quotePreview: String?
    /// wire: `reactions`. 表情反应快照（由 ReactionEvent 驱动更新并持久化）
    public let reactions: [ReactionEntry]
    /// wire: `replyTo`. 
    public let replyTo: String?
    /// wire: `sender`. 发送者名：别名、群会话里的会话内昵称、资料名、发送时快照（`sender_name`），都没有时为 结构化的「无名」。读取时由核心投影，不落库；SDK 交出的消息都带它。
    public let sender: DisplayName
    /// wire: `senderAvatar`. 
    public let senderAvatar: String
    /// wire: `senderDisplayName`. 旧字段：身份缓存里发送者的资料名（是真名字时），否则为空，永不为 id。读发送者名用 `sender`。
    public let senderDisplayName: String
    /// wire: `senderId`. 发送者
    public let senderId: String
    /// wire: `senderName`. 
    public let senderName: String
    /// wire: `serverId`. 服务端唯一ID
    public let serverId: String
    /// wire: `source`. 消息来源
    public let source: Int32
    /// wire: `status`. 
    public let status: Int32
    /// wire: `textPreview`. 列表、搜索、绑定层使用的纯文本预览。
    public let textPreview: String
    /// wire: `threadId`. 话题/线程根消息 ID；普通消息为空，话题回复使用该 typed field。
    public let threadId: String?
    /// wire: `updatedAt`. 
    public let updatedAt: UInt64
    /// wire: `version`. 
    public let version: UInt64
    /// wire: `timelineKey`. Core-computed stable row key for timeline rendering.
    public let timelineKey: String
    /// wire: `timelineSortTs`. Core-computed timeline sort timestamp in milliseconds.
    public let timelineSortTs: UInt64
    /// wire: `receipt`. Core-computed receipt projection (status and, on the viewer's own group messages, the read summary); always present on messages the SDK returns.
    public let receipt: MessageReceiptView?

    public init(attributes: [String: String] = [:], channelId: String = "", clientCreatedAt: UInt64 = 0, clientMsgId: String = "", content: MessageContent? = nil, conversationId: String = "", conversationSeq: UInt64 = 0, conversationType: Int32 = 0, createdAt: UInt64 = 0, extensions: [String: [UInt8]] = [:], isEdited: Bool = false, isRead: Bool = false, isRecalled: Bool = false, localState: MessageLocalState? = nil, mentionAll: Bool = false, mentionUsers: [String] = [], messageType: Int32 = 0, quotePreview: String? = nil, reactions: [ReactionEntry] = [], replyTo: String? = nil, sender: DisplayName, senderAvatar: String = "", senderDisplayName: String = "", senderId: String = "", senderName: String = "", serverId: String = "", source: Int32 = 0, status: Int32 = 0, textPreview: String = "", threadId: String? = nil, updatedAt: UInt64 = 0, version: UInt64 = 0, timelineKey: String = "", timelineSortTs: UInt64 = 0, receipt: MessageReceiptView? = nil) {
        self.attributes = attributes
        self.channelId = channelId
        self.clientCreatedAt = clientCreatedAt
        self.clientMsgId = clientMsgId
        self.content = content
        self.conversationId = conversationId
        self.conversationSeq = conversationSeq
        self.conversationType = conversationType
        self.createdAt = createdAt
        self.extensions = extensions
        self.isEdited = isEdited
        self.isRead = isRead
        self.isRecalled = isRecalled
        self.localState = localState
        self.mentionAll = mentionAll
        self.mentionUsers = mentionUsers
        self.messageType = messageType
        self.quotePreview = quotePreview
        self.reactions = reactions
        self.replyTo = replyTo
        self.sender = sender
        self.senderAvatar = senderAvatar
        self.senderDisplayName = senderDisplayName
        self.senderId = senderId
        self.senderName = senderName
        self.serverId = serverId
        self.source = source
        self.status = status
        self.textPreview = textPreview
        self.threadId = threadId
        self.updatedAt = updatedAt
        self.version = version
        self.timelineKey = timelineKey
        self.timelineSortTs = timelineSortTs
        self.receipt = receipt
    }
}
