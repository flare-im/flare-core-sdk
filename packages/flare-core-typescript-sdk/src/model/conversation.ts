/** GENERATED. Do not edit by hand. */
import type { ConversationParticipant } from './conversation_participant';
import type { ConversationType } from './conversation_type';
import type { DisplayName } from './display_name';
import type { MessagePreview } from './message_preview';

/** SDK 层会话类型：内部统一使用，从 proto ConversationSummary 获取后即转换为此类型。 与 message.rs 的 IMMessage 一致：扁平字段、serde camelCase。 */
export interface Conversation {
  /** wire: `avatarUrl`.  */
  avatarUrl: string;
  /** wire: `badge`.  */
  badge?: string;
  /** wire: `businessType`.  */
  businessType: string;
  /** wire: `channelId`. 会话路由 ID：单聊为对方 user_id；群/频道为业务 channel（与 proto `channel_id` 一致） */
  channelId: string;
  /** wire: `conversationId`.  */
  conversationId: string;
  /** wire: `conversationType`.  */
  conversationType: ConversationType;
  /** wire: `createdAt`.  */
  createdAt: number;
  /** wire: `description`.  */
  description?: string;
  /** wire: `displayName`. 业务名（服务端或业务 SDK 给的会话名），可为空，永不为 id；列表标题读 `title`。 */
  displayName: string;
  /** wire: `draft`.  */
  draft?: string;
  /** wire: `ext`. 扩展键值（与 proto ext 对应） */
  ext: Record<string, string>;
  /** wire: `isArchived`.  */
  isArchived: boolean;
  /** wire: `isMentionOnly`. Notification preference. None means the sync source did not supply it. */
  isMentionOnly?: boolean;
  /** wire: `isMuted`.  */
  isMuted: boolean;
  /** wire: `isPinned`.  */
  isPinned: boolean;
  /** wire: `lastMessage`.  */
  lastMessage?: MessagePreview;
  /** wire: `lastMessageAt`.  */
  lastMessageAt?: number;
  /** wire: `lastMessageId`.  */
  lastMessageId?: string;
  /** wire: `lastMessagePreview`.  */
  lastMessagePreview?: string;
  /** wire: `lastReadSeq`. 已读序列号（与 read_seq 同义） */
  lastReadSeq: number;
  /** wire: `lastSender`. 最后一条消息的发送者名（人名解析链，群会话含会话内昵称）；没有最后一条消息时缺省。 读取时由核心投影，不落库。 */
  lastSender?: DisplayName;
  /** wire: `lastSenderAvatarUrl`. 最后一条消息发送者头像 URL */
  lastSenderAvatarUrl: string;
  /** wire: `lastSenderId`.  */
  lastSenderId?: string;
  /** wire: `lastSenderNickname`. 旧字段：最后一条消息发送者在身份缓存里的资料名（是真名字时），否则为本地已存的名字或空串， 永不为 id。列表读 `last_sender`。 */
  lastSenderNickname: string;
  /** wire: `maxSeq`.  */
  maxSeq: number;
  /** wire: `memberPreview`. 摘要级成员预览，最多少量成员，不能作为完整成员列表使用。 */
  memberPreview: ConversationParticipant[];
  /** wire: `membersCount`.  */
  membersCount: number;
  /** wire: `mentionCount`.  */
  mentionCount: number;
  /** wire: `mentionMe`.  */
  mentionMe: boolean;
  /** wire: `participantVersion`. 服务端成员读模型版本。完整成员通过独立 participants 同步拉取。 */
  participantVersion: number;
  /** wire: `participants`. 已按需同步到本地的完整成员快照；会话摘要同步不会填充该字段。 */
  participants: ConversationParticipant[];
  /** wire: `peerReadSeq`. 对端（其他成员）最大已读序列号；用于发送方已读双勾在重连/重登后恢复。 由服务端同步摘要 `ext.peer_read_seq` 下发并持久化。 */
  peerReadSeq: number;
  /** wire: `remark`.  */
  remark?: string;
  /** wire: `role`.  */
  role?: string;
  /** wire: `title`. 列表与聊天头显示的会话标题：备注、单聊对端人名、业务名、无名群的成员名拼接， 都没有时为结构化的「无名」。读取时由核心投影，不落库；SDK 交出的会话都带它。 */
  title: DisplayName;
  /** wire: `unreadCount`.  */
  unreadCount: number;
  /** wire: `updatedAt`.  */
  updatedAt: number;
  /** wire: `updatedAtTs`. 更新时间戳（毫秒，用于排序/筛选） */
  updatedAtTs?: number;
  /** wire: `version`.  */
  version: number;
  /** wire: `visibleAfterSeq`. 当前用户的历史可见边界；seq <= visible_after_seq 的消息不可见，不参与冷启动回灌。 */
  visibleAfterSeq: number;
}
