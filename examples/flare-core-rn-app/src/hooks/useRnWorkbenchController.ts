import { useRef, useState } from 'react';
import { MessageBuildOp, MessageContentType, type MessageBuildCatalogEntry } from '@flare-im/sdk/model';
import { createRnFlareClient } from '../application/sdk/createRnFlareClient';
import {
  createRnWorkbenchSdkService,
  defaultHomeSyncProgress,
  defaultLoginForm,
  defaultSdkLabInputs,
  type DispatchInput,
  type RnWorkbenchSdkService,
} from '../application/sdk/rnWorkbenchSdkService';
import {
  shouldShowLogin,
  shouldShowSync,
  type RnCapabilityOperation,
  type RnConnectionOperation,
  type RnConversationAction,
  type RnSessionOperation,
} from '../application/workbench/h5Parity';
import type {
  ComposerPanel,
  ConversationFilter,
  ConversationItem,
  HomeSyncProgress,
  LoginFormState,
  MediaQueryOp,
  SdkLabInputs,
  SdkStatus,
  TimelineMessage,
  UploadTask,
  WorkbenchMode,
} from '../types';

export function useRnWorkbenchController() {
  const sdkServiceRef = useRef<RnWorkbenchSdkService | null>(null);
  const [mode, setMode] = useState<WorkbenchMode>('login');
  const [sdkStatus, setSdkStatus] = useState<SdkStatus>('idle');
  const [sdkMessage, setSdkMessage] = useState('请先登录并初始化 flare-im-core native bridge');
  const [sdkDiagnostics, setSdkDiagnostics] = useState<Record<string, string>>({});
  const [loginForm, setLoginForm] = useState<LoginFormState>(defaultLoginForm);
  const [loggedIn, setLoggedIn] = useState(false);
  const [homeSyncReady, setHomeSyncReady] = useState(false);
  const [homeSyncRunning, setHomeSyncRunning] = useState(false);
  const [homeSyncProgress, setHomeSyncProgress] = useState<HomeSyncProgress>(defaultHomeSyncProgress);
  const [currentUserId, setCurrentUserId] = useState('');
  const [conversations, setConversations] = useState<ConversationItem[]>([]);
  const [activeConversationId, setActiveConversationId] = useState('');
  const [activeFilter, setActiveFilter] = useState<ConversationFilter>('all');
  const [conversationSearchOpen, setConversationSearchOpen] = useState(false);
  const [conversationSearchQuery, setConversationSearchQuery] = useState('');
  const [moreOpen, setMoreOpen] = useState(false);
  const [startChatOpen, setStartChatOpen] = useState(false);
  const [startPeerUserId, setStartPeerUserId] = useState('');
  const [messages, setMessages] = useState<TimelineMessage[]>([]);
  const [composer, setComposer] = useState('');
  const [composerPanel, setComposerPanel] = useState<ComposerPanel>(null);
  const [composerRichMode, setComposerRichMode] = useState(false);
  const [replyMessageId, setReplyMessageId] = useState('');
  const [sending, setSending] = useState(false);
  const [multiSelectMode, setMultiSelectMode] = useState(false);
  const [selectedMessageIds, setSelectedMessageIds] = useState<string[]>([]);
  const [uploadTasks, setUploadTasks] = useState<UploadTask[]>([]);
  const [messageSearchQuery, setMessageSearchQuery] = useState('');
  const [messageSearchResults, setMessageSearchResults] = useState<TimelineMessage[]>([]);
  const [messageSearchBusy, setMessageSearchBusy] = useState(false);
  const [messageSearchError, setMessageSearchError] = useState('');
  const [builderBusy, setBuilderBusy] = useState(false);
  const [builderMessage, setBuilderMessage] = useState('');
  const [mediaFileId, setMediaFileId] = useState('');
  const [mediaResult, setMediaResult] = useState('');
  const [mediaBusy, setMediaBusy] = useState(false);
  const [sdkLabInputs, setSdkLabInputs] = useState<SdkLabInputs>(defaultSdkLabInputs);
  const [sdkLabResult, setSdkLabResult] = useState('');
  const [messageBuildCatalog, setMessageBuildCatalog] = useState<MessageBuildCatalogEntry[]>([]);

  const routeGate = { loggedIn, homeSyncReady };
  const activeConversation = conversations.find((item) => item.id === activeConversationId);
  const totalUnread = conversations.reduce((sum, item) => sum + item.unreadCount, 0);
  const pinnedCount = conversations.filter((item) => item.pinned).length;
  const visibleConversations = conversations.filter((item) => {
    if (activeFilter === 'unread' && item.unreadCount <= 0) return false;
    if (activeFilter === 'mention' && !item.mentionMe) return false;
    if (activeFilter === 'pinned' && !item.pinned) return false;
    if (activeFilter === 'muted' && !item.muted) return false;
    if (activeFilter === 'archived' && !item.archived) return false;
    if (activeFilter === 'draft' && !item.draft.trim()) return false;
    const query = conversationSearchQuery.trim().toLowerCase();
    if (!query) return true;
    return item.title.toLowerCase().includes(query) || item.lastMessagePreview.toLowerCase().includes(query);
  });
  const pinnedConversations = visibleConversations.filter((item) => item.pinned);
  const restConversations = visibleConversations.filter((item) => !item.pinned);
  const latestMessage = messages[messages.length - 1];
  const pinnedMessages = messages.filter((item) => item.pinned);
  const selectedCount = selectedMessageIds.length;

  function updateLoginForm(patch: Partial<LoginFormState>) {
    setLoginForm((current) => ({ ...current, ...patch }));
  }

  function updateSdkLabInputs(patch: Partial<SdkLabInputs>) {
    setSdkLabInputs((current) => ({ ...current, ...patch }));
  }

  function reportError(error: unknown) {
    setSdkMessage(error instanceof Error ? error.message : `${error}`);
    setSdkStatus('error');
  }

  function serviceOrReport(): RnWorkbenchSdkService | null {
    const service = sdkServiceRef.current;
    if (!service) {
      setSdkMessage('请先登录并初始化 flare-im-core SDK');
      setMode('login');
      return null;
    }
    return service;
  }

  async function initializeSdk() {
    try {
      setSdkStatus('connecting');
      setSdkMessage('正在初始化 SDK 会话');
      const client = createRnFlareClient();
      const service = createRnWorkbenchSdkService(client);
      sdkServiceRef.current = service;
      const snapshot = await service.initializeAndLogin(loginForm);
      setSdkDiagnostics(snapshot.diagnostics);
      setCurrentUserId(snapshot.currentUserId);
      setMessageBuildCatalog(snapshot.messageBuildCatalog);
      setSdkStatus(statusFromConnectionPhase(snapshot.connectionStatus.phase));
      setSdkMessage(`SDK 会话已建立 · ${snapshot.connectionStatus.phase}`);
      setLoggedIn(true);
      setHomeSyncReady(false);
      setMode('sync');
      await runHomeSync(service, snapshot.currentUserId);
    } catch (error) {
      setLoggedIn(false);
      setHomeSyncReady(false);
      setSdkDiagnostics({});
      reportError(error);
    }
  }

  async function runHomeSync(service = sdkServiceRef.current, userId = currentUserId) {
    if (!service) {
      setMode('login');
      return;
    }
    setHomeSyncRunning(true);
    setHomeSyncReady(false);
    try {
      setHomeSyncProgress({
        step: 'session',
        title: '检查连接',
        detail: '确认 SDK 会话和连接状态',
        percent: 20,
      });
      setHomeSyncProgress({
        step: 'conversations',
        title: '同步会话',
        detail: '拉取首页需要展示的会话列表',
        percent: 45,
      });
      const snapshot = await service.syncHome();
      setConversations(snapshot.conversations);
      const nextActiveId = snapshot.conversations[0]?.id ?? '';
      setActiveConversationId(nextActiveId);
      setHomeSyncProgress({
        step: 'unread',
        title: '统计未读',
        detail: '读取 SDK 首页快照和未读数量',
        percent: 70,
      });
      if (nextActiveId) {
        await refreshTimeline(nextActiveId, service, userId);
      } else {
        setMessages([]);
      }
      setHomeSyncProgress({
        step: 'ready',
        title: '同步完成',
        detail: '首页已准备好',
        percent: 100,
      });
      setHomeSyncReady(true);
      setMode('conversations');
      setSdkMessage(`首页同步完成 · ${snapshot.conversations.length} 会话`);
    } catch (error) {
      setHomeSyncReady(false);
      setHomeSyncProgress({
        step: 'failed',
        title: '同步失败',
        detail: error instanceof Error ? error.message : String(error),
        percent: 100,
      });
      reportError(error);
      setMode('sync');
    } finally {
      setHomeSyncRunning(false);
    }
  }

  async function logout() {
    try {
      await sdkServiceRef.current?.logout();
    } catch {
      // Logout should still clear local RN state when the native runtime is already gone.
    }
    sdkServiceRef.current = null;
    setLoggedIn(false);
    setHomeSyncReady(false);
    setCurrentUserId('');
    setConversations([]);
    setMessages([]);
    setActiveConversationId('');
    setSdkStatus('idle');
    setSdkMessage('已退出登录');
    setMode('login');
  }

  async function reloadConversations(preferredConversationId = activeConversationId) {
    const service = serviceOrReport();
    if (!service) return [];
    const next = await service.listConversations();
    setConversations(next);
    const nextActiveId = next.some((item) => item.id === preferredConversationId)
      ? preferredConversationId
      : (next[0]?.id ?? '');
    setActiveConversationId(nextActiveId);
    if (!nextActiveId) setMessages([]);
    return next;
  }

  async function refreshTimeline(conversationId = activeConversationId, service = sdkServiceRef.current, userId = currentUserId) {
    if (!service || !conversationId) {
      setMessages([]);
      return;
    }
    const snapshot = await service.openTimeline(conversationId, userId);
    if (snapshot.conversation) {
      setConversations((items) => upsertConversation(items, snapshot.conversation!));
    }
    setMessages(snapshot.messages);
  }

  async function selectConversation(id: string) {
    setActiveConversationId(id);
    setMode('chat');
    try {
      await refreshTimeline(id);
      await sdkServiceRef.current?.markConversationRead(id);
      await reloadConversations(id);
    } catch (error) {
      reportError(error);
    }
  }

  async function createConversation() {
    const peer = startPeerUserId.trim();
    if (!peer) return;
    const service = serviceOrReport();
    if (!service) return;
    try {
      const conversation = await service.getOneConversation(peer);
      setConversations((items) => upsertConversation(items, conversation));
      setActiveConversationId(conversation.id);
      setStartChatOpen(false);
      setStartPeerUserId('');
      setMode('chat');
      await refreshTimeline(conversation.id);
      await reloadConversations(conversation.id);
    } catch (error) {
      reportError(error);
    }
  }

  async function runConversationAction(action: RnConversationAction) {
    if (!activeConversation) return;
    const service = serviceOrReport();
    if (!service) return;
    try {
      await service.runConversationOperation(action, activeConversation.id, sdkLabInputs.draft);
      if (action === 'delete') {
        const next = await reloadConversations('');
        setActiveConversationId(next[0]?.id ?? '');
        setMode('conversations');
        return;
      }
      if (action === 'clear_history') setMessages([]);
      await reloadConversations(activeConversation.id);
      if (activeConversation.id) await refreshTimeline(activeConversation.id);
    } catch (error) {
      reportError(error);
    }
  }

  async function toggleConversationFlag(flag: 'pinned' | 'muted' | 'archived') {
    if (!activeConversation) return;
    if (flag === 'pinned') await runConversationAction(activeConversation.pinned ? 'unpin' : 'pin');
    if (flag === 'muted') await runConversationAction(activeConversation.muted ? 'unmute' : 'mute');
    if (flag === 'archived') await runConversationAction(activeConversation.archived ? 'unarchive' : 'archive');
  }

  async function markActiveUnread() {
    await runConversationAction('mark_unread');
  }

  async function markActiveRead() {
    await runConversationAction('mark_read');
  }

  async function clearActiveHistory() {
    await runConversationAction('clear_history');
  }

  async function deleteActiveConversation() {
    await runConversationAction('delete');
  }

  function appendEmoji(value: string) {
    setComposer((current) => `${current}${value}`);
  }

  function sendSticker(value: string) {
    void sendLocalMessage(value, MessageContentType.Sticker);
  }

  async function sendLocalMessage(forcedText?: string, contentType: TimelineMessage['contentType'] = MessageContentType.Text) {
    const text = (forcedText ?? composer).trim();
    if (!text || !activeConversation) return;
    const service = serviceOrReport();
    if (!service) return;
    setSending(true);
    try {
      const baseOp = resolveComposerBuildOp(text, contentType, composerRichMode);
      const op = replyMessageId && baseOp === MessageBuildOp.CreateText ? MessageBuildOp.CreateQuote : baseOp;
      const replyPreview = messages.find((item) => item.id === replyMessageId)?.text ?? '';
      const params = buildComposerParams(op, text, replyMessageId, replyPreview);
      const ack = await service.buildAndSend(op, activeConversation.id, params);
      if (!ack.success) throw new Error(ack.errorMessage || 'message.send failed');
      setComposer('');
      setComposerPanel(null);
      setReplyMessageId('');
      await refreshTimeline(activeConversation.id);
      await reloadConversations(activeConversation.id);
      setSdkStatus('ready');
    } catch (error) {
      reportError(error);
    } finally {
      setSending(false);
    }
  }

  function toggleMessageSelection(id: string) {
    setSelectedMessageIds((current) =>
      current.includes(id) ? current.filter((item) => item !== id) : [...current, id],
    );
  }

  function enterMultiSelect(id: string) {
    setMultiSelectMode(true);
    setSelectedMessageIds([id]);
  }

  function exitMultiSelect() {
    setMultiSelectMode(false);
    setSelectedMessageIds([]);
  }

  function retryMessage(id: string) {
    const message = messages.find((item) => item.id === id);
    if (!message) return;
    void sendLocalMessage(message.text, message.contentType);
  }

  async function reactMessage(id: string, emoji: string) {
    const service = serviceOrReport();
    if (!service || !activeConversation) return;
    const currentMessage = messages.find((item) => item.id === id);
    const removing = currentMessage?.reactions.includes(emoji) ?? false;
    try {
      if (removing) await service.removeReaction(id, emoji);
      else await service.addReaction(id, emoji);
      await refreshTimeline(activeConversation.id);
    } catch (error) {
      reportError(error);
    }
  }

  function removeUploadTask(id: string) {
    setUploadTasks((current) => current.filter((task) => task.id !== id));
  }

  async function runMessageSearch() {
    const keyword = messageSearchQuery.trim();
    const service = sdkServiceRef.current;
    if (!keyword || !service) {
      setMessageSearchResults([]);
      return;
    }
    setMessageSearchBusy(true);
    setMessageSearchError('');
    try {
      const results = await service.searchMessages(keyword, currentUserId, activeConversationId);
      setMessageSearchResults(results);
    } catch (error) {
      setMessageSearchError(error instanceof Error ? error.message : String(error));
      setMessageSearchResults([]);
    } finally {
      setMessageSearchBusy(false);
    }
  }

  async function runBuilderOp(op: MessageBuildOp | string = sdkLabInputs.buildOp) {
    const service = sdkServiceRef.current;
    const conversationId = activeConversationId;
    if (!service || !conversationId) {
      setBuilderMessage('请先登录 SDK 并选择会话');
      return;
    }
    setBuilderBusy(true);
    setBuilderMessage('');
    try {
      await service.buildAndSend(op, conversationId, parseJsonParams(sdkLabInputs.jsonParams, {
        text: sdkLabInputs.messageText,
        emoji: sdkLabInputs.messageText || sdkLabInputs.reaction,
      }));
      setBuilderMessage(`已构建并发送: ${op}`);
      await refreshTimeline(conversationId);
    } catch (error) {
      setBuilderMessage(error instanceof Error ? error.message : String(error));
    } finally {
      setBuilderBusy(false);
    }
  }

  async function runMessageDispatch(op = sdkLabInputs.dispatchOp) {
    const service = sdkServiceRef.current;
    if (!service) {
      setSdkLabResult('请先登录 SDK');
      return;
    }
    try {
      const result = await service.dispatchMessage(op, dispatchInput());
      setSdkLabResult(JSON.stringify(result, null, 2));
      await refreshTimeline(activeConversationId);
    } catch (error) {
      setSdkLabResult(error instanceof Error ? error.message : String(error));
    }
  }

  async function runMediaQuery(op: MediaQueryOp) {
    const service = sdkServiceRef.current;
    if (!service) {
      setMediaResult('请先登录 SDK');
      return;
    }
    setMediaBusy(true);
    setMediaResult('');
    try {
      const result = await service.runMediaQuery(op, { ...sdkLabInputs, fileId: mediaFileId.trim() || sdkLabInputs.fileId });
      setMediaResult(result || '(空)');
      setSdkLabResult(result || '(空)');
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      setMediaResult(detail);
      setSdkLabResult(detail);
    } finally {
      setMediaBusy(false);
    }
  }

  async function runCapabilityOperation(op: RnCapabilityOperation = 'list') {
    const service = sdkServiceRef.current;
    if (!service) return;
    try {
      const result = await service.runCapabilityOperation(op, sdkLabInputs);
      setSdkLabResult(result);
    } catch (error) {
      setSdkLabResult(error instanceof Error ? error.message : String(error));
    }
  }

  async function runConnectionOperation(op: RnConnectionOperation = 'status') {
    const service = sdkServiceRef.current;
    if (!service) return;
    try {
      const result = await service.runConnectionOperation(op);
      setSdkLabResult(result);
    } catch (error) {
      setSdkLabResult(error instanceof Error ? error.message : String(error));
    }
  }

  async function runSessionOperation(op: RnSessionOperation = 'runtime_health') {
    const service = sdkServiceRef.current;
    if (!service) return;
    try {
      const result = await service.runSessionOperation(op, sdkLabInputs, loginForm);
      setSdkLabResult(result);
    } catch (error) {
      setSdkLabResult(error instanceof Error ? error.message : String(error));
    }
  }

  async function runEventOperation() {
    const service = sdkServiceRef.current;
    if (!service) return;
    try {
      const result = await service.subscribeWorkbenchEvents();
      setSdkLabResult(result);
    } catch (error) {
      setSdkLabResult(error instanceof Error ? error.message : String(error));
    }
  }

  function dispatchInput(): DispatchInput {
    return {
      conversationId: activeConversationId,
      messageId: sdkLabInputs.messageId || latestMessage?.id || '',
      keyword: sdkLabInputs.query || messageSearchQuery,
      text: sdkLabInputs.messageText,
      emoji: sdkLabInputs.reaction,
      jsonParams: parseJsonParams(sdkLabInputs.jsonParams),
    };
  }

  return {
    mode: shouldShowLogin(routeGate) ? 'login' as WorkbenchMode : shouldShowSync(routeGate) && mode !== 'login' ? 'sync' as WorkbenchMode : mode,
    setMode,
    sdkStatus,
    sdkMessage,
    sdkDiagnostics,
    loginForm,
    updateLoginForm,
    loggedIn,
    homeSyncReady,
    homeSyncRunning,
    homeSyncProgress,
    currentUserId,
    conversations,
    activeConversation,
    activeConversationId,
    activeFilter,
    conversationSearchOpen,
    conversationSearchQuery,
    moreOpen,
    startChatOpen,
    startPeerUserId,
    messages,
    composer,
    composerPanel,
    composerRichMode,
    replyMessageId,
    sending,
    multiSelectMode,
    selectedMessageIds,
    uploadTasks,
    messageSearchQuery,
    setMessageSearchQuery,
    messageSearchResults,
    messageSearchBusy,
    messageSearchError,
    runMessageSearch,
    builderBusy,
    builderMessage,
    runBuilderOp,
    runMessageDispatch,
    mediaFileId,
    setMediaFileId,
    mediaResult,
    mediaBusy,
    runMediaQuery,
    sdkLabInputs,
    updateSdkLabInputs,
    sdkLabResult,
    messageBuildCatalog,
    totalUnread,
    pinnedCount,
    visibleConversations,
    pinnedConversations,
    restConversations,
    latestMessage,
    pinnedMessages,
    selectedCount,
    initializeSdk,
    runHomeSync,
    logout,
    selectConversation,
    createConversation,
    runConversationAction,
    toggleConversationFlag,
    markActiveUnread,
    markActiveRead,
    clearActiveHistory,
    deleteActiveConversation,
    appendEmoji,
    sendSticker,
    sendLocalMessage,
    toggleMessageSelection,
    enterMultiSelect,
    exitMultiSelect,
    retryMessage,
    reactMessage,
    removeUploadTask,
    runCapabilityOperation,
    runConnectionOperation,
    runSessionOperation,
    runEventOperation,
    setActiveFilter,
    setConversationSearchOpen,
    setConversationSearchQuery,
    setMoreOpen,
    setStartChatOpen,
    setStartPeerUserId,
    setComposer,
    setComposerPanel,
    setComposerRichMode,
    setReplyMessageId,
  };
}

function upsertConversation(items: ConversationItem[], conversation: ConversationItem): ConversationItem[] {
  const existing = items.findIndex((item) => item.id === conversation.id);
  if (existing < 0) return [conversation, ...items];
  return items.map((item) => (item.id === conversation.id ? conversation : item));
}

/** The workbench's coarse status from the core's connection phase (`connection://status`). */
function statusFromConnectionPhase(phase: string): SdkStatus {
  if (phase === 'online') return 'ready';
  if (phase === 'idle') return 'idle';
  if (phase === 'actionRequired') return 'disconnected';
  return 'connecting';
}

function resolveComposerBuildOp(text: string, contentType: TimelineMessage['contentType'], richMode: boolean): MessageBuildOp {
  if (contentType === MessageContentType.Sticker) return MessageBuildOp.CreateSticker;
  if (contentType === MessageContentType.Emoji) return MessageBuildOp.CreateEmoji;
  if (richMode || looksLikeRichMarkdown(text)) return MessageBuildOp.CreateRichDoc;
  const command = text.match(/^\/([a-z_]+)\b/i)?.[1]?.toLowerCase();
  switch (command) {
    case 'image':
      return MessageBuildOp.CreateImage;
    case 'video':
      return MessageBuildOp.CreateVideo;
    case 'voice':
    case 'audio':
      return MessageBuildOp.CreateAudio;
    case 'file':
      return MessageBuildOp.CreateFile;
    case 'location':
      return MessageBuildOp.CreateLocation;
    case 'card':
      return MessageBuildOp.CreateCard;
    case 'task':
      return MessageBuildOp.CreateTask;
    case 'schedule':
      return MessageBuildOp.CreateSchedule;
    case 'poll':
    case 'vote':
      return MessageBuildOp.CreateVote;
    case 'link':
      return MessageBuildOp.CreateLinkCard;
    case 'miniapp':
      return MessageBuildOp.CreateMiniProgram;
    case 'notice':
      return MessageBuildOp.CreateNotification;
    case 'announcement':
      return MessageBuildOp.CreateAnnouncement;
    case 'topic':
      return MessageBuildOp.CreateCustom;
    default:
      return loneEmoji(text) ? MessageBuildOp.CreateEmoji : MessageBuildOp.CreateText;
  }
}

function buildComposerParams(op: MessageBuildOp, text: string, replyMessageId: string, replyPreview = ''): Record<string, unknown> {
  const withoutCommand = text.replace(/^\/[a-z_]+\s*/i, '').trim();
  const body = withoutCommand || text;
  if (replyMessageId && op === MessageBuildOp.CreateQuote) {
    return {
      text: body,
      quotedMessageId: replyMessageId,
      quotedTextPreview: replyPreview || body,
      quotedContent: { contentType: MessageContentType.Text, data: { text: body, mentions: [] } },
    };
  }
  if (op === MessageBuildOp.CreateSticker) return { stickerId: body, packageId: 'rn' };
  if (op === MessageBuildOp.CreateEmoji) return { emoji: body };
  if (op === MessageBuildOp.CreateRichDoc) return { title: richTitle(body), markdown: body, text: body };
  if (op === MessageBuildOp.CreateImage) return { imageId: body, sourcePath: body, payload: { alt: body } };
  if (op === MessageBuildOp.CreateVideo) return { videoId: body, sourcePath: body, payload: { title: body } };
  if (op === MessageBuildOp.CreateAudio) return { audioId: body, sourcePath: body, payload: { title: body } };
  if (op === MessageBuildOp.CreateFile) return { fileId: body, sourcePath: body, payload: { name: body } };
  return { text: body, title: body, body, description: body };
}

function parseJsonParams(source: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  const raw = source.trim();
  if (!raw) return extra;
  try {
    const value = JSON.parse(raw);
    return value && typeof value === 'object' && !Array.isArray(value) ? { ...extra, ...value as Record<string, unknown> } : extra;
  } catch {
    return extra;
  }
}

function looksLikeRichMarkdown(value: string): boolean {
  return [
    /^\s{0,3}(#{1,6}|>|[-*+]|\d+\.)\s+\S/m,
    /(\*\*|__)[^\n]+(\*\*|__)/,
    /`[^`\n]+`/,
    /\[[^\]]+]\((https?:\/\/|mailto:)[^)]+\)/,
    /!\[[^\]]*]\((https?:\/\/|file:|data:)[^)]+\)/,
  ].some((pattern) => pattern.test(value));
}

function loneEmoji(value: string): boolean {
  const normalized = value.trim();
  return normalized.length > 0 && normalized.length <= 8 && /[\p{Emoji_Presentation}\p{Extended_Pictographic}]/u.test(normalized);
}

function richTitle(markdown: string): string {
  return markdown
    .replace(/^#+\s*/, '')
    .replace(/[*_`>#-]/g, '')
    .trim()
    .slice(0, 48) || 'RN 富文本';
}
