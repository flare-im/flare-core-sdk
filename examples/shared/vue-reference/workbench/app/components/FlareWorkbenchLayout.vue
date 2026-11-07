<script setup lang="ts">
import { computed, ref, watch, onBeforeUnmount } from "vue";
import { describeSdkError } from "../../shared/errors/describeSdkError";
import {
  AddOutline,
  ArchiveOutline,
  ChatbubbleEllipsesOutline,
  CheckmarkDoneOutline,
  DocumentTextOutline,
  FileTrayOutline,
  ImageOutline,
  InformationCircleOutline,
  LogOutOutline,
  MailUnreadOutline,
  MicOutline,
  NotificationsOffOutline,
  PinOutline,
  SearchOutline,
  SettingsOutline,
  SyncOutline,
  TrashOutline,
  VideocamOutline,
} from "@flare-im/vue-ui/icon-glyphs";
import { useToast } from "../ui/toast";
import AppIcon from "./AppIcon.vue";
import { useRoute, useRouter } from "vue-router";
import {
  FlareConversationDetails as ConversationDetails,
  FlareDangerConfirm,
  FlareButton,
  FlareFormSheet,
  FlareFormField,
  FlareSelect,
  FlareEmptyState,
  FlareFilterTabs,
  FlareIconButton,
  FlareSearchBar,
  FlareSearchResults,
  FlareSettingsList,
  FlareStatusBanner,
  FlareComposerActionPanel as ComposerActionPanel,
  FlareStartConversationDialog,
} from "@flare-im/vue-ui/components";
import MessagePreviewModal from "./MessagePreviewModal.vue";
import DeveloperConsole from "./DeveloperConsole.vue";
import WorkbenchShell from "./WorkbenchShell.vue";
import type { WorkbenchShellMode } from "./workbenchShell";
import { formatBytes, type FlareTone, type FlareSearchResultGroup, type FlareSearchResultItem } from "@flare-im/vue-ui/contracts";
import {
  loadDownloadLocation,
  mediaCacheBytes,
  pickDownloadLocation,
  resetDownloadLocation,
  type DownloadLocation,
} from "../infrastructure/media/downloadLocation";
import { provideFlareWorkbenchUi } from "../../composables/useFlareWorkbenchUi";
import { useFlareTheme, type FlareThemeMode, type FlareThemeVariant } from "@flare-im/vue-ui/theme";
import {
  displayTextFromStoredPreview,
  previewTextFromMessageContent,
} from "@flare-im/vue-ui/utils";
import {
  MessageSearchKind,
} from "@flare-im/sdk/web";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { conversationTitle } from "../shared/conversationTitle";
import { useFlareI18n, type FlareLocale } from "../shared/i18n";
import { useFlareUpdates } from "../state/update";

type MessageIdentity = { readonly serverId: string; readonly clientMsgId: string };
type ChatSearchResultMessage = MessageIdentity & {
  readonly content?: {
    readonly contentType?: string;
    readonly data?: Record<string, unknown>;
  };
  readonly textPreview?: string;
  readonly senderDisplayName?: string;
  readonly senderName?: string;
  readonly senderId?: string;
  readonly createdAt?: number;
  readonly clientCreatedAt?: number;
  readonly conversationSeq?: number;
};
type ChatSearchKindValue = "all" | "text" | "media" | "image" | "video" | "audio" | "file";

const sdk = useFlareSdk();
const message = useToast();
const router = useRouter();
const route = useRoute();
const { t, locale, setLocale } = useFlareI18n();
const { mode: themeMode, variant: themeVariant, setMode: setThemeMode, setVariant: setThemeVariant } =
  useFlareTheme();

const settingsOpen = ref(false);
const updates = useFlareUpdates();
const aboutSections = computed(() => [{
  items: [{ key: "about", label: t("versionPanel.title"), icon: "info", kind: "navigation" as const, badge: updates.badge.value }],
}]);

// ── 下载位置与本地媒体缓存（核心 SDK）：设置面板打开时读一次 ──────────────────────
const downloadLocation = ref<DownloadLocation | null>(null);
const mediaCacheSize = ref<number | null>(null);
const clearCacheOpen = ref(false);
const clearingCache = ref(false);
const downloadLocationText = computed(() => {
  const current = downloadLocation.value;
  if (!current) return "";
  return current.managedByBrowser ? t("workbench.downloadLocationBrowser") : current.directory;
});
const mediaCacheText = computed(() => formatBytes(mediaCacheSize.value, locale.value) ?? t("workbench.notMeasured"));

async function refreshStorageSettings(): Promise<void> {
  try {
    downloadLocation.value = await loadDownloadLocation(sdk.client.media);
  } catch {
    downloadLocation.value = null;
  }
  mediaCacheSize.value = await mediaCacheBytes(sdk.client.media).catch(() => null);
}

async function chooseDownloadLocation(): Promise<void> {
  try {
    if (await pickDownloadLocation(sdk.client.media, downloadLocation.value?.directory ?? "")) {
      await refreshStorageSettings();
      message.success(downloadLocationText.value);
    }
  } catch (error) {
    message.error(describeSdkError(error) || t("workbench.downloadLocationUnwritable"));
  }
}

async function useDefaultDownloadLocation(): Promise<void> {
  try {
    await resetDownloadLocation(sdk.client.media);
    await refreshStorageSettings();
  } catch (error) {
    message.error(describeSdkError(error) || t("workbench.downloadLocationUnwritable"));
  }
}

async function confirmClearCache(): Promise<void> {
  clearingCache.value = true;
  try {
    await sdk.client.media.clearMediaCache();
    clearCacheOpen.value = false;
    message.success(t("workbench.cacheCleared"));
    await refreshStorageSettings();
  } catch (error) {
    message.error(describeSdkError(error) || t("workbench.clearCacheFailed"));
  } finally {
    clearingCache.value = false;
  }
}

watch(settingsOpen, (open) => {
  if (open) void refreshStorageSettings();
});
const startChatOpen = ref(false);
const moreOpen = ref(false);
const sdkBuildOpen = ref(false);
const chatSearchOpen = ref(false);
const messageLocation = ref<{ conversationId: string; messageId: string } | null>(null);
const chatSearchQuery = ref("");
const chatSearchKind = ref<ChatSearchKindValue>("all");
const chatSearchLoading = ref(false);
let searchGeneration = 0;
function invalidateSearchPresentation() {
  messageLocation.value = null;
  searchGeneration += 1;
  chatSearchLoading.value = false;
  chatSearchError.value = '';
  chatSearchSearched.value = false;
}
watch([sdk.activeConversationId, sdk.currentUserId], invalidateSearchPresentation, { flush: 'sync' });
onBeforeUnmount(invalidateSearchPresentation);
const chatSearchSearched = ref(false);
const chatSearchError = ref("");
const chatSearchLastQuery = ref("");
const chatSearchLastKind = ref<ChatSearchKindValue>("all");
const previewOpen = ref(false);
const previewMessageId = ref("");
const startConversationType = ref<"single" | "group">("single");
const startPeerUserId = ref("");

watch(startChatOpen, (open) => {
  if (open) {
    startPeerUserId.value = sdk.sdkLab.peerUserId.trim() || "";
  }
});

provideFlareWorkbenchUi({
  messageLocation,
  openMore: () => {
    moreOpen.value = true;
  },
  openStartChat: () => {
    startChatOpen.value = true;
  },
  openSdkBuild: () => {
    sdkBuildOpen.value = true;
  },
  openChatSearch: () => {
    chatSearchOpen.value = true;
  },
  openPreview: (messageId: string) => {
    previewMessageId.value = messageId;
    previewOpen.value = true;
  },
});

const shellMode = computed<WorkbenchShellMode>(() => {
  if (route.name === "chat") return "chat";
  if (route.name === "sdk-lab") return "lab";
  return "conversations";
});

const moreActionCount = computed(() => {
  if (route.name === "chat") return 11;
  if (route.name === "conversations") return 5;
  return 3;
});

const themeModeValue = computed({
  get: () => themeMode.value,
  set: (value: FlareThemeMode) => setThemeMode(value),
});

const themeVariantValue = computed({
  get: () => themeVariant.value,
  set: (value: FlareThemeVariant) => setThemeVariant(value),
});

const localeValue = computed({
  get: () => locale.value,
  set: (value: FlareLocale) => setLocale(value),
});

const moreDrawerTitle = computed(() => (route.name === "chat" ? t("workbench.chatActions") : t("workbench.more")));
const activeConversation = computed(() => sdk.activeConversation.value);
const activeConversationUnread = computed(() => Math.max(0, Number(activeConversation.value?.unreadCount ?? 0) || 0));
const activeConversationPinned = computed(() => Boolean(activeConversation.value?.isPinned));
const activeConversationMuted = computed(() => Boolean(activeConversation.value?.isMuted));
const activeConversationArchived = computed(() => Boolean(activeConversation.value?.isArchived));
const chatSearchResults = computed(() => sdk.messageSearchResults.value);
const chatSearchCanSubmit = computed(() =>
  Boolean(sdk.activeConversationId.value && chatSearchQuery.value.trim() && !chatSearchLoading.value),
);
const chatSearchLastKindLabel = computed(() =>
  chatSearchKindOptions.find((option) => option.value === chatSearchLastKind.value)?.label ?? t("workbench.kind.all"),
);

const chatSearchKindOptions = [
  { label: t("workbench.kind.all"), value: "all", icon: ChatbubbleEllipsesOutline },
  { label: t("workbench.kind.text"), value: "text", icon: DocumentTextOutline },
  { label: t("workbench.kind.media"), value: "media", icon: FileTrayOutline },
  { label: t("workbench.kind.image"), value: "image", icon: ImageOutline },
  { label: t("workbench.kind.video"), value: "video", icon: VideocamOutline },
  { label: t("workbench.kind.audio"), value: "audio", icon: MicOutline },
  { label: t("workbench.kind.file"), value: "file", icon: FileTrayOutline },
] satisfies Array<{ label: string; value: ChatSearchKindValue; icon: typeof SearchOutline }>;

// The details panel shows the connection phase as it is; what to tell the user about it is the connection
// notice's job.
const detailsTone = computed<FlareTone>(() => {
  const phase = sdk.connectionPhase.value;
  if (phase === "online") return "success";
  return phase === "idle" ? "neutral" : "warning";
});

const connectionText = computed(() => sdk.connectionPhase.value);

const diagnosticsText = computed(() => JSON.stringify(sdk.diagnostics.value, null, 2));
const labResultText = computed(() => JSON.stringify(sdk.labResult.value, null, 2));
const previewMessage = computed(() => findMessage(previewMessageId.value));

function findMessage(id: string) {
  if (!id) return null;
  return (
    sdk.messages.value.find((m) => m.serverId === id || m.clientMsgId === id) ??
    chatSearchResults.value.find((m) => m.serverId === id || m.clientMsgId === id) ??
    null
  );
}

function messageId(message: MessageIdentity): string {
  return message.clientMsgId || message.serverId;
}

function chatSearchResultText(message: ChatSearchResultMessage): string {
  const contentText = previewTextFromMessageContent(message.content, locale.value).trim();
  if (contentText) return contentText;
  const storedPreview = displayTextFromStoredPreview(message.textPreview ?? "", locale.value).trim();
  if (storedPreview) return storedPreview;
  return chatSearchResultKindLabel(message);
}

function chatSearchResultKindLabel(message: ChatSearchResultMessage & { readonly content?: { readonly contentType?: string } }): string {
  const type = message.content?.contentType ?? "";
  if (type === "image") return t("workbench.kind.image");
  if (type === "video") return t("workbench.kind.video");
  if (type === "audio") return t("workbench.kind.audio");
  if (type === "file") return t("workbench.kind.file");
  if (type === "sticker") return t("workbench.kind.sticker");
  if (type === "emoji") return t("workbench.kind.emoji");
  return t("workbench.kind.message");
}

function chatSearchResultSender(message: ChatSearchResultMessage): string {
  return message.senderDisplayName?.trim() || message.senderName?.trim() || message.senderId || t("workbench.unknownMember");
}

function chatSearchResultTime(message: ChatSearchResultMessage): string {
  const timestamp = Number(message.createdAt || message.clientCreatedAt || 0);
  if (!Number.isFinite(timestamp) || timestamp <= 0) return t("workbench.justNow");
  const date = new Date(timestamp);
  const now = new Date();
  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();
  const time = new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
  if (sameDay) return time;
  return t("workbench.monthDayTime", { month: date.getMonth() + 1, day: date.getDate(), time });
}

const chatSearchGroups = computed<FlareSearchResultGroup[]>(() => [{
  kind: "message",
  label: `${chatSearchLastKindLabel.value} · ${chatSearchResults.value.length}`,
  items: chatSearchResults.value.map((result) => ({
    id: messageId(result),
    kind: "message",
    title: chatSearchResultSender(result),
    subtitle: chatSearchResultText(result),
    meta: chatSearchResultTime(result),
  })),
}]);

function openSearchItem(item: FlareSearchResultItem): void {
  const result = chatSearchResults.value.find((entry) => messageId(entry) === item.id);
  if (result) openSearchResult(result);
}

function openSearchResult(message: ChatSearchResultMessage): void {
  const id = messageId(message);
  if (!id || !sdk.activeConversationId.value) return;
  messageLocation.value = { conversationId: sdk.activeConversationId.value, messageId: id };
  chatSearchOpen.value = false;
  void router.push({ name: 'chat' });
}

function selectChatSearchKind(value: ChatSearchKindValue): void {
  chatSearchKind.value = value;
  if (!chatSearchQuery.value.trim()) return;
  void searchMessages();
}

function navigate(name: "conversations" | "chat" | "sdk-lab"): void {
  void router.push({ name });
}

async function logout(): Promise<void> {
  await sdk.logout();
  await router.replace({ name: "login" });
}

async function conversationOpenChat(): Promise<void> {
  const peerUserId = startPeerUserId.value.trim();
  if (!peerUserId) return;
  await sdk.openPeerConversation(startConversationType.value, peerUserId);
  startChatOpen.value = false;
  await router.push({ name: "chat" });
}

const dangerOperation = ref<{ kind: 'delete' | 'clear_history'; conversationId: string; userId: string; target: string }>();
const dangerBusy = ref(false);
const dangerError = ref('');
function requestConversationDanger(kind: 'delete' | 'clear_history'): void {
  const conversationId = sdk.activeConversationId.value;
  if (!conversationId) return;
  dangerError.value = '';
  dangerOperation.value = { kind, conversationId, userId: sdk.currentUserId.value,
    target: sdk.activeConversation.value ? conversationTitle(sdk.activeConversation.value) : conversationId };
}
async function confirmConversationDanger(): Promise<void> {
  const request = dangerOperation.value;
  if (!request || dangerBusy.value) return;
  if (request.conversationId !== sdk.activeConversationId.value || request.userId !== sdk.currentUserId.value) {
    dangerError.value = '当前会话已切换，请关闭并重新确认';
    return;
  }
  dangerBusy.value = true;
  dangerError.value = '';
  try {
    await sdk.runConversationOperation(request.kind);
    dangerOperation.value = undefined;
    if (request.kind === 'delete') await router.replace({ name: 'conversations' });
  } catch (error) {
    dangerError.value = operationErrorText(error, '操作未完成，请重试');
  } finally { dangerBusy.value = false; }
}
async function conversationDelete(): Promise<void> {
  requestConversationDanger('delete');
}

async function conversationPullFromServer(): Promise<void> {
  if (route.name === "chat") {
    await sdk.syncActiveConversation();
    await sdk.runSyncOperation("read");
    return;
  }
  await sdk.syncConversationsFromServer();
}

async function chatEnterLoadAndMarkRead(): Promise<void> {
  await conversationPullFromServer();
}

async function runActiveConversationAction(kind: string): Promise<void> {
  if (!sdk.activeConversationId.value) return;
  if (kind === "delete") {
    await conversationDelete();
  } else if (kind === 'clear_history') {
    requestConversationDanger('clear_history');
  } else {
    await sdk.runConversationOperation(kind);
  }
  moreOpen.value = false;
}

async function searchMessages(): Promise<void> {
  const own = ++searchGeneration;
  const query = chatSearchQuery.value.trim();
  chatSearchLoading.value = false;
  chatSearchError.value = "";
  chatSearchSearched.value = Boolean(query);
  if (!query) {
    await sdk.searchActiveMessages("", []);
    return;
  }
  if (!sdk.activeConversationId.value) {
    chatSearchError.value = t("workbench.selectOneConvFirst");
    return;
  }
  chatSearchLoading.value = true;
  chatSearchLastQuery.value = query;
  chatSearchLastKind.value = chatSearchKind.value;
  try {
    await sdk.searchActiveMessages(query, selectedChatSearchKinds());
  } catch (error) {
    if (own === searchGeneration) chatSearchError.value = searchErrorText(error);
  } finally {
    if (own === searchGeneration) chatSearchLoading.value = false;
  }
}

function selectedChatSearchKinds(): MessageSearchKind[] {
  switch (chatSearchKind.value) {
    case "text":
      return [MessageSearchKind.Text];
    case "media":
      return [MessageSearchKind.Media];
    case "image":
      return [MessageSearchKind.Image];
    case "video":
      return [MessageSearchKind.Video];
    case "audio":
      return [MessageSearchKind.Audio];
    case "file":
      return [MessageSearchKind.File];
    default:
      return [MessageSearchKind.Message];
  }
}

function operationErrorText(error: unknown, fallback: string): string {
  // 直接透 error.message 会把核心的错误文本甩给用户；按 SDK 失败的 i18n key 出文案。
  return describeSdkError(error, fallback);
}

function searchErrorText(error: unknown): string {
  return operationErrorText(error, t("workbench.searchUnavailable"));
}

async function buildFromAction(op: string): Promise<void> {
  try {
    await sdk.buildFromComposerAction(op, "");
    sdkBuildOpen.value = false;
  } catch (error) {
    message.error(operationErrorText(error, t("toast.sendFailed")));
  }
}
</script>

<template>
  <FlareDangerConfirm :open="Boolean(dangerOperation)"
    :title="dangerOperation?.kind === 'delete' ? '删除会话' : '清空聊天记录'"
    description="请确认操作对象。此操作会更改会话或聊天记录。"
    :target="dangerOperation?.target || ''" :busy="dangerBusy" :error="dangerError"
    :confirm-text="dangerOperation?.kind === 'delete' ? '删除会话' : '清空记录'"
    @confirm="confirmConversationDanger" @cancel="dangerOperation = undefined" />
  <WorkbenchShell
    v-model:more-open="moreOpen"
    v-model:chat-search-open="chatSearchOpen"
    v-model:sdk-build-open="sdkBuildOpen"
    v-model:preview-open="previewOpen"
    :mode="shellMode"
    :more-title="moreDrawerTitle"
    :more-action-count="moreActionCount"
    :message-unread-count="sdk.totalUnread.value"
    :navigation-label="t('workbench.navigationLabel')"
    :messages-label="t('nav.conversations')"
    :lab-label="t('nav.sdkLab')"
    :logout-label="t('common.logout')"
    @navigate-messages="navigate('conversations')"
    @navigate-lab="navigate('sdk-lab')"
    @logout="logout"
  >
    <template #conversation>
      <router-view name="conversation" />
    </template>

    <template #main>
      <router-view name="main" />
    </template>

    <template #details>
      <ConversationDetails
        :conversation="sdk.activeConversation.value"
        :connection-text="connectionText"
        :tone="detailsTone"
        :message-count="sdk.messages.value.length"
        :latest-message-id="sdk.activeLatestMessageId.value"
        @sync="chatEnterLoadAndMarkRead"
        @mark-read="sdk.runSyncOperation('read')"
        @mark-unread="sdk.runConversationOperation('mark_unread')"
        @pin="(pinned) => sdk.runConversationOperation(pinned ? 'pin' : 'unpin')"
        @mute="(muted) => sdk.runConversationOperation(muted ? 'mute' : 'unmute')"
        @archive="(archived) => sdk.runConversationOperation(archived ? 'archive' : 'unarchive')"
        @clear-history="requestConversationDanger('clear_history')"
        @delete="conversationDelete"
        @open-devtools="navigate('sdk-lab')"
      />
    </template>

    <template #more>
      <section v-if="route.name === 'conversations'" class="account-sheet-header">
        <div class="account-avatar">{{ sdk.form.userId.slice(0, 1).toUpperCase() }}</div>
        <div>
          <span>{{ t('workbench.account') }}</span>
          <strong>{{ sdk.form.userId }}</strong>
        </div>
        <FlareStatusBanner :tone="detailsTone" :text="connectionText" />
      </section>
      <div class="more-action-list">
        <button v-if="route.name === 'conversations'" type="button" @click="startChatOpen = true; moreOpen = false">
          <AppIcon :icon="AddOutline" /> {{ t('workbench.newChat') }}
        </button>
        <button v-if="route.name === 'chat'" type="button" @click="chatSearchOpen = true; moreOpen = false">
          <AppIcon :icon="SearchOutline" /> {{ t('workbench.searchMessages') }}
        </button>
        <button v-if="route.name === 'conversations'" type="button" @click="conversationPullFromServer(); moreOpen = false">
          <AppIcon :icon="SyncOutline" /> {{ t('workbench.pullFromServer') }}
        </button>
        <button v-if="route.name === 'chat'" type="button" @click="chatEnterLoadAndMarkRead(); moreOpen = false">
          <AppIcon :icon="SyncOutline" /> {{ t('workbench.syncAndMarkRead') }}
        </button>
      </div>
      <div v-if="route.name === 'chat' && activeConversation" class="more-action-list more-action-list--grouped">
        <button type="button" @click="runActiveConversationAction(activeConversationUnread ? 'mark_read' : 'mark_unread')">
          <AppIcon :icon="activeConversationUnread ? CheckmarkDoneOutline : MailUnreadOutline" />
          {{ activeConversationUnread ? t('conversation.markRead') : t('conversation.markUnread') }}
        </button>
        <button type="button" @click="runActiveConversationAction(activeConversationPinned ? 'unpin' : 'pin')">
          <AppIcon :icon="PinOutline" /> {{ activeConversationPinned ? t('conversation.unpin') : t('workbench.pinConv') }}
        </button>
        <button type="button" @click="runActiveConversationAction(activeConversationMuted ? 'unmute' : 'mute')">
          <AppIcon :icon="NotificationsOffOutline" /> {{ activeConversationMuted ? t('conversation.unmute') : t('conversation.mute') }}
        </button>
        <button type="button" @click="runActiveConversationAction(activeConversationArchived ? 'unarchive' : 'archive')">
          <AppIcon :icon="ArchiveOutline" /> {{ activeConversationArchived ? t('conversation.unarchive') : t('workbench.archiveConv') }}
        </button>
        <button type="button" @click="runActiveConversationAction('clear_history')">
          <AppIcon :icon="TrashOutline" /> {{ t('conversation.clearHistory') }}
        </button>
        <button type="button" class="more-action-danger" @click="runActiveConversationAction('delete')">
          <AppIcon :icon="TrashOutline" /> {{ t('conversation.delete') }}
        </button>
      </div>
      <div class="more-action-list more-action-list--grouped">
        <button type="button" @click="navigate('sdk-lab'); moreOpen = false">
          <AppIcon :icon="InformationCircleOutline" /> {{ t('workbench.sdkRuntimeStatus') }}
        </button>
        <button type="button" @click="settingsOpen = true; moreOpen = false">
          <AppIcon :icon="SettingsOutline" /> {{ t("nav.settings") }}
          <span v-if="updates.badge.value" class="more-action-dot" role="img" :aria-label="t('settingsRow.badge')" />
        </button>
        <button type="button" class="more-action-danger" @click="logout(); moreOpen = false">
          <AppIcon :icon="LogOutOutline" /> {{ t('common.logout') }}
        </button>
      </div>
    </template>

    <template #chat-search>
      <section class="chat-search-panel">
        <fieldset class="chat-search-panel__field" :disabled="!sdk.activeConversationId.value">
          <FlareSearchBar
            v-model="chatSearchQuery"
            :loading="chatSearchLoading"
            :placeholder="t('workbench.searchChatHistory')"
            @submit="chatSearchCanSubmit && searchMessages()"
          />
          <FlareIconButton
            :icon="SearchOutline"
            :ariaLabel="locale.startsWith('en') ? 'Search' : '搜索'"
            variant="solid"
            :disabled="!chatSearchCanSubmit"
            @click="searchMessages"
          />
        </fieldset>
        <FlareFilterTabs
          :model-value="chatSearchKind"
          :options="chatSearchKindOptions"
          layout="wrap"
          :aria-label="t('workbench.searchTypeAria')"
          @change="selectChatSearchKind($event as ChatSearchKindValue)"
        />
        <FlareEmptyState v-if="!sdk.activeConversationId.value"
          :title="t('workbench.noConvSelected')" :description="t('workbench.searchNoContent')" />
        <FlareStatusBanner v-else-if="chatSearchError" :text="chatSearchError" tone="danger"
          :action-text="locale.startsWith('en') ? 'Retry' : '重新搜索'" @action="searchMessages" />
        <FlareStatusBanner v-else-if="chatSearchLoading" :text="t('workbench.searchingTitle')" pulse />
        <FlareEmptyState v-else-if="!chatSearchSearched"
          :title="t('workbench.searchCurrentConvTitle')" :description="t('workbench.searchStartHint')" />
        <FlareSearchResults v-else :groups="chatSearchGroups" :query="chatSearchLastQuery" @open="openSearchItem" />
      </section>
    </template>

    <template #sdk-build>
      <ComposerActionPanel @action="buildFromAction($event.id)" />
      <DeveloperConsole
        class="sdk-build-console"
        :diagnostics-text="diagnosticsText"
        :lab-result-text="labResultText"
        :lab-busy="sdk.labBusy.value"
        :build-options="sdk.messageBuildOptions.value"
        :dispatch-options="sdk.messageDispatchOptions"
        :sdk-lab="sdk.sdkLab"
        :events="sdk.events.value"
        @session="sdk.runSessionDiagnostics"
        @events="sdk.runEventOperation"
        @open-peer="sdk.openPeerConversation"
        @build-send="sdk.buildAndSendMessage()"
        @dispatch="sdk.runDispatch()"
        @conversation="sdk.runConversationOperation"
        @sync="sdk.runSyncOperation"
        @presence="sdk.runPresenceOperation"
        @media="sdk.runMediaOperation"
        @capability="sdk.runCapabilityOperation"
      />
    </template>

    <template #preview>
      <MessagePreviewModal :message="previewMessage" />
    </template>
  </WorkbenchShell>

  <FlareStartConversationDialog
    v-model:open="startChatOpen"
    v-model:peer-user-id="startPeerUserId"
    v-model:conversation-type="startConversationType"
    :busy="sdk.labBusy.value"
    @confirm="conversationOpenChat"
  />

  <FlareFormSheet :open="settingsOpen" :title="t('nav.settings')" @close="settingsOpen = false" @confirm="settingsOpen = false">

      <FlareFormField :label="t('workbench.themeMode')">
        <FlareSelect
          :model-value="themeModeValue" @update:model-value="themeModeValue = $event as FlareThemeMode"
          :options="[
            { label: t('workbench.themeOpt.system'), value: 'system' },
            { label: t('workbench.themeOpt.light'), value: 'light' },
            { label: t('workbench.themeOpt.dark'), value: 'dark' },
          ]"
        />
      </FlareFormField>
      <FlareFormField :label="t('workbench.themeVariant')">
        <FlareSelect
          :model-value="themeVariantValue" @update:model-value="themeVariantValue = $event as FlareThemeVariant"
          :options="[
            { label: t('workbench.variantOpt.default'), value: 'default' },
            { label: t('workbench.variantOpt.compact'), value: 'compact' },
            { label: t('workbench.variantOpt.callDark'), value: 'callDark' },
            { label: t('workbench.variantOpt.highContrast'), value: 'highContrast' },
          ]"
        />
      </FlareFormField>
      <FlareFormField :label="t('workbench.language')">
        <FlareSelect
          :model-value="localeValue" @update:model-value="localeValue = $event as FlareLocale"
          :options="[
            { label: '简体中文', value: 'zh-CN' },
            { label: 'English', value: 'en-US' },
          ]"
        />
      </FlareFormField>
      <FlareButton variant="secondary" block @click="settingsOpen = false; router.push({ name: 'network' })">
        {{ t("accessDiagnostics.title") }}
      </FlareButton>
      <FlareSettingsList :sections="aboutSections" @select="settingsOpen = false; router.push({ name: 'about' })" />
      <FlareFormField :label="t('workbench.downloadLocation')">
        <div class="workbench-storage-row">
          <span class="workbench-storage-value">{{ downloadLocationText }}</span>
          <FlareButton v-if="downloadLocation?.canPick" size="sm" variant="secondary" @click="chooseDownloadLocation">
            {{ t("workbench.downloadLocationChange") }}
          </FlareButton>
          <FlareButton v-if="downloadLocation?.isCustom" size="sm" variant="ghost" @click="useDefaultDownloadLocation">
            {{ t("workbench.downloadLocationReset") }}
          </FlareButton>
        </div>
      </FlareFormField>
      <FlareFormField :label="t('workbench.mediaCache')">
        <div class="workbench-storage-row">
          <span class="workbench-storage-value">{{ mediaCacheText }}</span>
          <FlareButton size="sm" variant="secondary" :disabled="!mediaCacheSize" @click="clearCacheOpen = true">
            {{ t("workbench.clearCache") }}
          </FlareButton>
        </div>
      </FlareFormField>
  </FlareFormSheet>
  <FlareDangerConfirm
    :open="clearCacheOpen"
    :title="t('workbench.clearCache')"
    :description="t('workbench.clearCacheConfirm')"
    :target="t('workbench.mediaCache')"
    :confirm-text="t('workbench.clearCache')"
    :busy="clearingCache"
    @confirm="confirmClearCache"
    @cancel="clearCacheOpen = false"
  />
</template>

<style scoped src="../styles/chat-search.css"></style>
<style scoped>
.workbench-storage-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--flare-size-spacing-sm);
}

.workbench-storage-value {
  flex: 1 1 12rem;
  min-width: 0;
  overflow-wrap: anywhere;
  color: var(--flare-color-text-secondary);
}

/* The dot of the settings row inside, on the way there: this menu's buttons are drawn here, not by the kit. */
.more-action-dot {
  display: inline-block;
  flex: none;
  width: var(--flare-size-spacing-sm);
  height: var(--flare-size-spacing-sm);
  margin-inline-start: var(--flare-size-spacing-xs);
  border-radius: var(--flare-size-radius-full);
  background: var(--flare-color-error);
}
</style>
