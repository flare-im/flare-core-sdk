// GENERATED. Do not edit by hand.
import 'conversation_participant.dart';
import '../common/enums/conversation_type.dart';
import 'display_name.dart';
import 'message_preview.dart';

/// SDK 层会话类型：内部统一使用，从 proto ConversationSummary 获取后即转换为此类型。 与 message.rs 的 IMMessage 一致：扁平字段、serde camelCase。
final class Conversation {
  /// wire: `avatarUrl`. 
  final String avatarUrl;
  /// wire: `badge`. 
  final String? badge;
  /// wire: `businessType`. 
  final String businessType;
  /// wire: `channelId`. 会话路由 ID：单聊为对方 user_id；群/频道为业务 channel（与 proto `channel_id` 一致）
  final String channelId;
  /// wire: `conversationId`. 
  final String conversationId;
  /// wire: `conversationType`. 
  final ConversationType conversationType;
  /// wire: `createdAt`. 
  final int createdAt;
  /// wire: `description`. 
  final String? description;
  /// wire: `displayName`. 业务名（服务端或业务 SDK 给的会话名），可为空，永不为 id；列表标题读 `title`。
  final String displayName;
  /// wire: `draft`. 
  final String? draft;
  /// wire: `ext`. 扩展键值（与 proto ext 对应）
  final Map<String, String> ext;
  /// wire: `isArchived`. 
  final bool isArchived;
  /// wire: `isMentionOnly`. Notification preference. None means the sync source did not supply it.
  final bool? isMentionOnly;
  /// wire: `isMuted`. 
  final bool isMuted;
  /// wire: `isPinned`. 
  final bool isPinned;
  /// wire: `lastMessage`. 
  final MessagePreview? lastMessage;
  /// wire: `lastMessageAt`. 
  final int? lastMessageAt;
  /// wire: `lastMessageId`. 
  final String? lastMessageId;
  /// wire: `lastMessagePreview`. 
  final String? lastMessagePreview;
  /// wire: `lastReadSeq`. 已读序列号（与 read_seq 同义）
  final int lastReadSeq;
  /// wire: `lastSender`. 最后一条消息的发送者名（人名解析链，群会话含会话内昵称）；没有最后一条消息时缺省。 读取时由核心投影，不落库。
  final DisplayName? lastSender;
  /// wire: `lastSenderAvatarUrl`. 最后一条消息发送者头像 URL
  final String lastSenderAvatarUrl;
  /// wire: `lastSenderId`. 
  final String? lastSenderId;
  /// wire: `lastSenderNickname`. 旧字段：最后一条消息发送者在身份缓存里的资料名（是真名字时），否则为本地已存的名字或空串， 永不为 id。列表读 `last_sender`。
  final String lastSenderNickname;
  /// wire: `maxSeq`. 
  final int maxSeq;
  /// wire: `memberPreview`. 摘要级成员预览，最多少量成员，不能作为完整成员列表使用。
  final List<ConversationParticipant> memberPreview;
  /// wire: `membersCount`. 
  final int membersCount;
  /// wire: `mentionCount`. 
  final int mentionCount;
  /// wire: `mentionMe`. 
  final bool mentionMe;
  /// wire: `notifyAll`. In a large group, whether the current user turned on notifications for every message (large groups otherwise alert only on mentions). False when never turned on.
  final bool notifyAll;
  /// wire: `participantVersion`. 服务端成员读模型版本。完整成员通过独立 participants 同步拉取。
  final int participantVersion;
  /// wire: `participants`. 已按需同步到本地的完整成员快照；会话摘要同步不会填充该字段。
  final List<ConversationParticipant> participants;
  /// wire: `peerReadSeq`. 对端（其他成员）最大已读序列号；用于发送方已读双勾在重连/重登后恢复。 由服务端同步摘要 `ext.peer_read_seq` 下发并持久化。
  final int peerReadSeq;
  /// wire: `remark`. 
  final String? remark;
  /// wire: `role`. 
  final String? role;
  /// wire: `title`. 列表与聊天头显示的会话标题：备注、单聊对端人名、业务名、无名群的成员名拼接， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的会话都带它。
  final DisplayName title;
  /// wire: `unreadCount`. 
  final int unreadCount;
  /// wire: `updatedAt`. 
  final int updatedAt;
  /// wire: `updatedAtTs`. 更新时间戳（毫秒，用于排序/筛选）
  final int? updatedAtTs;
  /// wire: `version`. 
  final int version;
  /// wire: `visibleAfterSeq`. 当前用户的历史可见边界；seq <= visible_after_seq 的消息不可见，不参与冷启动回灌。
  final int visibleAfterSeq;

  const Conversation({
    this.avatarUrl = '',
    this.badge,
    this.businessType = '',
    this.channelId = '',
    this.conversationId = '',
    required this.conversationType,
    this.createdAt = 0,
    this.description,
    this.displayName = '',
    this.draft,
    this.ext = const {},
    this.isArchived = false,
    this.isMentionOnly,
    this.isMuted = false,
    this.isPinned = false,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastReadSeq = 0,
    this.lastSender,
    this.lastSenderAvatarUrl = '',
    this.lastSenderId,
    this.lastSenderNickname = '',
    this.maxSeq = 0,
    this.memberPreview = const [],
    this.membersCount = 0,
    this.mentionCount = 0,
    this.mentionMe = false,
    this.notifyAll = false,
    this.participantVersion = 0,
    this.participants = const [],
    this.peerReadSeq = 0,
    this.remark,
    this.role,
    required this.title,
    this.unreadCount = 0,
    this.updatedAt = 0,
    this.updatedAtTs,
    this.version = 0,
    this.visibleAfterSeq = 0,
  });
}
