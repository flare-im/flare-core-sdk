import type { MessageContentType } from '@flare-im/sdk/model';
import type {
  RnCapabilityOperation,
  RnConnectionOperation,
  RnConversationAction,
  RnMediaLabOperation,
  RnMessageDispatchOperation,
  RnSessionOperation,
} from './application/workbench/h5Parity';

export type WorkbenchMode = 'login' | 'sync' | 'conversations' | 'chat' | 'sdk' | 'search' | 'builder' | 'media';
export type MediaQueryOp = RnMediaLabOperation;
export type ConversationFilter = 'all' | 'unread' | 'mention' | 'pinned' | 'muted' | 'archived' | 'draft';
export type SdkStatus = 'idle' | 'connecting' | 'ready' | 'disconnected' | 'error';
export type PresenceStatus = 'online' | 'offline' | 'busy';
export type ComposerPanel = 'emoji' | 'sticker' | 'more' | null;

/** What the sign-in screen collects. Where to connect is the bundle's access configuration (src/config/access.ts). */
export type LoginFormState = {
  userId: string;
  token: string;
  dataUrl: string;
  tenantId: string;
};

export type HomeSyncStep = 'idle' | 'session' | 'conversations' | 'unread' | 'preview' | 'ready' | 'failed';

export type HomeSyncProgress = {
  step: HomeSyncStep;
  title: string;
  detail: string;
  percent: number;
};

export type SdkLabInputs = {
  buildOp: string;
  dispatchOp: RnMessageDispatchOperation;
  messageText: string;
  messageId: string;
  query: string;
  reaction: string;
  capability: string;
  capabilityTargetUserId: string;
  fileId: string;
  mediaUrl: string;
  mediaCacheRoot: string;
  mediaCacheMaxBytes: number;
  downloadSubfolder: string;
  downloadKey: string;
  displayFileName: string;
  sourcePath: string;
  sourceUrl: string;
  remoteFileId: string;
  heartbeatNatTimeoutSecs: number;
  tokenTtlSecs: number;
  draft: string;
  jsonParams: string;
};

export type SdkLabOperation =
  | RnMessageDispatchOperation
  | RnMediaLabOperation
  | RnCapabilityOperation
  | RnConnectionOperation
  | RnSessionOperation
  | RnConversationAction;

export type ConversationItem = {
  id: string;
  channelId: string;
  title: string;
  avatar: string;
  avatarUrl?: string;
  avatarColor: string;
  presence: PresenceStatus;
  lastMessagePreview: string;
  lastMessagePreviewKind?: 'text' | 'emoji' | 'sticker';
  lastMessageAt: string;
  unreadCount: number;
  mentionMe: boolean;
  pinned: boolean;
  muted: boolean;
  archived: boolean;
  draft: string;
  maxSeq: number;
  peerReadSeq: number;
  membersCount: number;
};

export type TimelineMessage = {
  id: string;
  clientMsgId?: string;
  serverId?: string;
  authorId: string;
  authorName: string;
  direction: 'inbound' | 'outbound';
  text: string;
  time: string;
  seq: number;
  status: 'sending' | 'sent' | 'delivered' | 'read' | 'failed' | 'received';
  contentType: MessageContentType;
  reactions: string[];
  pinned?: boolean;
  recalled?: boolean;
  edited?: boolean;
};

export type UploadTask = {
  id: string;
  name: string;
  progress: number;
  status: 'queued' | 'uploading' | 'success' | 'failed';
};
