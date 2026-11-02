// GENERATED. Do not edit by hand.
import 'display_name.dart';
import 'message_content.dart';
import 'message_local_state.dart';
import 'message_receipt_view.dart';
import 'reaction_entry.dart';

/// SDK 层消息类型：与 message.proto 的 Message 属性一致，content 为解码后的 Elem； 另保留 raw_content 与 proto 一致用于持久化/网络，并增加发送者展示字段。
final class Message {
  /// wire: `attributes`. 
  final Map<String, String> attributes;
  /// wire: `channelId`. 会话频道 ID：单聊=对方 user_id，群聊=群 ID，频道/话题=对应 ID
  final String channelId;
  /// wire: `clientCreatedAt`. 客户端本地创建时间，Unix epoch millis。
  final int clientCreatedAt;
  /// wire: `clientMsgId`. 客户端生成ID（去重）
  final String clientMsgId;
  /// wire: `content`. proto结构
  final MessageContent? content;
  /// wire: `conversationId`. 会话ID
  final String conversationId;
  /// wire: `conversationSeq`. 会话内持久化 replay 序列号。
  final int conversationSeq;
  /// wire: `conversationType`. 会话类型
  final int conversationType;
  /// wire: `createdAt`. 消息创建时间，Unix epoch millis。
  final int createdAt;
  /// wire: `extensions`. 扩展数据；未提供时为空。
  final Map<String, List<int>> extensions;
  /// wire: `isEdited`. 
  final bool isEdited;
  /// wire: `isRead`. 
  final bool isRead;
  /// wire: `isRecalled`. 
  final bool isRecalled;
  /// wire: `localState`. 
  final MessageLocalState? localState;
  /// wire: `mentionAll`. 
  final bool mentionAll;
  /// wire: `mentionUsers`. 
  final List<String> mentionUsers;
  /// wire: `messageType`. 消息类型
  final int messageType;
  /// wire: `quotePreview`. 
  final String? quotePreview;
  /// wire: `reactions`. 表情反应快照（由 ReactionEvent 驱动更新并持久化）
  final List<ReactionEntry> reactions;
  /// wire: `replyTo`. 
  final String? replyTo;
  /// wire: `sender`. 发送者名：别名、群会话里的会话内昵称、资料名、发送时快照（`sender_name`），都没有时为 结构化的「无名」。读取时由核心投影，不落库；SDK 交出的消息都带它。
  final DisplayName sender;
  /// wire: `senderAvatar`. 
  final String senderAvatar;
  /// wire: `senderDisplayName`. 旧字段：身份缓存里发送者的资料名（是真名字时），否则为空，永不为 id。读发送者名用 `sender`。
  final String senderDisplayName;
  /// wire: `senderId`. 发送者
  final String senderId;
  /// wire: `senderName`. 
  final String senderName;
  /// wire: `serverId`. 服务端唯一ID
  final String serverId;
  /// wire: `source`. 消息来源
  final int source;
  /// wire: `status`. 
  final int status;
  /// wire: `textPreview`. 列表、搜索、绑定层使用的纯文本预览。
  final String textPreview;
  /// wire: `threadId`. 话题/线程根消息 ID；普通消息为空，话题回复使用该 typed field。
  final String? threadId;
  /// wire: `updatedAt`. 
  final int updatedAt;
  /// wire: `version`. 
  final int version;
  /// wire: `timelineKey`. Core-computed stable row key for timeline rendering.
  final String timelineKey;
  /// wire: `timelineSortTs`. Core-computed timeline sort timestamp in milliseconds.
  final int timelineSortTs;
  /// wire: `receipt`. Core-computed receipt projection (status and, on the viewer's own group messages, the read summary); always present on messages the SDK returns.
  final MessageReceiptView? receipt;

  const Message({
    this.attributes = const {},
    this.channelId = '',
    this.clientCreatedAt = 0,
    this.clientMsgId = '',
    this.content,
    this.conversationId = '',
    this.conversationSeq = 0,
    this.conversationType = 0,
    this.createdAt = 0,
    this.extensions = const {},
    this.isEdited = false,
    this.isRead = false,
    this.isRecalled = false,
    this.localState,
    this.mentionAll = false,
    this.mentionUsers = const [],
    this.messageType = 0,
    this.quotePreview,
    this.reactions = const [],
    this.replyTo,
    required this.sender,
    this.senderAvatar = '',
    this.senderDisplayName = '',
    this.senderId = '',
    this.senderName = '',
    this.serverId = '',
    this.source = 0,
    this.status = 0,
    this.textPreview = '',
    this.threadId,
    this.updatedAt = 0,
    this.version = 0,
    this.timelineKey = '',
    this.timelineSortTs = 0,
    this.receipt,
  });
}
