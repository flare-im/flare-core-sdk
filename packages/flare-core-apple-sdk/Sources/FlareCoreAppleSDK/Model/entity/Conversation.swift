import Foundation

/// GENERATED. Do not edit by hand.
/// SDK 层会话类型：内部统一使用，从 proto ConversationSummary 获取后即转换为此类型。 与 message.rs 的 IMMessage 一致：扁平字段、serde camelCase。
public struct Conversation: Codable, Sendable {
    /// wire: `avatarUrl`. 
    public let avatarUrl: String
    /// wire: `badge`. 
    public let badge: String?
    /// wire: `businessType`. 
    public let businessType: String
    /// wire: `channelId`. 会话路由 ID：单聊为对方 user_id；群/频道为业务 channel（与 proto `channel_id` 一致）
    public let channelId: String
    /// wire: `conversationId`. 
    public let conversationId: String
    /// wire: `conversationType`. 
    public let conversationType: ConversationType
    /// wire: `createdAt`. 
    public let createdAt: UInt64
    /// wire: `description`. 
    public let description: String?
    /// wire: `displayName`. 业务名（服务端或业务 SDK 给的会话名），可为空，永不为 id；列表标题读 `title`。
    public let displayName: String
    /// wire: `draft`. 
    public let draft: String?
    /// wire: `ext`. 扩展键值（与 proto ext 对应）
    public let ext: [String: String]
    /// wire: `isArchived`. 
    public let isArchived: Bool
    /// wire: `isMuted`. 
    public let isMuted: Bool
    /// wire: `isPinned`. 
    public let isPinned: Bool
    /// wire: `lastMessage`. 
    public let lastMessage: MessagePreview?
    /// wire: `lastMessageAt`. 
    public let lastMessageAt: UInt64?
    /// wire: `lastMessageId`. 
    public let lastMessageId: String?
    /// wire: `lastMessagePreview`. 
    public let lastMessagePreview: String?
    /// wire: `lastReadSeq`. 已读序列号（与 read_seq 同义）
    public let lastReadSeq: UInt64
    /// wire: `lastSender`. 最后一条消息的发送者名（人名解析链，群会话含会话内昵称）；没有最后一条消息时缺省。 读取时由核心投影，不落库。
    public let lastSender: DisplayName?
    /// wire: `lastSenderAvatarUrl`. 最后一条消息发送者头像 URL
    public let lastSenderAvatarUrl: String
    /// wire: `lastSenderId`. 
    public let lastSenderId: String?
    /// wire: `lastSenderNickname`. 旧字段：最后一条消息发送者在身份缓存里的资料名（是真名字时），否则为本地已存的名字或空串， 永不为 id。列表读 `last_sender`。
    public let lastSenderNickname: String
    /// wire: `maxSeq`. 
    public let maxSeq: UInt64
    /// wire: `memberPreview`. 摘要级成员预览，最多少量成员，不能作为完整成员列表使用。
    public let memberPreview: [ConversationParticipant]
    /// wire: `membersCount`. 
    public let membersCount: UInt32
    /// wire: `mentionCount`. 
    public let mentionCount: UInt32
    /// wire: `mentionMe`. 
    public let mentionMe: Bool
    /// wire: `participantVersion`. 服务端成员读模型版本。完整成员通过独立 participants 同步拉取。
    public let participantVersion: UInt64
    /// wire: `participants`. 已按需同步到本地的完整成员快照；会话摘要同步不会填充该字段。
    public let participants: [ConversationParticipant]
    /// wire: `peerReadSeq`. 对端（其他成员）最大已读序列号；用于发送方已读双勾在重连/重登后恢复。 由服务端同步摘要 `ext.peer_read_seq` 下发并持久化。
    public let peerReadSeq: UInt64
    /// wire: `remark`. 
    public let remark: String?
    /// wire: `role`. 
    public let role: String?
    /// wire: `title`. 列表与聊天头显示的会话标题：备注、单聊对端人名、业务名、无名群的成员名拼接， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的会话都带它。
    public let title: DisplayName
    /// wire: `unreadCount`. 
    public let unreadCount: UInt32
    /// wire: `updatedAt`. 
    public let updatedAt: UInt64
    /// wire: `updatedAtTs`. 更新时间戳（毫秒，用于排序/筛选）
    public let updatedAtTs: UInt64?
    /// wire: `version`. 
    public let version: UInt64
    /// wire: `visibleAfterSeq`. 当前用户的历史可见边界；seq <= visible_after_seq 的消息不可见，不参与冷启动回灌。
    public let visibleAfterSeq: UInt64

    public init(avatarUrl: String = "", badge: String? = nil, businessType: String = "", channelId: String = "", conversationId: String = "", conversationType: ConversationType, createdAt: UInt64 = 0, description: String? = nil, displayName: String = "", draft: String? = nil, ext: [String: String] = [:], isArchived: Bool = false, isMuted: Bool = false, isPinned: Bool = false, lastMessage: MessagePreview? = nil, lastMessageAt: UInt64? = nil, lastMessageId: String? = nil, lastMessagePreview: String? = nil, lastReadSeq: UInt64 = 0, lastSender: DisplayName? = nil, lastSenderAvatarUrl: String = "", lastSenderId: String? = nil, lastSenderNickname: String = "", maxSeq: UInt64 = 0, memberPreview: [ConversationParticipant] = [], membersCount: UInt32 = 0, mentionCount: UInt32 = 0, mentionMe: Bool = false, participantVersion: UInt64 = 0, participants: [ConversationParticipant] = [], peerReadSeq: UInt64 = 0, remark: String? = nil, role: String? = nil, title: DisplayName, unreadCount: UInt32 = 0, updatedAt: UInt64 = 0, updatedAtTs: UInt64? = nil, version: UInt64 = 0, visibleAfterSeq: UInt64 = 0) {
        self.avatarUrl = avatarUrl
        self.badge = badge
        self.businessType = businessType
        self.channelId = channelId
        self.conversationId = conversationId
        self.conversationType = conversationType
        self.createdAt = createdAt
        self.description = description
        self.displayName = displayName
        self.draft = draft
        self.ext = ext
        self.isArchived = isArchived
        self.isMuted = isMuted
        self.isPinned = isPinned
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.lastMessageId = lastMessageId
        self.lastMessagePreview = lastMessagePreview
        self.lastReadSeq = lastReadSeq
        self.lastSender = lastSender
        self.lastSenderAvatarUrl = lastSenderAvatarUrl
        self.lastSenderId = lastSenderId
        self.lastSenderNickname = lastSenderNickname
        self.maxSeq = maxSeq
        self.memberPreview = memberPreview
        self.membersCount = membersCount
        self.mentionCount = mentionCount
        self.mentionMe = mentionMe
        self.participantVersion = participantVersion
        self.participants = participants
        self.peerReadSeq = peerReadSeq
        self.remark = remark
        self.role = role
        self.title = title
        self.unreadCount = unreadCount
        self.updatedAt = updatedAt
        self.updatedAtTs = updatedAtTs
        self.version = version
        self.visibleAfterSeq = visibleAfterSeq
    }
}
