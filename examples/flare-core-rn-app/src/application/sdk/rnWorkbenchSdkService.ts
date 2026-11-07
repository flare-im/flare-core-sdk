import type { FlareImClient, SdkConfig } from '@flare-im/sdk/api';
import type {
  ConnectionStatus,
  Conversation,
  ImageGroupContentPayload,
  Message,
  MessageBuildCatalogEntry,
  MessageContent,
  SendMessageResponse,
} from '@flare-im/sdk/model';
import { MessageBuildOp, MessageContentType } from '@flare-im/sdk/model';
import { buildAccessConfig } from '../../config/access';
import {
  RN_CAPABILITY_OPERATIONS,
  RN_CONNECTION_OPERATIONS,
  RN_MEDIA_LAB_OPERATIONS,
  RN_MESSAGE_DISPATCH_OPERATIONS,
  RN_SESSION_OPERATIONS,
  type RnCapabilityOperation,
  type RnConnectionOperation,
  type RnConversationAction,
  type RnMediaLabOperation,
  type RnMessageDispatchOperation,
  type RnSessionOperation,
} from '../workbench/h5Parity';
import type {
  ConversationItem,
  HomeSyncProgress,
  LoginFormState,
  SdkLabInputs,
  TimelineMessage,
} from '../../types';
import { conversationToItem, messagesToTimeline } from '../mappers/sdkViewModels';

type DiagnosticsSnapshot = Record<'sdkVersion' | 'ffiContract' | 'dataRoot' | 'runtimeHealth' | 'connectionPhase', string>;

type LoginSnapshot = {
  currentUserId: string;
  diagnostics: DiagnosticsSnapshot;
  messageBuildCatalog: MessageBuildCatalogEntry[];
  /** `connection.getStatus` right after sign-in; the core keeps reporting it as `connection://status`. */
  connectionStatus: ConnectionStatus;
};

type HomeSyncSnapshot = {
  conversations: ConversationItem[];
};

export type RnWorkbenchSdkService = {
  getDiagnostics(): Promise<DiagnosticsSnapshot>;
  initializeAndLogin(form: LoginFormState): Promise<LoginSnapshot>;
  syncHome(): Promise<HomeSyncSnapshot>;
  logout(): Promise<void>;
  currentUserId(): Promise<string>;
  listConversations(): Promise<ConversationItem[]>;
  getOneConversation(peerUserId: string, conversationType?: 'single' | 'group'): Promise<ConversationItem>;
  openTimeline(conversationId: string, currentUserId: string, messageLimit?: number): Promise<{
    conversation?: ConversationItem;
    messages: TimelineMessage[];
    hasMore: boolean;
  }>;
  sendTextMessage(conversationId: string, text: string): Promise<{
    draft: Message;
    ack: SendMessageResponse;
  }>;
  buildAndSend(op: MessageBuildOp | string, conversationId: string, params?: Record<string, unknown>): Promise<SendMessageResponse>;
  runConversationOperation(kind: RnConversationAction, conversationId: string, draft?: string): Promise<void>;
  markConversationRead(conversationId: string): Promise<void>;
  markConversationUnread(conversationId: string): Promise<void>;
  setConversationPinned(conversationId: string, pinned: boolean): Promise<void>;
  setConversationMuted(conversationId: string, muted: boolean): Promise<void>;
  setConversationArchived(conversationId: string, archived: boolean): Promise<void>;
  updateDraft(conversationId: string, draft: string): Promise<void>;
  clearLocalHistory(conversationId: string): Promise<void>;
  deleteConversation(conversationId: string): Promise<void>;
  addReaction(messageId: string, emoji: string): Promise<void>;
  removeReaction(messageId: string, emoji: string): Promise<void>;
  dispatchMessage(op: RnMessageDispatchOperation, input: DispatchInput): Promise<unknown>;
  searchMessages(
    keyword: string,
    currentUserId: string,
    conversationId?: string,
    limit?: number,
  ): Promise<TimelineMessage[]>;
  runMediaQuery(op: RnMediaLabOperation, input: SdkLabInputs): Promise<string>;
  runCapabilityOperation(op: RnCapabilityOperation, input: SdkLabInputs, currentUserId: string): Promise<string>;
  runConnectionOperation(op: RnConnectionOperation): Promise<string>;
  runSessionOperation(op: RnSessionOperation, input: SdkLabInputs, form: LoginFormState): Promise<string>;
  subscribeWorkbenchEvents(): Promise<string>;
};

export type DispatchInput = {
  conversationId: string;
  messageId: string;
  keyword: string;
  text: string;
  emoji: string;
  jsonParams: Record<string, unknown>;
};

export const defaultLoginForm: LoginFormState = {
  userId: '11',
  token: '',
  dataUrl: '',
  tenantId: '0',
};

export const defaultHomeSyncProgress: HomeSyncProgress = {
  step: 'idle',
  title: '准备同步',
  detail: '等待 SDK 会话建立',
  percent: 0,
};

export const defaultSdkLabInputs: SdkLabInputs = {
  buildOp: MessageBuildOp.CreateText,
  dispatchOp: 'search',
  messageText: '',
  messageId: '',
  query: '',
  reaction: '👍',
  capability: '',
  capabilityTargetUserId: '',
  fileId: '',
  mediaUrl: '',
  mediaCacheRoot: 'memory://flare-core-rn-app/media-cache',
  mediaCacheMaxBytes: 134217728,
  downloadSubfolder: 'flare-im',
  downloadKey: '',
  displayFileName: '',
  sourcePath: '',
  sourceUrl: '',
  remoteFileId: '',
  heartbeatNatTimeoutSecs: 60,
  tokenTtlSecs: 3600,
  draft: '',
  jsonParams: '{}',
};

const sdkEventSources = [
  'lifecycle',
  'connection',
  'access',
  'message',
  'conversation',
  'sync',
  'presence',
  'media',
  'capability',
] as const;

export function createRnWorkbenchSdkService(client: FlareImClient): RnWorkbenchSdkService {
  return {
    async getDiagnostics() {
      return refreshDiagnostics(client);
    },

    async initializeAndLogin(form) {
      const identity = normalizeLoginIdentity(form);
      // 应用托管：登录表单带了现成 token 就原样用；SDK 托管：留空，SDK 签发并自动刷新。
      // 客户端不再本地签发（那等于把签名密钥打进 App）。
      const explicitToken = form.token.trim();
      await client.init(coreSdkConfig(form, identity.tenantId, explicitToken));
      await client.events.subscribeEvents({ sources: [...sdkEventSources] });
      await client.login(explicitToken ? { userId: identity.userId, token: explicitToken } : { userId: identity.userId });
      const [diagnostics, catalog, connectionStatus] = await Promise.all([
        refreshDiagnostics(client),
        client.messageBuilder.listSupportedBuildOperations(),
        client.connection.getStatus(),
      ]);
      return {
        currentUserId: identity.userId,
        diagnostics,
        messageBuildCatalog: [...catalog.entries],
        connectionStatus,
      };
    },

    async syncHome() {
      const snapshot = await client.conversations.bootstrapHomeTimeline({ conversationLimit: 100 });
      return {
        conversations: snapshot.conversations.map(conversationToItem),
      };
    },

    logout() {
      return client.logout();
    },

    async currentUserId() {
      const response = await client.currentUserId();
      return stringField(response, 'userId');
    },

    async listConversations() {
      const response = await client.conversations.listConversations();
      return response.conversations.map(conversationToItem);
    },

    async getOneConversation(peerUserId, conversationType = 'single') {
      if (conversationType === 'group') {
        const conversation = await client.conversations.getGroupConversationByUserIds({ userIds: [peerUserId] });
        return conversationToItem(conversation);
      }
      const conversation = await client.conversations.getOneConversation({
        sourceId: peerUserId,
        conversationType: 'single',
      });
      return conversationToItem(conversation);
    },

    async openTimeline(conversationId, currentUserId, messageLimit = 100) {
      const snapshot = await client.conversations.openConversationTimeline({ conversationId, messageLimit });
      return {
        conversation: snapshot.conversation ? conversationToItem(snapshot.conversation) : undefined,
        messages: messagesToTimeline(snapshot.messages, currentUserId),
        hasMore: snapshot.hasMore,
      };
    },

    async sendTextMessage(conversationId, text) {
      const draft = await buildTypedMessage(client, MessageBuildOp.CreateText, conversationId, { text });
      const ack = await client.messages.sendMessage({ message: draft });
      return { draft, ack };
    },

    async buildAndSend(op, conversationId, params = {}) {
      const draft = await buildTypedMessage(client, op, conversationId, params);
      return client.messages.sendMessage({ message: draft });
    },

    async runConversationOperation(kind, conversationId, draft = '') {
      if (kind === 'mark_unread') await client.conversations.markConversationUnread({ conversationId });
      else if (kind === 'mark_read') await client.conversations.markConversationRead({ conversationId });
      else if (kind === 'pin' || kind === 'unpin') await client.conversations.setConversationPinned({ conversationId, pinned: kind === 'pin' });
      else if (kind === 'mute' || kind === 'unmute') await client.conversations.setConversationMuted({ conversationId, muted: kind === 'mute' });
      else if (kind === 'archive' || kind === 'unarchive') await client.conversations.setConversationArchived({ conversationId, archived: kind === 'archive' });
      else if (kind === 'clear_history') await client.conversations.clearLocalChatHistory({ conversationId });
      else if (kind === 'draft') await client.conversations.updateConversationDraft({ conversationId, draft });
      else if (kind === 'delete') await client.conversations.deleteConversation({ conversationId });
    },

    markConversationRead(conversationId) {
      return client.conversations.markConversationRead({ conversationId });
    },

    async markConversationUnread(conversationId) {
      await client.conversations.markConversationUnread({ conversationId });
    },

    setConversationPinned(conversationId, pinned) {
      return client.conversations.setConversationPinned({ conversationId, pinned });
    },

    setConversationMuted(conversationId, muted) {
      return client.conversations.setConversationMuted({ conversationId, muted });
    },

    setConversationArchived(conversationId, archived) {
      return client.conversations.setConversationArchived({ conversationId, archived });
    },

    updateDraft(conversationId, draft) {
      return client.conversations.updateConversationDraft({ conversationId, draft });
    },

    clearLocalHistory(conversationId) {
      return client.conversations.clearLocalChatHistory({ conversationId });
    },

    deleteConversation(conversationId) {
      return client.conversations.deleteConversation({ conversationId });
    },

    addReaction(messageId, emoji) {
      return client.messages.addReaction({ messageId, emoji });
    },

    removeReaction(messageId, emoji) {
      return client.messages.removeReaction({ messageId, emoji });
    },

    dispatchMessage(op, input) {
      assertKnownOperation(op, RN_MESSAGE_DISPATCH_OPERATIONS, 'message dispatch');
      return client.messages.dispatchMessage({
        op,
        params: {
          conversationId: input.conversationId,
          messageId: input.messageId,
          clientMsgId: input.messageId,
          text: input.text,
          keyword: input.keyword,
          emoji: input.emoji,
          ...input.jsonParams,
        },
      });
    },

    async searchMessages(keyword, currentUserId, conversationId = '', limit = 50) {
      const response = await client.messages.searchMessagesByQuery({
        conversationId,
        keyword,
        kinds: [],
        limit,
        includeRecalled: false,
      });
      return messagesToTimeline(response.messages, currentUserId);
    },

    async runMediaQuery(op, input) {
      assertKnownOperation(op, RN_MEDIA_LAB_OPERATIONS, 'media');
      const params = parseJsonParams(input.jsonParams);
      const result = await runMediaOperation(client, op, input, params);
      return compactJson(result);
    },

    async runCapabilityOperation(op, input, currentUserId) {
      assertKnownOperation(op, RN_CAPABILITY_OPERATIONS, 'capability');
      const params = parseJsonParams(input.jsonParams);
      if (op === 'list') return compactJson(await client.capabilities.listCapabilities({}));
      if (op === 'list_user') return compactJson(await client.capabilities.listUserCapabilities({ userId: currentUserId }));
      if (op === 'grant') {
        await client.capabilities.grantCapability({
          userId: input.capabilityTargetUserId,
          capability: input.capability,
          payload: params,
        });
        return compactJson({ granted: input.capability, userId: input.capabilityTargetUserId });
      }
      if (op === 'revoke') {
        await client.capabilities.revokeCapability({
          userId: input.capabilityTargetUserId,
          capability: input.capability,
          payload: params,
        });
        return compactJson({ revoked: input.capability, userId: input.capabilityTargetUserId });
      }
      return compactJson(await client.capabilities.dispatchCapability({
        operation: 'rn.echo',
        capability: input.capability,
        payload: params,
      }));
    },

    async runConnectionOperation(op) {
      assertKnownOperation(op, RN_CONNECTION_OPERATIONS, 'connection');
      if (op === 'reconnect_now') {
        await client.connection.reconnectNow();
        return compactJson({ reconnecting: true, status: await client.connection.getStatus() });
      }
      if (op === 'disconnect') {
        await client.connection.disconnect();
        return compactJson({ disconnected: true, status: await client.connection.getStatus() });
      }
      if (op === 'access_status') return compactJson(await client.access.getStatus());
      if (op === 'access_points') return compactJson(await client.access.listAccessPoints());
      if (op === 'access_diagnostics') return compactJson(await client.access.exportDiagnostics());
      return compactJson(await client.connection.getStatus());
    },

    async runSessionOperation(op, input, form) {
      assertKnownOperation(op, RN_SESSION_OPERATIONS, 'session');
      if (op === 'runtime_health') return compactJson(await client.diagnostics.getRuntimeHealth());
      if (op === 'heartbeat_interval') return compactJson(await client.heartbeatEffectiveInterval());
      if (op === 'heartbeat_nat_timeout') {
        await client.setHeartbeatNatTimeout({
          natTimeoutSecs: input.heartbeatNatTimeoutSecs > 0 ? input.heartbeatNatTimeoutSecs : undefined,
        });
        return compactJson(await client.heartbeatEffectiveInterval());
      }
      if (op === 'update_access_token') {
        // 客户端不再签发：只把登录表单里粘贴的 token 应用到核心（应用托管形态）。
        // SDK 托管形态下核心自己到期前刷新，这里无事可做。
        const identity = normalizeLoginIdentity(form);
        const accessToken = form.token.trim();
        if (!accessToken) {
          throw new Error('SDK-managed token is refreshed by the core; paste a backend-issued token on the login form to apply one manually');
        }
        await client.updateAccessToken({ accessToken, tenantId: identity.tenantId });
        return compactJson({ updated: true, tokenLength: accessToken.length });
      }
      if (op === 'current_user') return compactJson(await client.currentUserId());
      if (op === 'session_active') {
        return compactJson({
          active: await client.sessionActive(),
          connected: await client.isConnected(),
        });
      }
      return compactJson(await refreshDiagnostics(client));
    },

    async subscribeWorkbenchEvents() {
      return compactJson(await client.events.subscribeEvents({ sources: [...sdkEventSources] }));
    },
  };
}

/**
 * The init request: where to connect is the bundle's access configuration (src/config/access.ts), never a field of
 * the sign-in form; the tenant and data root are the account's. Without a connect token of the host's the SDK
 * issues and renews one itself (SDK-managed).
 */
export function coreSdkConfig(form: Pick<LoginFormState, 'dataUrl'>, tenantId: string, token: string): SdkConfig {
  return {
    access: buildAccessConfig(),
    dataUrl: form.dataUrl,
    tenantId,
    resourceProfile: 'mobile',
    ...(token ? {} : { auth: {} }),
  };
}

async function refreshDiagnostics(client: FlareImClient): Promise<DiagnosticsSnapshot> {
  const [sdkVersion, ffiContract, dataRoot, runtimeHealth, status] = await Promise.all([
    client.diagnostics.getSdkVersion(),
    client.diagnostics.getFfiContractVersion(),
    client.diagnostics.getDataRoot(),
    client.diagnostics.getRuntimeHealth(),
    client.connection.getStatus(),
  ]);
  return {
    sdkVersion: compactJson(sdkVersion),
    ffiContract: compactJson(ffiContract),
    dataRoot: compactJson(dataRoot),
    runtimeHealth: compactJson(runtimeHealth),
    connectionPhase: status.phase,
  };
}

function normalizeLoginIdentity(form: LoginFormState): { userId: string; tenantId: string } {
  const userId = form.userId.trim();
  if (!userId) throw new Error('userId is required');
  return {
    userId,
    tenantId: form.tenantId.trim() || '0',
  };
}

async function buildTypedMessage(
  client: FlareImClient,
  op: MessageBuildOp | string,
  conversationId: string,
  params: Record<string, unknown>,
): Promise<Message> {
  switch (op) {
    case MessageBuildOp.CreateText:
      return client.messageBuilder.buildText({ conversationId, text: stringParam(params, 'text', '来自 RN 的文本消息') });
    case MessageBuildOp.CreateQuote:
      return client.messageBuilder.buildQuote({
        conversationId,
        text: stringParam(params, 'text', '引用回复'),
        quotedMessageId: stringParam(params, 'quotedMessageId', ''),
        quotedTextPreview: stringParam(params, 'quotedTextPreview', ''),
        quotedContent: messageContentParam(params, 'quotedContent'),
      });
    case MessageBuildOp.CreateEmoji:
      return client.messageBuilder.buildEmoji({ conversationId, emoji: stringParam(params, 'emoji', '👍') });
    case MessageBuildOp.CreateSticker:
      return client.messageBuilder.buildSticker({
        conversationId,
        stickerId: stringParam(params, 'stickerId', stringParam(params, 'text', 'like')),
        packageId: stringParam(params, 'packageId', 'rn'),
      });
    case MessageBuildOp.CreateImage:
      return client.messageBuilder.buildImage({
        conversationId,
        imageId: stringParam(params, 'imageId', stringParam(params, 'sourcePath', 'rn-image')),
        payload: optionalRecord(params, 'payload'),
      });
    case MessageBuildOp.CreateImageGroup:
      return client.messageBuilder.buildImageGroup({
        conversationId,
        payload: imageGroupPayload(params),
      });
    case MessageBuildOp.CreateVideo:
      return client.messageBuilder.buildVideo({
        conversationId,
        videoId: stringParam(params, 'videoId', stringParam(params, 'sourcePath', 'rn-video')),
        payload: optionalRecord(params, 'payload'),
      });
    case MessageBuildOp.CreateAudio:
      return client.messageBuilder.buildAudio({
        conversationId,
        audioId: stringParam(params, 'audioId', stringParam(params, 'sourcePath', 'rn-audio')),
        payload: optionalRecord(params, 'payload'),
      });
    case MessageBuildOp.CreateFile:
      return client.messageBuilder.buildFile({
        conversationId,
        fileId: stringParam(params, 'fileId', stringParam(params, 'sourcePath', 'rn-file')),
        payload: optionalRecord(params, 'payload'),
      });
    case MessageBuildOp.CreateRichDoc:
      {
        const markdown = stringParam(params, 'markdown', stringParam(params, 'text', '# RN 富文本'));
        const docJson = stringParam(params, 'docJson');
        const html = stringParam(params, 'html');
        const normalized = docJson
          ? await client.messageBuilder.normalizeRichDocFromDocJson({ docJson })
          : html
            ? await client.messageBuilder.normalizeRichDocFromHtml({ html })
            : await client.messageBuilder.normalizeRichDocFromMarkdown({ markdown });
        const sourcePayloadBase = normalized.sourcePayload
          ? Object.fromEntries(
            Object.entries(normalized.sourcePayload)
              .map(([entryKey, entryValue]) => [entryKey, String(entryValue ?? '')] as const),
          )
          : {};
        const sourcePayload = markdown
          ? { ...sourcePayloadBase, markdown }
          : Object.keys(sourcePayloadBase).length
            ? sourcePayloadBase
            : undefined;
        return client.messageBuilder.buildRichDoc({
          conversationId,
          docJson: normalized.docJson,
          contentSchema: normalized.contentSchema,
          plainText: normalized.plainText,
          inputFormat: normalized.inputFormat,
          sourcePayload,
          title: stringParam(params, 'title', stringParam(params, 'text', 'RN 富文本')),
          searchText: normalized.searchText,
          renderHintsJson: JSON.stringify(normalized.renderHints),
        });
      }
    case MessageBuildOp.CreateLocation:
      return client.messageBuilder.buildLocation({
        conversationId,
        latitude: numberParam(params, 'latitude', 31.2304),
        longitude: numberParam(params, 'longitude', 121.4737),
        title: stringParam(params, 'title', '上海中心'),
        address: stringParam(params, 'address', '上海市浦东新区银城中路'),
      });
    case MessageBuildOp.CreateLinkCard:
      return client.messageBuilder.buildLinkCard({
        conversationId,
        url: stringParam(params, 'url', 'https://flare.im'),
        title: stringParam(params, 'title', 'Flare IM'),
        description: stringParam(params, 'description', '跨端 IM SDK'),
        siteName: stringParam(params, 'siteName', 'flare.im'),
      });
    case MessageBuildOp.CreateCard:
      return client.messageBuilder.buildCard({
        conversationId,
        id: stringParam(params, 'id', `card-${Date.now()}`),
        cardType: stringParam(params, 'cardType', 'info'),
        title: stringParam(params, 'title', '示例卡片'),
        subtitle: stringParam(params, 'subtitle', 'RN MessageBuilder 卡片'),
      });
    case MessageBuildOp.CreateMiniProgram:
      return client.messageBuilder.buildMiniProgram({
        conversationId,
        appId: stringParam(params, 'appId', 'mp-demo'),
        pagePath: stringParam(params, 'pagePath', '/pages/index'),
        title: stringParam(params, 'title', '小程序示例'),
      });
    case MessageBuildOp.CreateSystem:
      return client.messageBuilder.buildSystem({
        conversationId,
        eventKind: stringParam(params, 'eventKind', 'demo'),
        body: stringParam(params, 'body', '系统事件示例'),
      });
    case MessageBuildOp.CreateNotification:
      return client.messageBuilder.buildNotification({
        conversationId,
        title: stringParam(params, 'title', '通知'),
        body: stringParam(params, 'body', stringParam(params, 'text', '这是一条通知消息')),
      });
    case MessageBuildOp.CreateAnnouncement:
      return client.messageBuilder.buildAnnouncement({
        conversationId,
        title: stringParam(params, 'title', '公告'),
        body: stringParam(params, 'body', stringParam(params, 'text', '这是一条群公告')),
      });
    case MessageBuildOp.CreateVote:
      return client.messageBuilder.buildVote({
        conversationId,
        voteId: stringParam(params, 'voteId', `vote-${Date.now()}`),
        title: stringParam(params, 'title', '今天午餐吃什么?'),
        options: arrayParam(params, 'options', ['火锅', '快餐', '沙拉']),
        participantUserIds: arrayParam(params, 'participantUserIds', []),
      });
    case MessageBuildOp.CreateTask:
      return client.messageBuilder.buildTask({
        conversationId,
        taskId: stringParam(params, 'taskId', `task-${Date.now()}`),
        title: stringParam(params, 'title', '示例任务'),
        status: stringParam(params, 'status', 'open'),
        participantUserIds: arrayParam(params, 'participantUserIds', []),
      });
    case MessageBuildOp.CreateSchedule:
      return client.messageBuilder.buildSchedule({
        conversationId,
        scheduleId: stringParam(params, 'scheduleId', `sched-${Date.now()}`),
        title: stringParam(params, 'title', '示例日程'),
        startTimeMs: numberParam(params, 'startTimeMs', Date.now()),
        endTimeMs: numberParam(params, 'endTimeMs', Date.now() + 3600000),
        participantUserIds: arrayParam(params, 'participantUserIds', []),
      });
    case MessageBuildOp.CreateCustom:
      return client.messageBuilder.buildCustom({
        conversationId,
        type: stringParam(params, 'type', 'rn.custom'),
      });
    case MessageBuildOp.CreatePlaceholder:
      return client.messageBuilder.buildPlaceholder({
        conversationId,
        reason: stringParam(params, 'reason', 'rn placeholder'),
      });
    default:
      return client.messageBuilder.buildText({ conversationId, text: `暂不支持的构建操作: ${op}` });
  }
}

async function runMediaOperation(
  client: FlareImClient,
  op: RnMediaLabOperation,
  input: SdkLabInputs,
  params: Record<string, unknown>,
): Promise<unknown> {
  if (op === 'clear') {
    await client.media.clearMediaCache();
    return { cleared: true };
  }
  if (op === 'upload_file' || op === 'upload_image' || op === 'upload_video') {
    const payload = {
      path: input.sourcePath,
      fileId: input.fileId,
      fileName: input.displayFileName,
      ...params,
    };
    if (op === 'upload_image') return client.media.uploadImage(payload);
    if (op === 'upload_video') return client.media.uploadVideo(payload);
    return client.media.uploadFile(payload);
  }
  if (op === 'upload_bytes') {
    const bytes = asciiBytes(`Flare RN SDK Lab ${new Date().toISOString()}`);
    return client.media.uploadBytes({
      bytes,
      fileName: input.displayFileName || 'rn-lab.txt',
      mimeType: 'text/plain',
      ...params,
    });
  }
  if (op === 'delete_file') return client.media.deleteFile({ fileId: input.fileId, hardDelete: Boolean(params.hardDelete), ...params });
  if (op === 'url') return client.media.getMediaUrl({ fileId: input.fileId, mediaUrl: input.mediaUrl });
  if (op === 'temp_url') return client.media.getTempDownloadUrl({ fileId: input.fileId, expiresInSeconds: 900 });
  if (op === 'resolve') return client.media.resolveMediaAccess({ fileId: input.fileId, mediaUrl: input.mediaUrl });
  if (op === 'display_url') return { displayUrl: await client.media.resolveDisplayUrl({ fileId: input.fileId, mediaUrl: input.mediaUrl }) };
  if (op === 'cache_remote') return client.media.cacheRemoteMedia({ fileId: input.fileId, mediaUrl: input.mediaUrl });
  if (op === 'set_root') {
    await client.media.setMediaCacheRoot({ root: input.mediaCacheRoot });
    return { cacheRoot: input.mediaCacheRoot };
  }
  if (op === 'set_max') {
    await client.media.setMediaCacheMaxBytes({ maxBytes: input.mediaCacheMaxBytes });
    return { maxBytes: input.mediaCacheMaxBytes };
  }
  if (op === 'download_subfolder') {
    await client.media.setUserDownloadSubfolder({ subfolder: input.downloadSubfolder });
    return client.media.getUserDownloadSubfolder();
  }
  if (op === 'download_file') {
    return client.media.downloadFileToDownloads({
      downloadKey: input.downloadKey,
      fileId: input.fileId,
      displayFileName: input.displayFileName,
      sourcePath: input.sourcePath || undefined,
      sourceHttpUrl: input.sourceUrl || undefined,
      remoteFileId: input.remoteFileId || input.fileId || undefined,
      expiresIn: 900,
    });
  }
  if (op === 'cancel_download') return client.media.cancelUserFileDownload({ downloadKey: input.downloadKey, fileId: input.fileId });
  if (op === 'saved_path') return client.media.getUserDownloadSavedPath({ downloadKey: input.downloadKey, fileId: input.fileId });
  if (op === 'delete_download') {
    await client.media.deleteUserDownloadRecord({ downloadKey: input.downloadKey, fileId: input.fileId });
    return { deleted: input.downloadKey || input.fileId };
  }
  return client.media.getMediaCacheStats();
}

function compactJson(value: unknown): string {
  const text = JSON.stringify(value);
  if (!text) return '-';
  return text.length > 160 ? `${text.slice(0, 157)}...` : text;
}

function stringField(value: unknown, field: string): string {
  if (!value || typeof value !== 'object') return '';
  const text = (value as Record<string, unknown>)[field];
  return typeof text === 'string' ? text : '';
}

function parseJsonParams(source: string): Record<string, unknown> {
  const raw = source.trim();
  if (!raw) return {};
  const value = JSON.parse(raw);
  return asRecord(value);
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function recordParam(source: Record<string, unknown>, field: string, fallback: Record<string, unknown> = {}): Record<string, unknown> {
  const value = asRecord(source[field]);
  return Object.keys(value).length ? value : fallback;
}

function messageContentParam(source: Record<string, unknown>, field: string): MessageContent {
  const value = asRecord(source[field]);
  const contentType = value.contentType;
  if (typeof contentType === 'string' && Object.values(MessageContentType).includes(contentType as MessageContentType)) {
    return {
      contentType: contentType as MessageContentType,
      data: recordParam(value, 'data'),
    };
  }
  return {
    contentType: MessageContentType.Text,
    data: {
      text: stringParam(source, 'quotedTextPreview', stringParam(source, 'text', '引用消息')),
      mentions: [],
    },
  };
}

function imageGroupPayload(source: Record<string, unknown>): ImageGroupContentPayload {
  const payload = recordParam(source, 'payload');
  const rawImages = payload.images;
  const images = Array.isArray(rawImages)
    ? rawImages
      .map((item) => asRecord(item))
      .map((item) => ({
        imageId: stringParam(item, 'imageId', stringParam(source, 'imageId', 'rn-image')),
        url: stringParam(item, 'url') || undefined,
        title: stringParam(item, 'title') || undefined,
        width: numberParam(item, 'width', 0) || undefined,
        height: numberParam(item, 'height', 0) || undefined,
      }))
      .filter((item) => item.imageId)
    : [];
  const { images: _ignored, ...rest } = payload;
  return {
    ...rest,
    images: images.length ? images : [{ imageId: stringParam(source, 'imageId', 'rn-image') }],
  } as ImageGroupContentPayload;
}

function optionalRecord(source: Record<string, unknown>, field: string): Record<string, unknown> | undefined {
  const value = asRecord(source[field]);
  return Object.keys(value).length ? value : undefined;
}

function stringParam(source: Record<string, unknown>, field: string, fallback = ''): string {
  const value = source[field];
  return typeof value === 'string' && value.trim() ? value : fallback;
}

function numberParam(source: Record<string, unknown>, field: string, fallback: number): number {
  const value = source[field];
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function arrayParam<T>(source: Record<string, unknown>, field: string, fallback: T[]): T[] {
  const value = source[field];
  return Array.isArray(value) ? value as T[] : fallback;
}

function asciiBytes(value: string): number[] {
  return Array.from(value).map((char) => char.charCodeAt(0) & 0xff);
}

function assertKnownOperation<T extends readonly string[]>(value: string, allowed: T, label: string): asserts value is T[number] {
  if (!allowed.includes(value)) {
    throw new Error(`unsupported ${label} operation: ${value}`);
  }
}
