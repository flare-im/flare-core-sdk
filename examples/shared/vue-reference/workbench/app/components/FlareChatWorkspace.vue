<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { describeSdkError } from "../../shared/errors/describeSdkError";
import {
  ChatbubbleEllipsesOutline,
  PinOutline,
} from "@flare-im/vue-ui/icon-glyphs";
import { useToast } from "../ui/toast";
import { onBeforeRouteLeave, useRouter } from "vue-router";
import { MessageContentType, type Message, type MessageContent } from "@flare-im/sdk/web";
import {
  FlareChatWorkspace as ChatWorkspace,
  FlareConversationHeader,
  FlareComposer as EnhancedComposer,
  FlareEmojiStickerPicker as ComposerEmojiStickerPanel,
  FlareMessageBatchToolbar as MessageBatchToolbar,
  FlareMessageList as MessageList,
  FlarePinnedMessageBar as PinnedMessageBar,
  FlareFilterTabs,
  FlareStatusBanner,
  FlareEmptyState,
  type FlareIconName,
} from "@flare-im/vue-ui/components";
import {
  formatEmojiPackToken,
  isMarkdown,
  listMessageMediaDownloadSources,
  markdownToPlainText,
  proxiedMediaUrl,
  resolveLoneEmojiPackKey,
  type MessageMediaDownloadSource,
} from "@flare-im/vue-ui/utils";
import type { MessageMenuConfig } from "@flare-im/vue-ui/utils";
import { useFlarePlatform } from "@flare-im/vue-ui/composables";
import { callPlatform } from "@flare-im/vue-ui/contracts";
import type {
  FlareConversationHeaderAction,
  MessageBatchAction,
  MessageBatchCapabilities,
  MessageLike,
} from "@flare-im/vue-ui/contracts";
import { useFlareWorkbenchUi } from "../../composables/useFlareWorkbenchUi";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { useFlareUpdates } from "../state/update";
import { getMessageText } from "@flare-im/vue-ui/utils";
import { conversationTitle, resolveConversationPeer } from "../shared/conversationTitle";
import { useFlareI18n } from "../shared/i18n";
import ComposerPayloadModal from "../message-enhancements/components/ComposerPayloadModal.vue";
import ForwardModal from "../message-enhancements/components/ForwardModal.vue";
import { FlareComposerMediaPreview as MediaComposerPreviewModal } from "@flare-im/vue-ui/components";
import { DraftIdleScheduler } from "../shared/draftIdleScheduler";
import { locateTimelineMessage } from "../shared/locateTimelineMessage";
import { createMessageOperationAdapter } from "../message-enhancements/messageOperations";
import { composerActions, resolveComposerAction, resolveMessageMenuActions, type ComposerActionDefinition } from "../message-enhancements/messageTypeRegistry";
import { createComposerAttachActions } from "../message-enhancements/composerActionPresentation";
import { useMessageInteractionState } from "../message-enhancements/useMessageInteractionState";
import type { BatchOperationResult, ComposerPayloadRequest, EnhancedMessageKind, ForwardMode, MediaComposerPreviewItem, MessageOperationSdk, MessagePinScope } from "../message-enhancements/types";
import { resolveAppMediaLocalPath } from "../infrastructure/media/appMediaResolver";
import {
  canRevealDownloadedMedia,
  revealDownloadedMediaFile,
  startBrowserDownload,
} from "../infrastructure/media/downloadedMediaActions";

type MessageIdentity = Pick<Message, "serverId" | "clientMsgId" | "senderId" | "messageType" | "content">;
type MediaDownloadAction = "download" | "openFolder";
type MediaDownloadState = "notDownloaded" | "downloading" | "downloaded";
type MessageMediaDownloadUiState = "idle" | "downloading" | "downloaded" | "openFolder";
type VoiceRecordingPayload = {
  blob: Blob;
  durationMs: number;
  mimeType: string;
  fileName: string;
};
type ComposerMediaSource = {
  sourcePath: string;
  sourceUrl?: string;
  fileName: string;
  mimeType: string;
  fileSize: number;
};
type ComposerMentionCandidate = {
  userId: string;
  label?: string;
  avatarUrl?: string;
};
const DRAFT_IDLE_DELAY_MS = 5_000;
const DRAFT_CLEAR_DELAY_MS = 1_200;
const PEER_PRESENCE_REFRESH_DELAY_MS = 5_000;
const MESSAGE_LOCATE_MAX_OLDER_LOADS = 48;

const workbenchUi = useFlareWorkbenchUi();
const sdk = useFlareSdk();
const router = useRouter();
const message = useToast();
const platform = useFlarePlatform();
const { t } = useFlareI18n();

const composerAttachActions = computed(() => createComposerAttachActions(composerActions, t));

const composerText = ref("");
const replyMessageId = ref("");
const editingMessageId = ref("");
const composerPanel = ref<"emoji" | "sticker" | "more" | null>(null);
const composerRichMode = ref(false);
const chatContentTab = ref<"messages" | "pin">("messages");
const sending = ref(false);
const composerStackRef = ref<HTMLElement | null>(null);
const composerRef = ref<{
  insertAtCursor?: (text: string) => void;
  focus?: () => void;
  resetInput?: (value?: string) => void;
} | null>(null);
const composerSurfaceKey = ref(0);
const messageListRef = ref<InstanceType<typeof MessageList> | null>(null);
const mediaDownloadStates = ref<Record<string, MediaDownloadState>>({});
const mediaDownloadRefreshInFlight = ref(false);
const handledVoicePayloads = new WeakSet<VoiceRecordingPayload>();

let typingTimer: number | undefined;
let scrollBottomFrame: number | undefined;
let scrollBottomTimer: number | undefined;
let peerPresenceRefreshTimer: number | undefined;
let composerVoiceDomTarget: HTMLElement | null = null;
let skipNextComposerTextWatch = false;
let composerUserEditVersion = 0;
const draftClearTimers = new Map<string, number>();

const draftScheduler = new DraftIdleScheduler(DRAFT_IDLE_DELAY_MS, (conversationId, draft) =>
  sdk.clearConversationDraft(conversationId, draft),
);

const mediaPanelOpen = computed(() => composerPanel.value === "emoji" || composerPanel.value === "sticker");
const composerMediaTab = computed<"emoji" | "sticker">(() =>
  composerPanel.value === "sticker" ? "sticker" : "emoji",
);
const canSendText = computed(() =>
  composerText.value.trim().length > 0
  && !sending.value
  && Boolean(sdk.activeConversationId.value),
);
const peerPresenceStatus = ref<"online" | "offline" | "busy">("offline");
// Receive-side typing text for the active conversation. Presence + TTL are computed in the
// core (TypingAggregate); here we only turn "someone is typing" into the localized label.
const activeTypingText = computed(() =>
  sdk.activeConversationTypingUsers.value.length > 0 ? t("chat.typing") : "",
);
const messageInteractionSource = computed(() => sdk.messages.value as unknown as readonly Message[]);
const timelineMessages = computed<readonly MessageLike[]>(() => sdk.messages.value.map((row) => ({
  ...row,
  status: row.localState?.failed
    ? "failed"
    : row.localState?.sending
      ? "sending"
      : row.isRead
        ? "read"
        : "sent",
}) as unknown as MessageLike));
const forwardConversationSource = computed(() => sdk.conversations.value as unknown as readonly import("@flare-im/sdk/web").Conversation[]);
const interactions = useMessageInteractionState(messageInteractionSource);
const operations = createMessageOperationAdapter(sdk as unknown as MessageOperationSdk);
const multiSelectMode = interactions.multiSelectMode;
const selectedMessageIds = interactions.selectedMessageIds;
const selectedMessages = interactions.selectedMessages;
const selectableMessageIds = interactions.selectableMessageIds;
const allSelected = interactions.allSelected;
const forwardOpen = interactions.forwardOpen;
const forwardMode = interactions.forwardMode;
const composerActionOpen = interactions.composerActionOpen;
const activeComposerOp = interactions.activeComposerOp;
const operationBusy = computed(() => sending.value || operations.busyKeys.value.size > 0);
const batchCapabilities: MessageBatchCapabilities = {
  forwardEach: true,
  forwardMerged: true,
  pin: true,
  pinSelf: true,
  delete: true,
};
const activeMediaAction = ref<ComposerActionDefinition | null>(null);
const mediaPreviewOpen = ref(false);
const mediaPreviewItems = ref<MediaComposerPreviewItem[]>([]);
const activePayloadAction = computed(() => resolveComposerAction(activeComposerOp.value));
const payloadComposerOpen = computed({
  get: () => Boolean(composerActionOpen.value && activePayloadAction.value && !activePayloadAction.value.acceptsFiles),
  set: (open: boolean) => {
    composerActionOpen.value = open;
    if (!open) activeComposerOp.value = "";
  },
});
const messageMenuConfig = computed<MessageMenuConfig>(() => ({
  resolveVisible: ({ message: row }) =>
    resolveMessageMenuActions(row as unknown as Message, {
      currentUserId: sdk.currentUserId.value || sdk.form.userId,
      connected: isConnected.value,
      multiSelectMode: multiSelectMode.value,
    }),
  resolveMediaAction: ({ message: row, hasDownloadableMedia }) => {
    if (!hasDownloadableMedia) return null;
    const first = firstMediaDownloadSource(row);
    if (!first) return null;
    const state = mediaDownloadStates.value[first.downloadKey];
    if (state === "downloading") return null;
    if (state === "downloaded") {
      return canRevealDownloadedMedia() ? "openMediaFolder" : "downloadMedia";
    }
    return "downloadMedia";
  },
}));

const messageMediaDownloadUiStates = computed<Record<string, MessageMediaDownloadUiState>>(() => {
  const states: Record<string, MessageMediaDownloadUiState> = {};
  const canOpenFolder = canRevealDownloadedMedia();
  for (const row of sdk.messages.value) {
    const messageRow = row as unknown as Message;
    const source = firstMediaDownloadSource(messageRow);
    if (!source) continue;
    const state = mediaDownloadStates.value[source.downloadKey];
    if (state === "downloading") {
      states[mediaMessageId(messageRow)] = "downloading";
    } else if (state === "downloaded" && canOpenFolder) {
      states[mediaMessageId(messageRow)] = "openFolder";
    }
  }
  return states;
});

const isConnected = computed(() => sdk.connectionPhase.value === "online");

const activeTitle = computed(() =>
  conversationTitle(sdk.activeConversation.value, sdk.currentUserId.value || sdk.form.userId) || t("nav.chat"),
);
const activeSubtitle = computed(() => {
  const item = sdk.activeConversation.value;
  if (!item) return "";
  if (item.conversationType === "group") {
    return t("chat.members", { count: item.membersCount ?? 0 });
  }
  if (item.conversationType === "ai") return t("chat.aiAssistant");
  if (peerPresenceStatus.value === "online") return t("chat.online");
  if (peerPresenceStatus.value === "busy") return t("chat.busy");
  return t("chat.offline");
});

const composerDisabled = computed(() => !sdk.activeConversationId.value);
const pinnedCount = computed(() => sdk.pinnedMessages.value.length);
const showContentTabs = computed(() =>
  !multiSelectMode.value && Boolean(sdk.activeConversationId.value) && pinnedCount.value > 0,
);
const showingPinnedTab = computed(() => chatContentTab.value === "pin" && pinnedCount.value > 0);
const chatEmptyState = computed(() => {
  const conversation = sdk.activeConversation.value;
  const hasHistoryHint = Boolean(
    Boolean(conversation?.lastMessageId)
    || Boolean(conversation?.lastMessagePreview)
    || Boolean(conversation?.lastMessage?.messageId)
    || Number(conversation?.maxSeq ?? 0) > 0,
  );
  if (sdk.messageOpening.value || sdk.messageSyncing.value) {
    return {
      title: t("chat.emptySyncing"),
      detail: t("chat.emptySyncingHint"),
      loading: true,
      error: false,
    };
  }
  if (sdk.messageSyncError.value) {
    return {
      title: t("chat.emptySyncFailed"),
      detail: sdk.messageSyncError.value,
      loading: false,
      error: true,
    };
  }
  if (hasHistoryHint) {
    return {
      title: t("chat.emptyHistoryUnavailable"),
      detail: t("chat.emptyHistoryUnavailableHint"),
      loading: false,
      error: true,
    };
  }
  return {
    title: t("chat.emptyTitle"),
    detail: t("chat.emptyHint"),
    loading: false,
    error: false,
  };
});

function resolvePeerUserId(): string {
  const item = sdk.activeConversation.value;
  if (!item || item.conversationType !== "single") return "";
  const peer = resolveConversationPeer(item, sdk.currentUserId.value || sdk.form.userId);
  return peer?.userId?.trim() || item.channelId?.trim() || "";
}

const composerMentionCandidates = computed<ComposerMentionCandidate[]>(() => {
  const item = sdk.activeConversation.value;
  if (!item) return [];
  const currentUserId = (sdk.currentUserId.value || sdk.form.userId).trim();
  const candidates = new Map<string, ComposerMentionCandidate>();
  const add = (userId?: string, label?: string): void => {
    const id = userId?.trim();
    if (!id || id === currentUserId || candidates.has(id)) return;
    const display = label?.trim() || id;
    candidates.set(id, { userId: id, label: display });
  };

  for (const participant of item.participants ?? []) add(participant.userId, participant.nickname);
  for (const participant of item.memberPreview ?? []) add(participant.userId, participant.nickname);
  if (item.conversationType === "single") add(resolvePeerUserId(), activeTitle.value);

  const channel = item.channelId?.trim() ?? "";
  if (channel.startsWith("users:")) {
    for (const userId of channel.slice("users:".length).split(/[,\s，、;；|]+/)) add(userId, userId);
  }

  return [...candidates.values()].slice(0, 64);
});

function mapPresenceStatus(raw: string): "online" | "offline" | "busy" {
  const normalized = raw.toLowerCase();
  if (normalized.includes("busy") || normalized.includes("dnd")) return "busy";
  if (normalized.includes("online")) return "online";
  return "offline";
}

const updates = useFlareUpdates();
const composerPlaceholder = computed(() => (
  updates.readOnly.value ? t("composer.readOnlyUpdate") : t("chat.composerPlaceholder", { name: activeTitle.value })
));
// A forced web update only reloads a page with nothing in the composer.
watch(composerText, (text) => {
  updates.composerHasText.value = text.trim().length > 0;
});

const replyMessage = computed(() => findMessage(replyMessageId.value));
const editingMessage = computed(() => findMessage(editingMessageId.value));
const editingPreview = computed(() => (editingMessage.value ? getMessageText(editingMessage.value) : ""));

function clearScrollBottomRetry(): void {
  if (scrollBottomFrame !== undefined) {
    window.cancelAnimationFrame(scrollBottomFrame);
    scrollBottomFrame = undefined;
  }
  if (scrollBottomTimer !== undefined) {
    window.clearTimeout(scrollBottomTimer);
    scrollBottomTimer = undefined;
  }
}

async function scrollChatToBottomAfterRender(): Promise<void> {
  await nextTick();
  await messageListRef.value?.scrollToBottom();
  if (typeof window !== "undefined") {
    clearScrollBottomRetry();
    scrollBottomFrame = window.requestAnimationFrame(() => {
      scrollBottomFrame = undefined;
      void messageListRef.value?.scrollToBottom();
    });
    scrollBottomTimer = window.setTimeout(() => {
      scrollBottomTimer = undefined;
      void messageListRef.value?.scrollToBottom();
    }, 320);
  }
}

function handleTimelineAtBottomChange(atBottom: boolean): void {
  sdk.setActiveTimelineAtBottom(atBottom);
}

function clearPeerPresenceRefreshTimer(): void {
  if (peerPresenceRefreshTimer === undefined) return;
  window.clearTimeout(peerPresenceRefreshTimer);
  peerPresenceRefreshTimer = undefined;
}

function schedulePeerPresenceRefresh(conversationId: string, peerUserId: string): void {
  clearPeerPresenceRefreshTimer();
  peerPresenceRefreshTimer = window.setTimeout(() => {
    peerPresenceRefreshTimer = undefined;
    if (sdk.activeConversationId.value !== conversationId) return;
    void sdk.refreshActivePeerPresence(peerUserId).then((status) => {
      if (sdk.activeConversationId.value === conversationId) {
        peerPresenceStatus.value = mapPresenceStatus(status);
      }
    });
  }, PEER_PRESENCE_REFRESH_DELAY_MS);
}

watch(
  () => sdk.activeConversationId.value,
  async (conversationId, previousConversationId) => {
    clearPeerPresenceRefreshTimer();
    if (previousConversationId) {
      await flushComposerDraftNow(previousConversationId, editingMessageId.value ? "" : composerText.value);
    } else {
      draftScheduler.cancel();
    }
    if (!conversationId) {
      setComposerTextSilently("");
      replyMessageId.value = "";
      editingMessageId.value = "";
      composerPanel.value = null;
      peerPresenceStatus.value = "offline";
      chatContentTab.value = "messages";
      exitMultiSelect();
      return;
    }
    const draft =
      sdk.conversations.value.find((item) => item.conversationId === conversationId)?.draft ?? "";
    setComposerTextSilently(draft);
    replyMessageId.value = "";
    editingMessageId.value = "";
    composerPanel.value = null;
    chatContentTab.value = "messages";
    exitMultiSelect();
    const peerUserId = resolvePeerUserId();
    if (peerUserId) {
      peerPresenceStatus.value = mapPresenceStatus(sdk.peerPresence.value[peerUserId] ?? "offline");
    } else {
      peerPresenceStatus.value = "offline";
    }
    await sdk.enterActiveConversation("chat_enter");
    await scrollChatToBottomAfterRender();
    if (peerUserId) {
      schedulePeerPresenceRefresh(conversationId, peerUserId);
    }
  },
  { immediate: true },
);

watch(pinnedCount, (count) => {
  if (count === 0 && chatContentTab.value === "pin") {
    chatContentTab.value = "messages";
  }
});

watch(
  () =>
    sdk.messages.value
      .map((row) => [
        row.timelineKey,
        row.serverId,
        row.clientMsgId,
        row.content?.contentType,
      ].join(":"))
      .join("|"),
  () => {
    void refreshVisibleMediaDownloadStates();
  },
  { flush: "post" },
);

watch(
  () => sdk.peerPresence.value,
  (presence) => {
    const peerUserId = resolvePeerUserId();
    if (!peerUserId) return;
    const status = presence[peerUserId];
    if (status) {
      peerPresenceStatus.value = mapPresenceStatus(status);
    }
  },
  { deep: true },
);

watch(composerText, (draft) => {
  if (skipNextComposerTextWatch) {
    skipNextComposerTextWatch = false;
    return;
  }
  composerUserEditVersion += 1;
  if (editingMessageId.value) return;
  scheduleComposerDraft(draft);
  if (!isConnected.value) return;
  if (typingTimer !== undefined) {
    window.clearTimeout(typingTimer);
    typingTimer = undefined;
  }
  void sdk.sendTyping(true);
  typingTimer = window.setTimeout(() => {
    typingTimer = undefined;
    void sdk.sendTyping(false);
  }, 1200);
});

function findMessage(id: string) {
  if (!id) return null;
  return sdk.messages.value.find((m) => m.serverId === id || m.clientMsgId === id) ?? null;
}

let locationGeneration = 0;
function cancelMessageLocation() { locationGeneration += 1; }
watch([sdk.activeConversationId, sdk.currentUserId], cancelMessageLocation, { flush: 'sync' });
onBeforeUnmount(cancelMessageLocation);
onBeforeRouteLeave(cancelMessageLocation);

async function locateMessage(messageId: string): Promise<void> {
  const targetId = messageId.trim();
  const conversationId = sdk.activeConversationId.value;
  if (!targetId || !conversationId) return;
  const own = ++locationGeneration;
  const isCurrent = () => own === locationGeneration && conversationId === sdk.activeConversationId.value;
  chatContentTab.value = "messages";
  try {
    const result = await locateTimelineMessage({
      isCurrent,
      scroll: async () => {
        await nextTick();
        if (!isCurrent()) return false;
        return (await messageListRef.value?.scrollToMessage(targetId, true)) ?? false;
      },
      hasOlder: () => sdk.messageHasMore.value,
      loadOlder: () => sdk.loadOlderMessages(),
      maxLoads: MESSAGE_LOCATE_MAX_OLDER_LOADS,
    });
    if (result === 'missing' && isCurrent()) message.warning(t("chat.messageLocateFailed"));
  } catch (error) {
    if (isCurrent()) message.error(describeSdkError(error) || t("toast.loadHistoryFailed"));
  }
}

watch(() => workbenchUi.messageLocation?.value, (target) => {
  if (!target || target.conversationId !== sdk.activeConversationId.value) return;
  if (workbenchUi.messageLocation) workbenchUi.messageLocation.value = null;
  void locateMessage(target.messageId);
}, { immediate: true, flush: 'post' });

function messageId(message: MessageIdentity): string {
  return message.serverId || message.clientMsgId;
}

function quotedMessageContent(message: MessageIdentity): MessageContent {
  if (message.content) {
    return {
      contentType: message.content.contentType,
      data: message.content.data,
    };
  }
  return {
    contentType: MessageContentType.Text,
    data: {
      text: getMessageText(message),
      mentions: [],
    },
  };
}

function back(): void {
  if (multiSelectMode.value) {
    exitMultiSelect();
    return;
  }
  void router.push({ name: "conversations" });
}

function setComposerTextSilently(value: string): void {
  if (composerText.value === value) {
    composerRef.value?.resetInput?.(value);
    if (!value) composerSurfaceKey.value += 1;
    return;
  }
  skipNextComposerTextWatch = true;
  composerText.value = value;
  composerRef.value?.resetInput?.(value);
  if (!value) composerSurfaceKey.value += 1;
}

function cancelPendingDraftClear(conversationId: string): void {
  const timer = draftClearTimers.get(conversationId);
  if (timer === undefined) return;
  window.clearTimeout(timer);
  draftClearTimers.delete(conversationId);
}

function cancelAllPendingDraftClears(): void {
  for (const timer of draftClearTimers.values()) {
    window.clearTimeout(timer);
  }
  draftClearTimers.clear();
}

function scheduleComposerDraft(draft: string): void {
  const conversationId = sdk.activeConversationId.value;
  if (conversationId && draft.trim()) {
    cancelPendingDraftClear(conversationId);
  }
  draftScheduler.schedule({
    conversationId,
    draft,
  });
}

async function flushComposerDraftNow(
  conversationId = sdk.activeConversationId.value,
  draft = composerText.value,
): Promise<void> {
  if (conversationId && draft.trim()) {
    cancelPendingDraftClear(conversationId);
  }
  await draftScheduler.flush({ conversationId, draft });
}

function clearComposerDraft(conversationId = sdk.activeConversationId.value, immediate = false): Promise<void> | void {
  draftScheduler.cancel();
  if (!conversationId) return;
  cancelPendingDraftClear(conversationId);
  if (immediate) {
    return sdk.clearConversationDraft(conversationId, "");
  }
  const timer = window.setTimeout(() => {
    draftClearTimers.delete(conversationId);
    void sdk.clearConversationDraft(conversationId, "");
  }, DRAFT_CLEAR_DELAY_MS);
  draftClearTimers.set(conversationId, timer);
}

function prepareComposerSend(): void {
  draftScheduler.cancel();
  const conversationId = sdk.activeConversationId.value;
  if (conversationId) cancelPendingDraftClear(conversationId);
}

async function withComposerSendDeadline<T>(task: Promise<T>): Promise<T> {
  // 不再对发送施加独立的超时死线：发送的权威终态归核心 reliable_queue（10s 单次 ack
  // 超时 + 3 次幂等重试 + 落库对账，窗口 ~40s；成功 SendAck / 失败 SendFailed 由核心直接
  // 更新消息 store，气泡经视图 delta 呈现、失败带重发入口）。这里曾有一条 35s 死线，比核心
  // 窗口短，会把 SendAck 下行帧偶发丢/迟、其实已投递的消息提前误报失败。改为透传。
  return await task;
}

function titleFromRichMarkdown(markdown: string): string {
  const firstLine = markdownToPlainText(markdown)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean) ?? "";
  return (firstLine || t("composeType.richText.label")).slice(0, 48);
}

function buildRichTextPayload(markdown: string): ComposerPayloadRequest {
  const action = resolveComposerAction("create_rich_doc");
  if (!action) throw new Error(t("toast.richBuilderUnavailable"));
  return action.buildRequest({
    markdown,
    title: titleFromRichMarkdown(markdown),
  });
}

function textLooksLikeRichMarkdown(text: string): boolean {
  return isMarkdown(text);
}

async function sendText(submittedText?: string): Promise<void> {
  const text = (submittedText ?? composerText.value).trim();
  if (!text) {
    message.warning(t("toast.enterContent"));
    return;
  }
  if (!sdk.activeConversationId.value) {
    message.warning(t("error.selectConversationFirst"));
    return;
  }
  if (sending.value) return;

  prepareComposerSend();
  sending.value = true;
  let sendAcknowledged = false;
  const composerVersionAtSubmit = composerUserEditVersion;
  try {
    setComposerTextSilently("");
    await clearComposerDraft(undefined, true);
    let task: Promise<void>;
    if (editingMessageId.value) {
      task = sdk.editMessageText(editingMessageId.value, text);
    } else if (replyMessage.value) {
      task = sdk.buildAndSendMessage("create_quote", {
        text,
        quotedMessageId: messageId(replyMessage.value),
        quotedSenderId: replyMessage.value.senderId,
        quotedTextPreview: getMessageText(replyMessage.value),
        quotedContent: quotedMessageContent(replyMessage.value),
      });
    } else if (composerRichMode.value || textLooksLikeRichMarkdown(text)) {
      task = operations.sendComposerPayload(buildRichTextPayload(text));
    } else {
      const loneEmojiKey = resolveLoneEmojiPackKey(text);
      if (loneEmojiKey) {
        task = sdk.sendEmoji(loneEmojiKey);
      } else {
        task = sdk.sendText(text);
      }
    }
    // 不等 ack 再放行输入框。
    //
    // 原来这里 `await` 整个发送直到服务端 ack，而 `sending` 守卫覆盖同一段时间
    // （`if (sending.value) return;`）。ack 迟到时——线上实测过 ack 根本没回来、
    // 一直到 30s 超时——这期间用户的每一次点击都被**静默丢弃**：
    // 没有气泡、没有提示、也没有进入核心，看起来就像“发送键坏了”。
    //
    // 发送本身已经是有状态的：核心在入队前就把消息以 sending 落库并发总线，
    // 失败会翻成 failed 并由气泡呈现重发入口。所以这里只负责“交出去”，
    // 后续状态一律由 ack / 回执事件驱动。
    void withComposerSendDeadline(task).catch((error: unknown) => {
      const detail = describeSdkError(error);
      message.error(detail || t("toast.sendFailed"));
      // 仅当用户此后没有再输入时，才把原文放回输入框，避免覆盖新内容
      if (composerUserEditVersion === composerVersionAtSubmit && !composerText.value.trim()) {
        setComposerTextSilently(text);
        void flushComposerDraftNow(sdk.activeConversationId.value, text);
      }
    });
    sendAcknowledged = true;
    editingMessageId.value = "";
    replyMessageId.value = "";
    composerPanel.value = null;
    await nextTick();
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    // 这里只剩**提交前**的同步失败（构建载荷、清草稿）
    const detail = describeSdkError(error);
    if (sendAcknowledged) {
      console.warn("[flare-web] post_send_cleanup_failed", detail);
      return;
    }
    message.error(detail || t("toast.sendFailed"));
    if (!composerText.value.trim()) {
      setComposerTextSilently(text);
      void flushComposerDraftNow(sdk.activeConversationId.value, text);
    }
  } finally {
    sending.value = false;
  }
}

async function reactMessage(id: string, emoji: string): Promise<void> {
  try {
    await operations.toggleReaction(id, emoji);
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.reactFailed"));
  }
}

function forwardOne(id: string): void {
  selectedMessageIds.value = [id];
  interactions.openForward("separate", [id]);
}

async function recallMessage(id: string): Promise<void> {
  try {
    await sdk.recallMessageById(id);
    if (editingMessageId.value === id) cancelEditingMessage();
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.recallFailed"));
  }
}

function editMessage(id: string): void {
  const target = findMessage(id);
  if (!target) {
    message.warning(t("toast.editNotFound"));
    return;
  }
  const text = getMessageText(target).trim();
  if (!text) {
    message.warning(t("toast.editNoText"));
    return;
  }
  editingMessageId.value = id;
  replyMessageId.value = "";
  composerPanel.value = null;
  setComposerTextSilently(text);
}

function cancelEditingMessage(): void {
  editingMessageId.value = "";
  setComposerTextSilently("");
}

async function markMessage(id: string): Promise<void> {
  sdk.sdkLab.messageId = id;
  await sdk.runDispatch("mark_by_message_id");
  await sdk.refreshActiveChat();
}

async function deleteMessage(id: string): Promise<void> {
  const result = await operations.deleteMessagesForSelf([id]);
  showBatchResult(t("toast.batchAction.delete"), result);
}

async function pinMessage(id: string, pinned: boolean, scope: MessagePinScope = "conversation"): Promise<void> {
  const result = await operations.setMessagesPinned([id], pinned, scope);
  showBatchResult(pinned ? t("toast.batchAction.pin") : t("toast.batchAction.unpin"), result);
}

function startReply(id: string): void {
  editingMessageId.value = "";
  replyMessageId.value = id;
  composerPanel.value = null;
}

function startMultiSelect(id: string): void {
  cancelEditingMessage();
  replyMessageId.value = "";
  composerPanel.value = null;
  chatContentTab.value = "messages";
  interactions.enterMultiSelect(id);
}

function toggleSelected(id: string): void {
  interactions.toggleSelected(id);
}

function exitMultiSelect(): void {
  interactions.exitMultiSelect();
}

function forwardSelected(merge: boolean): void {
  if (!selectedMessageIds.value.length) return;
  interactions.openForward(merge ? "merged" : "separate");
}

async function deleteSelectedForSelf(): Promise<void> {
  const result = await operations.deleteMessagesForSelf(selectedMessageIds.value);
  showBatchResult(t("toast.batchAction.delete"), result);
  if (!result.failed.length) exitMultiSelect();
}

async function pinSelected(): Promise<void> {
  const result = await operations.setMessagesPinned(selectedMessageIds.value, true, "conversation");
  showBatchResult(t("toast.batchAction.pin"), result);
  if (!result.failed.length) exitMultiSelect();
}

async function pinSelectedForSelf(): Promise<void> {
  const result = await operations.setMessagesPinned(selectedMessageIds.value, true, "self");
  showBatchResult(t("toast.batchAction.pinSelf"), result);
  if (!result.failed.length) exitMultiSelect();
}

function handleBatchAction(payload: { action: MessageBatchAction; ids: string[] }): void {
  switch (payload.action) {
    case "forwardEach": forwardSelected(false); break;
    case "forwardMerged": forwardSelected(true); break;
    case "pin": void pinSelected(); break;
    case "pinSelf": void pinSelectedForSelf(); break;
    case "delete": void deleteSelectedForSelf(); break;
  }
}

function showBatchResult(action: string, result: BatchOperationResult): void {
  if (result.failed.length) {
    message.error(t("toast.batchPartial", { action, ok: result.succeeded.length, total: result.total, fail: result.failed.length, detail: result.failed[0]?.reason ?? "" }));
    return;
  }
  message.success(t("toast.batchSuccess", { action, ok: result.succeeded.length, total: result.total }));
}

function openPreview(id: string): void {
  workbenchUi.openPreview(id);
}

function mediaMessageId(row: Message): string {
  return row.clientMsgId || row.serverId;
}

function findMessageByActionId(id: string): Message | undefined {
  return sdk.messages.value.find((row) => mediaMessageId(row as unknown as Message) === id) as Message | undefined;
}

/** Save sources of [row]; a file path on this device counts only in the user's own messages. */
function mediaDownloadSources(row: unknown): MessageMediaDownloadSource[] {
  return listMessageMediaDownloadSources(row as unknown as Parameters<typeof listMessageMediaDownloadSources>[0], {
    currentUserId: (sdk.currentUserId.value || sdk.form.userId).trim(),
  });
}

function firstMediaDownloadSource(row: unknown): MessageMediaDownloadSource | null {
  const sources = mediaDownloadSources(row);
  return sources[0] ?? null;
}

function savedPathFromResponse(response: unknown): string {
  if (typeof response === "string") return response.trim();
  if (!response || typeof response !== "object") return "";
  const record = response as Record<string, unknown>;
  const value = record.path ?? record.savedPath ?? record.localPath;
  return typeof value === "string" ? value.trim() : "";
}

function mediaDownloadRequest(source: MessageMediaDownloadSource): Record<string, unknown> {
  return {
    downloadKey: source.downloadKey,
    displayFileName: source.displayFileName,
    ...(source.sourcePath ? { sourcePath: source.sourcePath } : {}),
    ...(!source.remoteFileId && source.sourceHttpUrl ? { sourceHttpUrl: source.sourceHttpUrl } : {}),
    ...(source.remoteFileId ? { remoteFileId: source.remoteFileId } : {}),
    ...(source.mimeType ? { mimeType: source.mimeType } : {}),
  };
}

function isNativeDownloadUnsupported(error: unknown): boolean {
  const record = error && typeof error === "object" ? (error as Record<string, unknown>) : {};
  const code = String(record.code ?? "");
  const operation = String(record.operation ?? "");
  const detail = error instanceof Error ? error.message : String(error ?? "");
  return (
    code === "operation.not_supported" ||
    operation.includes("media.download_file_to_downloads") ||
    detail.includes("operation.not_supported") ||
    detail.includes("Native media cache is disabled")
  );
}

async function resolveBrowserDownloadUrl(source: MessageMediaDownloadSource): Promise<string> {
  if (source.remoteFileId) {
    try {
      const url = await sdk.client.media.resolveDisplayUrl({
        fileId: source.remoteFileId,
        mediaUrl: source.sourceHttpUrl ?? "",
      });
      return proxiedMediaUrl(url);
    } catch {
      // Fall through to explicit browser/source URLs when the runtime cannot resolve media access.
    }
  }
  if (source.browserUrl) return proxiedMediaUrl(source.browserUrl);
  if (source.sourceHttpUrl) return proxiedMediaUrl(source.sourceHttpUrl);
  return "";
}

function setMediaDownloadState(source: MessageMediaDownloadSource, state: MediaDownloadState): void {
  mediaDownloadStates.value = {
    ...mediaDownloadStates.value,
    [source.downloadKey]: state,
  };
}

async function downloadMediaSource(source: MessageMediaDownloadSource): Promise<void> {
  setMediaDownloadState(source, "downloading");
  try {
    const response = await sdk.client.media.downloadFileToDownloads(mediaDownloadRequest(source));
    const savedPath = savedPathFromResponse(response);
    if (savedPath) {
      const record = (response ?? {}) as Record<string, unknown>;
      // web：交给浏览器下载的文件，页面看不到它落在哪，也打不开所在文件夹。
      const byBrowser = record.savedVia === "browser";
      setMediaDownloadState(source, byBrowser ? "notDownloaded" : "downloaded");
      const location = String(record.directory ?? "").trim();
      message.success(
        byBrowser
          ? t("toast.downloadStarted")
          : location
            ? t("toast.savedTo", { location })
            : t("toast.downloaded"),
      );
      return;
    }
  } catch (error) {
    if (!isNativeDownloadUnsupported(error)) {
      setMediaDownloadState(source, "notDownloaded");
      throw error;
    }
  }

  const browserUrl = await resolveBrowserDownloadUrl(source);
  if (!browserUrl) {
    setMediaDownloadState(source, "notDownloaded");
    throw new Error(t("toast.noDownloadUrl"));
  }
  try {
    await startBrowserDownload(browserUrl, source.displayFileName);
    setMediaDownloadState(source, "notDownloaded");
  } catch (error) {
    setMediaDownloadState(source, "notDownloaded");
    throw error;
  }
}

async function openDownloadedMediaFolder(source: MessageMediaDownloadSource): Promise<void> {
  try {
    const response = await sdk.client.media.getUserDownloadSavedPath({
      downloadKey: source.downloadKey,
      fileId: source.fileId,
    });
    const savedPath = savedPathFromResponse(response);
    if (!savedPath) {
      setMediaDownloadState(source, "notDownloaded");
      await downloadMediaSource(source);
      return;
    }
    const opened = await revealDownloadedMediaFile(savedPath);
    if (opened) {
      setMediaDownloadState(source, "downloaded");
      return;
    }
    await sdk.client.media.deleteUserDownloadRecord({
      downloadKey: source.downloadKey,
      fileId: source.fileId,
    });
    setMediaDownloadState(source, "notDownloaded");
    message.warning(t("toast.localFileMissing"));
  } catch (error) {
    if (!isNativeDownloadUnsupported(error)) {
      throw error;
    }
    await downloadMediaSource(source);
  }
}

async function handleMediaAction(id: string, action: MediaDownloadAction): Promise<void> {
  const row = findMessageByActionId(id);
  if (!row) return;
  const sources = mediaDownloadSources(row);
  if (!sources.length) return;
  try {
    if (action === "openFolder") {
      await openDownloadedMediaFolder(sources[0]);
      return;
    }
    for (const source of sources) {
      await downloadMediaSource(source);
    }
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.downloadFailed"));
  }
}

async function refreshVisibleMediaDownloadStates(): Promise<void> {
  if (!canRevealDownloadedMedia() || mediaDownloadRefreshInFlight.value) return;
  const sourcesByKey = new Map<string, MessageMediaDownloadSource>();
  for (const row of sdk.messages.value) {
    for (const source of mediaDownloadSources(row)) {
      sourcesByKey.set(source.downloadKey, source);
    }
  }
  if (!sourcesByKey.size) return;
  mediaDownloadRefreshInFlight.value = true;
  try {
    const next = { ...mediaDownloadStates.value };
    for (const source of sourcesByKey.values()) {
      if (next[source.downloadKey] === "downloaded") continue;
      try {
        const response = await sdk.client.media.getUserDownloadSavedPath({
          downloadKey: source.downloadKey,
          fileId: source.fileId,
        });
        next[source.downloadKey] = savedPathFromResponse(response)
          ? "downloaded"
          : "notDownloaded";
      } catch (error) {
        if (!isNativeDownloadUnsupported(error)) {
          next[source.downloadKey] = "notDownloaded";
        }
      }
    }
    mediaDownloadStates.value = next;
  } finally {
    mediaDownloadRefreshInFlight.value = false;
  }
}

function isMediaComposerAction(action: ComposerActionDefinition | undefined): action is ComposerActionDefinition {
  if (!action?.acceptsFiles) return false;
  return ["file", "image", "video", "audio", "imageGroup"].includes(action.kind);
}

function mediaAcceptForKind(kind: EnhancedMessageKind): string {
  if (kind === "image" || kind === "imageGroup") return "image/*";
  if (kind === "video") return "video/*";
  if (kind === "audio") return "audio/*";
  return "";
}

function mediaNameFromPath(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  return normalized.split("/").filter(Boolean).pop() || path;
}

function revokeMediaPreviewUrls(): void {
  for (const item of mediaPreviewItems.value) {
    if (item.previewUrl?.startsWith("blob:") && typeof URL !== "undefined" && typeof URL.revokeObjectURL === "function") {
      URL.revokeObjectURL(item.previewUrl);
    }
  }
}

function setMediaPreviewItems(action: ComposerActionDefinition, items: MediaComposerPreviewItem[]): void {
  revokeMediaPreviewUrls();
  activeMediaAction.value = action;
  mediaPreviewItems.value = items;
  mediaPreviewOpen.value = items.length > 0;
}

function mediaActionForSelection(action: ComposerActionDefinition, count: number): ComposerActionDefinition {
  if (action.kind === "image" && count > 1) {
    return resolveComposerAction("create_image_group") ?? action;
  }
  return action;
}

function closeMediaPreview(): void {
  revokeMediaPreviewUrls();
  mediaPreviewItems.value = [];
  mediaPreviewOpen.value = false;
  activeMediaAction.value = null;
}

async function openMediaComposer(action: ComposerActionDefinition): Promise<void> {
  composerPanel.value = null;
  interactions.closeComposerAction();
  activeMediaAction.value = action;
  const multiple = action.kind === "image" || Boolean(action.multipleFiles);
  // The platform contract owns the native surface: DOM input on web, the
  // dialog plugin on Tauri. A dismissed picker is CANCELLED and stays silent.
  const result = action.kind === "image"
    ? await callPlatform(platform.adapter.value, "pickImages", { multiple })
    : await callPlatform(platform.adapter.value, "pickFiles", {
        multiple,
        accept: mediaAcceptForKind(action.kind).split(",").map((entry) => entry.trim()).filter(Boolean),
      });
  if (!result.ok) {
    activeMediaAction.value = null;
    if (result.error.code !== "CANCELLED") message.error(result.error.message || t("toast.mediaPickFailed"));
    return;
  }
  const files = result.value.map((item) => item.file).filter((file): file is File => Boolean(file));
  if (files.length) {
    previewMediaFiles(action, files);
    return;
  }
  const paths = result.value.map((item) => item.path?.trim() ?? "").filter(Boolean);
  if (!paths.length) {
    activeMediaAction.value = null;
    return;
  }
  const previewAction = mediaActionForSelection(action, paths.length);
  setMediaPreviewItems(previewAction, paths.map((path, index) => ({
    id: `${previewAction.kind}:path:${index}:${path}`,
    kind: previewAction.kind,
    name: mediaNameFromPath(path),
    sourcePath: path,
    previewUrl: previewAction.kind === "file" ? "" : resolveAppMediaLocalPath(path),
  })));
}

function handleDroppedFiles(files: File[]): void {
  if (!files.length || sending.value) return;
  const op = files.every((file) => file.type.startsWith('image/'))
    ? 'create_image' : files.length === 1 && files[0].type.startsWith('video/') ? 'create_video' : 'create_file';
  const action = resolveComposerAction(op);
  if (action) previewMediaFiles(action, files);
}

function previewMediaFiles(action: ComposerActionDefinition, selected: File[]): void {
  const files = action.kind === "image" || action.multipleFiles ? selected : selected.slice(0, 1);
  if (!files.length) return;
  const previewAction = mediaActionForSelection(action, files.length);
  setMediaPreviewItems(previewAction, files.map((file, index) => ({
    id: `${previewAction.kind}:file:${index}:${file.name}:${file.size}:${file.lastModified}`,
    kind: previewAction.kind,
    name: file.name,
    file,
    mimeType: file.type || "application/octet-stream",
    size: file.size,
    previewUrl: typeof URL !== "undefined" && typeof URL.createObjectURL === "function"
      ? URL.createObjectURL(file)
      : "",
  })));
}

/**
 * 把浏览器里的 Blob/File 转成核心可识别的 `data:` 定位符。
 *
 * 核心的 `send_with_media` 会把 `data:` / `blob:` / iOS `ph://` / 小程序临时路径
 * 一律当作**待上传的本地媒体**：先把消息以 `uploading` 状态落库并发总线（气泡立刻出现），
 * 再上传并按字节回填进度，最后才真正发送。`https://` 则被视为已就绪的远端资源，
 * 核心不再上传——那是「应用自己上传后用资源地址发送」的口子。
 *
 * 所以应用**不应该**自己调 media.upload_*：那样上传期间没有气泡也没有进度，
 * 消息要等上传完成才出现。
 */
async function blobToCoreDataUrl(
  blob: Blob,
  fileName: string,
  mimeType: string,
): Promise<string> {
  const raw = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ""));
    reader.onerror = () => reject(reader.error ?? new Error("file read failed"));
    reader.readAsDataURL(blob);
  });
  const comma = raw.indexOf(",");
  const body = comma >= 0 ? raw.slice(comma + 1) : raw;
  const type = mimeType || blob.type || "application/octet-stream";
  return `data:${type};name=${encodeURIComponent(fileName)};size=${blob.size};base64,${body}`;
}

async function fileToCoreDataUrl(file: File): Promise<string> {
  const raw = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ""));
    reader.onerror = () => reject(reader.error ?? new Error("file read failed"));
    reader.readAsDataURL(file);
  });
  const comma = raw.indexOf(",");
  const body = comma >= 0 ? raw.slice(comma + 1) : raw;
  const mimeType = file.type || "application/octet-stream";
  return `data:${mimeType};name=${encodeURIComponent(file.name)};size=${file.size};base64,${body}`;
}

function uploadRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function normalizedUploadRecord(value: unknown): Record<string, unknown> {
  const source = uploadRecord(value);
  const result = { ...source };
  for (const key of ["data", "file", "media", "result", "payload"]) {
    const nested = uploadRecord(source[key]);
    for (const [nestedKey, nestedValue] of Object.entries(nested)) {
      if (result[nestedKey] === undefined) result[nestedKey] = nestedValue;
    }
  }
  return result;
}

function uploadStringValue(source: Record<string, unknown>, ...keys: string[]): string {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return "";
}

function uploadNumberValue(source: Record<string, unknown>, ...keys: string[]): number {
  for (const key of keys) {
    const raw = source[key];
    if (typeof raw === "number" && Number.isFinite(raw) && raw > 0) return raw;
    if (typeof raw === "string" && raw.trim()) {
      const value = Number(raw);
      if (Number.isFinite(value) && value > 0) return value;
    }
  }
  return 0;
}

async function uploadAudioMediaItem(item: MediaComposerPreviewItem): Promise<ComposerMediaSource> {
  const fileName = item.name || item.file?.name || mediaNameFromPath(item.sourcePath ?? "") || `audio-${Date.now()}.webm`;
  const mimeType = item.mimeType || item.file?.type || "audio/webm";
  const fileSize = item.size ?? item.file?.size ?? 0;
  // 与图片/视频/文件保持一致：交出本地定位符，由核心负责上传与进度。
  // 这里原来先调 media.upload_* 自己传完再发，导致上传期间既没有气泡也没有进度，
  // 消息要等整段上传结束才出现——这正是要消除的应用侧重复实现。
  if (item.file) {
    return {
      sourcePath: await blobToCoreDataUrl(item.file, fileName, mimeType),
      fileName,
      mimeType,
      fileSize,
    };
  }
  if (item.sourcePath) {
    // 已是本地路径（iOS ph:// / 小程序临时路径 / blob:），核心同样会识别并上传。
    return { sourcePath: item.sourcePath, fileName, mimeType, fileSize };
  }
  throw new Error("missing selected audio file");
}

async function mediaItemSource(item: MediaComposerPreviewItem, kind: EnhancedMessageKind): Promise<ComposerMediaSource> {
  if (kind === "audio") return uploadAudioMediaItem(item);
  if (item.sourcePath) {
    return {
      sourcePath: item.sourcePath,
      fileName: item.name,
      mimeType: item.mimeType ?? "",
      fileSize: item.size ?? 0,
    };
  }
  if (!item.file) throw new Error("missing selected media file");
  return {
    sourcePath: await fileToCoreDataUrl(item.file),
    fileName: item.name,
    mimeType: item.mimeType ?? item.file.type ?? "application/octet-stream",
    fileSize: item.size ?? item.file.size,
  };
}

async function sendMediaPreview(description: string): Promise<void> {
  const action = activeMediaAction.value;
  if (!action || sending.value) return;
  const items = [...mediaPreviewItems.value];
  if (!items.length) return;
  const sources = await Promise.all(items.map((item) => mediaItemSource(item, action.kind)));
  const first = sources[0];
  if (!first) return;
  const params: Record<string, unknown> = {
    description,
    sourcePath: first.sourcePath,
    sourceUrl: first.sourceUrl ?? "",
    fileName: first.fileName,
    mimeType: first.mimeType,
    fileSize: first.fileSize,
    size: first.fileSize,
  };
  if (action.kind === "image") params.imageId = first.sourcePath;
  if (action.kind === "video") params.videoId = first.sourcePath;
  if (action.kind === "audio") params.audioId = first.sourcePath;
  if (action.kind === "file") params.fileId = first.sourcePath;
  if (action.kind === "imageGroup") {
    params.imageSources = sources.map((source) => ({
      imageId: source.sourcePath,
      fileName: source.fileName,
      mimeType: source.mimeType,
      size: source.fileSize,
    }));
  }
  closeMediaPreview();
  await sendComposerPayload(action.buildRequest(params, []), { rethrow: true });
}

async function sendVoiceRecording(recording: VoiceRecordingPayload): Promise<void> {
  if (!sdk.activeConversationId.value) {
    message.warning(t("error.selectConversationFirst"));
    return;
  }
  if (sending.value) return;
  const action = resolveComposerAction("create_audio");
  if (!action) {
    message.error(t("toast.voiceBuilderUnavailable"));
    return;
  }

  prepareComposerSend();
  sending.value = true;
  try {
    const mimeType = recording.mimeType || "audio/mp4";
    const fileName = recording.fileName || `voice-${Date.now()}.m4a`;
    const size = recording.blob.size;
    // 同上：交给核心上传，录完立刻出气泡并显示上传进度。
    const localLocator = await blobToCoreDataUrl(recording.blob, fileName, mimeType);
    const source = { sourcePath: localLocator, sourceUrl: "", fileName, mimeType, fileSize: size };
    // 同文本路径：不等 ack。语音还要先上传，等下去会把输入区锁住更久，
    // 期间的点击会被 `sending` 守卫静默丢弃。
    void withComposerSendDeadline(operations.sendComposerPayload(action.buildRequest({
      audioId: source.sourcePath,
      sourcePath: source.sourcePath,
      sourceUrl: source.sourceUrl ?? "",
      fileName: source.fileName,
      mimeType: source.mimeType,
      size: source.fileSize || size,
      fileSize: source.fileSize || size,
      durationMs: recording.durationMs,
      description: t("toast.voiceMessageDesc"),
    }))).catch((error: unknown) => {
      const detail = describeSdkError(error);
      message.error(detail || t("toast.voiceSendFailed"));
    });
    setComposerTextSilently("");
    clearComposerDraft(undefined, true);
    composerPanel.value = null;
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.voiceSendFailed"));
  } finally {
    sending.value = false;
  }
}

function handleComposerVoicePayload(payload: VoiceRecordingPayload): void {
  if (handledVoicePayloads.has(payload)) return;
  handledVoicePayloads.add(payload);
  void sendVoiceRecording(payload);
}

function handleComposerVoiceDomEvent(event: Event): void {
  const detail = (event as CustomEvent<VoiceRecordingPayload>).detail;
  if (!detail || !(detail.blob instanceof Blob)) return;
  handleComposerVoicePayload(detail);
}

async function buildFromAction(op: string): Promise<void> {
  if (!sdk.activeConversationId.value) {
    message.warning(t("error.selectConversationFirst"));
    return;
  }
  const action = resolveComposerAction(op);
  if (action?.kind === "richText") {
    composerRichMode.value = true;
    composerPanel.value = null;
    await nextTick();
    return;
  }
  if (isMediaComposerAction(action)) {
    await openMediaComposer(action);
    return;
  }
  if (action) {
    interactions.openComposerAction(op);
    return;
  }
  if (sending.value) return;
  prepareComposerSend();
  sending.value = true;
  try {
    // 同其它发送路径：提交后立刻放行输入区，不等 ack。
    void withComposerSendDeadline(sdk.buildFromComposerAction(op, composerText.value))
      .catch((error: unknown) => {
        const detail = describeSdkError(error);
        message.error(detail || t("toast.sendFailed"));
      });
    setComposerTextSilently("");
    clearComposerDraft(undefined, true);
    composerPanel.value = null;
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.sendFailed"));
  } finally {
    sending.value = false;
  }
}

async function sendComposerPayload(
  payload: ComposerPayloadRequest,
  options: { rethrow?: boolean } = {},
): Promise<void> {
  if (sending.value) return;
  prepareComposerSend();
  sending.value = true;
  try {
    // 同文本/语音路径：不等 ack 再放行。媒体还要先上传，等下去锁住输入区更久，
    // 期间的点击会被 `sending` 守卫静默丢弃（没有气泡、没有提示）。
    const task = withComposerSendDeadline(operations.sendComposerPayload(payload))
      .catch((error: unknown) => {
        const detail = describeSdkError(error);
        message.error(detail || t("toast.sendFailed"));
        if (options.rethrow) throw error;
      });
    composerActionOpen.value = false;
    activeComposerOp.value = "";
    setComposerTextSilently("");
    clearComposerDraft(undefined, true);
    composerPanel.value = null;
    await messageListRef.value?.scrollToBottom();
    // rethrow 由调用方决定是否等待失败结果；默认不阻塞输入区
    if (options.rethrow) await task;
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.sendFailed"));
    if (options.rethrow) throw error;
  } finally {
    sending.value = false;
  }
}

async function confirmForward(payload: { targetConversationId: string; title: string }): Promise<void> {
  const mode: ForwardMode = forwardMode.value;
  const result = await operations.forwardMessages({
    mode,
    targetConversationId: payload.targetConversationId,
    title: payload.title,
    messageIds: selectedMessageIds.value,
  });
  showBatchResult(mode === "merged" ? t("toast.batchAction.forwardMerged") : t("toast.batchAction.forwardEach"), result);
  if (!result.failed.length) {
    interactions.closeForward();
    exitMultiSelect();
  }
}

async function resendMessage(clientMsgId: string): Promise<void> {
  if (!clientMsgId || sending.value) return;
  sending.value = true;
  try {
    // 重发同样不等 ack：这条消息的状态本来就在气泡上（sending / failed），
    // 阻塞输入区只会让用户在等待期间点什么都没反应。
    void withComposerSendDeadline(sdk.resendFailedMessage(clientMsgId))
      .catch((error: unknown) => {
        const detail = describeSdkError(error);
        message.error(detail || t("toast.resendFailed"));
      });
    await messageListRef.value?.scrollToBottom();
  } finally {
    sending.value = false;
  }
}

function insertEmojiPackKey(packKey: string): void {
  const token = formatEmojiPackToken(packKey);
  if (!token) return;
  if (composerRef.value?.insertAtCursor) {
    composerRef.value.insertAtCursor(token);
    return;
  }
  composerText.value = `${composerText.value}${token}`;
}

type ComposerStickerSendPick = {
  stickerId: string;
  packageId: string;
  url: string;
};

function onSendStickerFromPanel(payload: { picks: ComposerStickerSendPick[] }): void {
  const pick = payload.picks[0];
  if (!pick) return;
  void sendStickerItem(pick);
}

async function sendStickerItem(sticker: ComposerStickerSendPick): Promise<void> {
  if (!sdk.activeConversationId.value) {
    message.warning(t("error.selectConversationFirst"));
    return;
  }
  // 贴纸连点是常见操作，等 ack 会让第二次点击看起来没反应。
  void withComposerSendDeadline(sdk.sendSticker({
    stickerId: sticker.stickerId,
    packageId: sticker.packageId,
    url: sticker.url,
    stickerFormat: "webp",
  })).catch((error: unknown) => {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.stickerSendFailed"));
  });
  await messageListRef.value?.scrollToBottom();
}

function dismissMediaPanel(): void {
  if (composerPanel.value === "emoji" || composerPanel.value === "sticker") {
    composerPanel.value = null;
  }
}

function onChatEscape(event: KeyboardEvent): void {
  if (event.key !== "Escape") return;
  dismissMediaPanel();
}

function syncComposerVoiceDomListener(): void {
  const nextTarget = composerStackRef.value;
  if (composerVoiceDomTarget === nextTarget) return;
  composerVoiceDomTarget?.removeEventListener("flare-send-voice", handleComposerVoiceDomEvent as EventListener);
  composerVoiceDomTarget = nextTarget;
  composerVoiceDomTarget?.addEventListener("flare-send-voice", handleComposerVoiceDomEvent as EventListener);
}

onMounted(() => {
  window.addEventListener("keydown", onChatEscape);
  window.addEventListener("flare-send-voice", handleComposerVoiceDomEvent as EventListener);
  void nextTick(() => {
    syncComposerVoiceDomListener();
  });
});

watch(composerStackRef, syncComposerVoiceDomListener, { flush: "post" });

onBeforeUnmount(() => {
  window.removeEventListener("keydown", onChatEscape);
  window.removeEventListener("flare-send-voice", handleComposerVoiceDomEvent as EventListener);
  composerVoiceDomTarget?.removeEventListener("flare-send-voice", handleComposerVoiceDomEvent as EventListener);
  composerVoiceDomTarget = null;
  closeMediaPreview();
  clearScrollBottomRetry();
  if (typingTimer !== undefined) {
    window.clearTimeout(typingTimer);
    typingTimer = undefined;
  }
  clearPeerPresenceRefreshTimer();
  operations.dispose();
  cancelAllPendingDraftClears();
  void draftScheduler.flush();
  draftScheduler.dispose();
});

onBeforeRouteLeave(async () => {
  await flushComposerDraftNow(sdk.activeConversationId.value, editingMessageId.value ? "" : composerText.value);
});

function toggleComposerPanel(panel: "emoji" | "sticker" | "more" | null): void {
  composerPanel.value = panel;
  void messageListRef.value?.scrollToBottom();
}

function setComposerMediaTab(tab: "emoji" | "sticker"): void {
  composerPanel.value = tab;
  void messageListRef.value?.scrollToBottom();
}

async function syncEmptyChat(): Promise<void> {
  try {
    await sdk.syncActiveConversation();
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("sync.failedTitle"));
  }
}

async function loadOlderMessages(): Promise<void> {
  try {
    await sdk.loadOlderMessages();
  } catch (error) {
    const detail = describeSdkError(error);
    message.error(detail || t("toast.loadHistoryFailed"));
  }
}

async function focusPinnedMessage(messageId: string): Promise<void> {
  await locateMessage(messageId);
}

const headerActions = computed<Array<FlareConversationHeaderAction & { icon: FlareIconName }>>(() => multiSelectMode.value ? [
  { id: 'selectAll', label: t('enhance.selectAll'), icon: 'check', enabled: !operationBusy.value && !allSelected.value },
  { id: 'forwardEach', label: t('enhance.forwardEach'), icon: 'share', enabled: selectedMessageIds.value.length > 0 },
  { id: 'forwardMerged', label: t('enhance.forwardMerged'), icon: 'share', enabled: selectedMessageIds.value.length > 1 },
  { id: 'pin', label: t('chat.pinTab'), icon: 'pin', enabled: selectedMessageIds.value.length > 0 },
  { id: 'pinSelf', label: t('toast.batchAction.pinSelf'), icon: 'pin', enabled: selectedMessageIds.value.length > 0 },
  { id: 'delete', label: t('enhance.opDelete'), icon: 'delete', enabled: selectedMessageIds.value.length > 0 },
] : [
  { id: 'search', label: t('workbench.searchMessages'), icon: 'search' },
  { id: 'sdkBuild', label: t('workbench.sdkMsgType'), icon: 'file' },
  { id: 'more', label: t('workbench.more'), icon: 'more', dot: updates.badge.value },
]);

function handleHeaderAction(action: { id: string }): void {
  switch (action.id) {
    case 'search': workbenchUi.openChatSearch(); break;
    case 'sdkBuild': workbenchUi.openSdkBuild(); break;
    case 'more': workbenchUi.openMore(); break;
    case 'selectAll': interactions.selectAll(); break;
    case 'forwardEach': forwardSelected(false); break;
    case 'forwardMerged': forwardSelected(true); break;
    case 'pin': void pinSelected(); break;
    case 'pinSelf': void pinSelectedForSelf(); break;
    case 'delete': void deleteSelectedForSelf(); break;
  }
}

</script>

<template>
  <ChatWorkspace composer-placement="overlay" :selection-mode="multiSelectMode" :label="activeTitle">
    <template #header>
    <FlareConversationHeader
      :identity="{
        id: sdk.activeConversation.value?.channelId || activeTitle,
        title: multiSelectMode ? t('chat.multiSelect', { count: selectedMessageIds.length }) : activeTitle,
        subtitle: multiSelectMode ? undefined : activeSubtitle,
        presence: multiSelectMode ? undefined : peerPresenceStatus,
        typingText: multiSelectMode ? undefined : activeTypingText,
      }"
      :configuration="{ replaceDefaults: true, maxPrimaryActions: 5, compactMaxPrimaryActions: 1 }"
      :actions="headerActions"
      show-back
      @back="back"
      @action="handleHeaderAction"
    />
    </template>

    <!-- The connection itself has the app's one connection notice; this slot is the conversation's own sync. -->
    <template v-if="sdk.messageSyncError.value && sdk.messages.value.length" #notice>
      <FlareStatusBanner
        :text="`${t('chat.messageSyncFailed')} · ${sdk.messageSyncError.value}`"
        tone="danger"
        :action-text="t('chat.syncRetry')"
        @action="syncEmptyChat"
      />
    </template>

    <template v-if="showContentTabs" #toolbar>
      <FlareFilterTabs
        :model-value="chatContentTab"
        :aria-label="t('chat.contentTabsAria')"
        layout="wrap"
        :options="[
          { value: 'messages', label: t('chat.messagesTab'), icon: ChatbubbleEllipsesOutline },
          { value: 'pin', label: t('chat.pinTab'), icon: PinOutline, badge: pinnedCount },
        ]"
        @update:model-value="chatContentTab = $event === 'pin' ? 'pin' : 'messages'"
      />
    </template>

    <template #timeline="{ bottomInset }">
      <PinnedMessageBar
        v-if="showingPinnedTab"
        :items="sdk.pinnedMessages.value"
        @focus="focusPinnedMessage"
      />
      <template v-else>
        <FlareEmptyState
          v-if="!sdk.messages.value.length"
          :title="chatEmptyState.title"
          :description="chatEmptyState.detail"
          :loading="chatEmptyState.loading"
          :tone="chatEmptyState.error ? 'error' : 'normal'"
          icon="chats"
          @pointerdown="dismissMediaPanel"
          v-on="chatEmptyState.loading ? {} : { tap: syncEmptyChat }"
        />
        <MessageList
          v-else
          ref="messageListRef"
          @pointerdown="dismissMediaPanel"
          :conversation-id="sdk.activeConversationId.value"
          :conversation-type="sdk.activeConversation.value?.conversationType"
          :messages="timelineMessages"
          :current-user-id="sdk.currentUserId.value || sdk.form.userId"
          :multi-select-mode="multiSelectMode"
          :selected-ids="selectedMessageIds"
          :loading-older="sdk.loadingOlderMessages.value"
          :has-older="sdk.messageHasMore.value"
          :bottom-inset="bottomInset"
          :menu-config="messageMenuConfig"
          :media-download-states="messageMediaDownloadUiStates"
          @react="reactMessage"
          @edit="editMessage"
          @delete="deleteMessage"
          @pin="pinMessage"
          @mark="markMessage"
          @preview="openPreview"
          @media-action="handleMediaAction"
          @reply="startReply"
          @forward="forwardOne"
          @recall="recallMessage"
          @resend="resendMessage"
          @multi-select="startMultiSelect"
          @toggle-select="toggleSelected"
          @locate-message="locateMessage"
          @at-bottom-change="handleTimelineAtBottomChange"
          @load-older="loadOlderMessages"
        />
      </template>
      <MessageBatchToolbar
        v-if="multiSelectMode"
        :selected-ids="selectedMessageIds"
        :total="selectableMessageIds.length"
        :capabilities="batchCapabilities"
        :busy="operationBusy"
        floating
        @select-all="interactions.selectAll"
        @clear-selection="interactions.clearSelection"
        @action="handleBatchAction"
        @exit="exitMultiSelect"
      />
    </template>

    <template v-if="!multiSelectMode && chatContentTab === 'messages'" #composer>
    <footer
      ref="composerStackRef"
      @mousedown.stop
      @click.stop
    >
      <ComposerEmojiStickerPanel
        v-if="mediaPanelOpen"
        :active-tab="composerMediaTab"
        :can-send="canSendText"
        :sending="sending"
        @insert-emoji="insertEmojiPackKey"
        @send-sticker="onSendStickerFromPanel"
        @send-text="sendText"
        @update:active-tab="setComposerMediaTab"
      />
      <EnhancedComposer
        file-drop-enabled
        @files-drop="handleDroppedFiles"
        :key="`${sdk.activeConversationId.value}:${composerSurfaceKey}`"
        ref="composerRef"
        v-model="composerText"
        :sending="sending"
        :disabled="composerDisabled"
        :read-only="updates.readOnly.value"
        :placeholder="composerPlaceholder"
        :target-name="activeTitle"
        :mention-candidates="composerMentionCandidates"
        toolbar-presentation="expanded"
        :actions="composerAttachActions"
        more-search-visible
        :active-panel="composerPanel"
        :rich-mode="composerRichMode"
        :media-panel-open="mediaPanelOpen"
        :reply-sender="replyMessage?.senderDisplayName"
        :reply-preview="replyMessage ? getMessageText(replyMessage) : ''"
        :editing="Boolean(editingMessageId)"
        :edit-preview="editingPreview"
        :send-voice-handler="sendVoiceRecording"
        @send-voice="handleComposerVoicePayload"
        @toggle-panel="toggleComposerPanel"
        @toggle-rich-mode="composerRichMode = $event"
        @clear-reply="replyMessageId = ''"
        @clear-edit="cancelEditingMessage"
        @build="buildFromAction"
        @send="sendText"
      />
    </footer>
    </template>

    <template #overlays>
    <ForwardModal
      v-model:show="forwardOpen"
      :mode="forwardMode"
      :conversations="forwardConversationSource"
      :messages="selectedMessages"
      :active-conversation-id="sdk.activeConversationId.value"
      :loading="operationBusy"
      @confirm="confirmForward"
    />

    <ComposerPayloadModal
      v-model:show="payloadComposerOpen"
      :op="activeComposerOp"
      :loading="sending"
      @submit="sendComposerPayload"
    />

    <MediaComposerPreviewModal
      v-model:show="mediaPreviewOpen"
      :kind="activeMediaAction?.kind ?? 'image'"
      :items="mediaPreviewItems"
      :loading="sending"
      @cancel="closeMediaPreview"
      @submit="sendMediaPreview"
    />
    </template>
  </ChatWorkspace>
</template>
