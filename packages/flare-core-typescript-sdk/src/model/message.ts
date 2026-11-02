/** GENERATED. Do not edit by hand. */
import type { DisplayName } from './display_name';
import type { MessageContent } from './message_content';
import type { MessageLocalState } from './message_local_state';
import type { MessageReceiptView } from './message_receipt_view';
import type { ReactionEntry } from './reaction_entry';

/** SDK 层消息类型：与 message.proto 的 Message 属性一致，content 为解码后的 Elem； 另保留 raw_content 与 proto 一致用于持久化/网络，并增加发送者展示字段。 */
export interface Message {
  /** wire: `attributes`.  */
  attributes: Record<string, string>;
  /** wire: `channelId`. 会话频道 ID：单聊=对方 user_id，群聊=群 ID，频道/话题=对应 ID */
  channelId: string;
  /** wire: `clientCreatedAt`. 客户端本地创建时间，Unix epoch millis。 */
  clientCreatedAt: number;
  /** wire: `clientMsgId`. 客户端生成ID（去重） */
  clientMsgId: string;
  /** wire: `content`. proto结构 */
  content?: MessageContent;
  /** wire: `conversationId`. 会话ID */
  conversationId: string;
  /** wire: `conversationSeq`. 会话内持久化 replay 序列号。 */
  conversationSeq: number;
  /** wire: `conversationType`. 会话类型 */
  conversationType: number;
  /** wire: `createdAt`. 消息创建时间，Unix epoch millis。 */
  createdAt: number;
  /** wire: `extensions`. 扩展数据；未提供时为空。 */
  extensions: Record<string, Uint8Array | number[]>;
  /** wire: `isEdited`.  */
  isEdited: boolean;
  /** wire: `isRead`.  */
  isRead: boolean;
  /** wire: `isRecalled`.  */
  isRecalled: boolean;
  /** wire: `localState`.  */
  localState?: MessageLocalState;
  /** wire: `mentionAll`.  */
  mentionAll: boolean;
  /** wire: `mentionUsers`.  */
  mentionUsers: string[];
  /** wire: `messageType`. 消息类型 */
  messageType: number;
  /** wire: `quotePreview`.  */
  quotePreview?: string;
  /** wire: `reactions`. 表情反应快照（由 ReactionEvent 驱动更新并持久化） */
  reactions: ReactionEntry[];
  /** wire: `replyTo`.  */
  replyTo?: string;
  /** wire: `sender`. 发送者名：别名、群会话里的会话内昵称、资料名、发送时快照（`sender_name`），都没有时为 结构化的「无名」。读取时由核心投影，不落库；SDK 交出的消息都带它。 */
  sender: DisplayName;
  /** wire: `senderAvatar`.  */
  senderAvatar: string;
  /** wire: `senderDisplayName`. 旧字段：身份缓存里发送者的资料名（是真名字时），否则为空，永不为 id。读发送者名用 `sender`。 */
  senderDisplayName: string;
  /** wire: `senderId`. 发送者 */
  senderId: string;
  /** wire: `senderName`.  */
  senderName: string;
  /** wire: `serverId`. 服务端唯一ID */
  serverId: string;
  /** wire: `source`. 消息来源 */
  source: number;
  /** wire: `status`.  */
  status: number;
  /** wire: `textPreview`. 列表、搜索、绑定层使用的纯文本预览。 */
  textPreview: string;
  /** wire: `threadId`. 话题/线程根消息 ID；普通消息为空，话题回复使用该 typed field。 */
  threadId?: string;
  /** wire: `updatedAt`.  */
  updatedAt: number;
  /** wire: `version`.  */
  version: number;
  /** wire: `timelineKey`. Core-computed stable row key for timeline rendering. */
  timelineKey: string;
  /** wire: `timelineSortTs`. Core-computed timeline sort timestamp in milliseconds. */
  timelineSortTs: number;
  /** wire: `receipt`. Core-computed receipt projection (status and, on the viewer's own group messages, the read summary); always present on messages the SDK returns. */
  receipt?: MessageReceiptView;
}
