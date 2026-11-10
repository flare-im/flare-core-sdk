import { validSearchTimeRange, type FlareSearchTimeRange } from "@flare-im/vue-ui/contracts";
import { computed, onBeforeUnmount, reactive, readonly, ref, shallowRef, watch } from "vue";
import { translateFlare } from "@flare-im/vue-ui/i18n";
import type {
  AudioContentPayload,
  ConnectionStatus,
  Conversation,
  FileContentPayload,
  FlareImClient,
  ImageGroupContentPayload,
  ImageContentPayload,
  Message,
  MessageBuildCatalogEntry,
  MessageContent,
  MessageSendCallback,
  MessageSearchKind,
  ReactionEntry,
  SendMessageResponse,
  SdkConfig,
  VideoContentPayload,
  ViewUpdate,
  WebFlareImClient,
} from "@flare-im/sdk/web";
import {
  FlareSdkException,
  MessageBuildOp,
  MessageContentType,
  conversationFromJson,
} from "@flare-im/sdk/web";
import {
  bindFlareSessionEvents,
  reportSdkError,
  type IncomingMessageHint,
  type PresenceChangedHint,
  type ReactionChangedHint,
} from "./useFlareSessionBridge";
import {
  emitDesktopNotification,
  setDesktopUnreadCount,
  type DesktopNotificationKind,
} from "../app/infrastructure/desktop/desktopNotifications";
import { FlareConnectionRefresh, withTimeout } from "@flare-im/vue-ui/utils";

/**
 * What the sign-in page collects. Where to connect is not here: it is the build's access configuration
 * (`UseFlareCoreClientOptions.sdkConfig`).
 */
export interface LoginFormState {
  userId: string;
  /** A connect token the host already holds (app-hosted); empty lets the SDK issue and renew one (SDK-managed). */
  token: string;
  dataUrl: string;
  tenantId: string;
}

export type SdkRuntimeStatus = "browser-wasm" | "browser-unavailable" | "tauri-native" | "electron-native" | "uni-native";

export interface LoginIdentity {
  userId: string;
  tenantId: string;
}

export interface RuntimeEventLogItem {
  id: number;
  label: string;
  detail: string;
  at: number;
}

export interface HomeSyncProgress {
  step: "idle" | "session" | "conversations" | "unread" | "history" | "preview" | "ready" | "failed";
  title: string;
  detail: string;
  percent: number;
}

export interface SdkLabState {
  buildOp: string;
  dispatchOp: string;
  messageText: string;
  messageId: string;
  query: string;
  peerUserId: string;
  userIds: string;
  fileId: string;
  reaction: string;
  capability: string;
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
}

export type ConversationFilter = "all" | "unread" | "mention" | "pinned" | "muted" | "archived" | "draft";
type ConversationRefreshOptions = { silent?: boolean };
type MessageRefreshOptions = { silent?: boolean };
type LoadOlderMessagesOptions = { force?: boolean; limit?: number };

type BuildAndSendMessageRequest = {
  conversationId: string;
  op: MessageBuildOp | string;
  params?: Record<string, unknown>;
  callback?: MessageSendCallback;
};

type CoreSessionSnapshot = {
  initialized: boolean;
  loggedIn: boolean;
  userId: string;
  connectionStatus: ConnectionStatus;
};

type CoreDiagnosticsSnapshot = {
  sdkVersion: Record<string, unknown>;
  ffiContract: Record<string, unknown>;
  dataRoot: Record<string, unknown>;
  runtimeHealth: Record<string, unknown>;
  currentUser: unknown;
  sessionActive: boolean;
  isConnected: boolean;
  connectionStatus: ConnectionStatus;
};

type ViewDeltaPayload = NonNullable<ViewUpdate["delta"]>;
type ViewDeltaOperation = NonNullable<ViewDeltaPayload["ops"]>[number];

export interface ConversationFilterState {
  filter: ConversationFilter;
  includeArchived: boolean;
  conversationType: string;
}

// 会话打开/翻页一次取多少条。开窗越小，打开时主线程上的 WASM 取数(IndexedDB 读+protobuf 解码)
// 与 Vue 渲染(每条 MessageBubble ~4ms)成正比越少 → 打开更流畅(符合"首屏 <200ms"预算)。
// 更早的历史按需经 load-older(已验证可用)增量补齐,不丢可回溯性。
const MESSAGE_PAGE_SIZE = 40;
// 单次回填读多少条。这个值决定了用户发送的**最坏等待**：桥接层已把后台读降级到
// 交互操作之后，但正在执行的那一次不会被打断，所以发送最多要等一次回填读完。
//
// 实测单次耗时与条数大致成正比（~96 条约 600ms，即 ~6ms/条：IndexedDB 读 +
// protobuf 解码 + 视图装配）。所以把**单次**切小、页数相应加大，总量不变而
// 最坏等待成比例下降 —— 200→100 时上屏 635→362ms（同期还降级了 mark_read）。
const INITIAL_HISTORY_REPAIR_SYNC_LIMIT = 50;
// 打开会话时最多同步补几页历史。总量 = 页数 × 单页，目标 200 条左右：
// 够撑起滚动，再往前交给 load-older 懒加载。
//
// 原值 8 页 × 200 = 最多 1600 条。WASM 的 invoke 是单槽 FIFO，这些批量读把链子
// 占满，用户开完会话的第一次发送只能排队：实测 Enter→上屏 1299ms，
// 而链子空闲时同样的发送只要 52ms。
//
// 现在拆成「页数多、单页小」：总量不变，但**单次**耗时短，而单次耗时正是
// 用户发送的最坏等待（正在执行的调用不会被打断）。
const INITIAL_HISTORY_REPAIR_MAX_PAGES = 4;
const FULL_HISTORY_BACKFILL_SYNC_LIMIT = 500;
const FULL_HISTORY_BACKFILL_MAX_PAGES_PER_CALL = 2;
const FULL_HISTORY_BACKFILL_MAX_ROUNDS = 128;
const HISTORY_BACKFILL_CONVERSATION_TIMEOUT_MS = 30_000;
const REALTIME_SAFETY_POLL_INTERVAL_MS = 12_000;
const REALTIME_SAFETY_POLL_BACKOFF_BASE_MS = 8_000;
const REALTIME_SAFETY_POLL_BACKOFF_MAX_MS = 60_000;
const REALTIME_SAFETY_POLL_AFTER_SEND_QUIET_MS = 30_000;
const INCOMING_CONVERSATION_REFRESH_DEBOUNCE_MS = 120;
// 活动会话的"事件提示"对账(syncConversation + 时间线重读)去抖窗口:实时显示由 core 观察视图增量
// (applyTimelineViewDelta)负责;此对账仅作安全网,合并消息突发为一次,避免每条消息全量重开时间线的抖动风暴。
const ACTIVE_CONVERSATION_REFRESH_DEBOUNCE_MS = 500;

export interface UseFlareCoreClientOptions {
  /** Host-provided client factory (e.g. web WASM bridge). */
  createClient: () => FlareImClient;
  /** Host environment record (e.g. Vite `import.meta.env`): sign-in defaults only, never an address. */
  env?: Record<string, string | undefined>;
  /**
   * The SDK configuration this build connects with: the access configuration (signed seed or development
   * endpoints) and the host's own settings such as a private CA. Throws when the build has none; the sign-in page
   * then says so and offers no sign-in.
   */
  sdkConfig: () => SdkConfig;
  /** Host runtime label for diagnostics and login status. */
  runtimeStatus?: SdkRuntimeStatus;
}

/**
 * 归档筛选的取舍：只保留已归档的会话。
 *
 * SDK 侧只有 `includeArchived`，语义是"额外带上归档会话"而不是"只要归档会话"。
 * 拿它当归档筛选用，列表会原样返回全部——筛选看起来生效了（高亮切了），
 * 内容却一条没少。没有 archivedOnly 查询可用，只能取回后自己收窄。
 */
export function keepArchivedConversations<T extends { isArchived?: boolean }>(
  conversations: readonly T[],
): T[] {
  return conversations.filter((conversation) => Boolean(conversation.isArchived));
}

export function readLoginEnvText(value: string | undefined, fallback: string): string {
  const normalized = String(value ?? "").trim();
  return normalized || fallback;
}

export function normalizeLoginIdentityForSdk(input: Pick<LoginFormState, "userId" | "tenantId">): LoginIdentity {
  const userId = String(input.userId ?? "").trim();
  if (!userId) {
    throw new Error("userId is required");
  }
  const tenantId = String(input.tenantId ?? "").trim() || "0";
  return { userId, tenantId };
}

export function presenceStatusFromCoreDto(input: unknown): string {
  const status = readStringField(input, "status");
  if (status) return status;
  const isOnline = readBooleanField(input, "isOnline");
  if (isOnline !== undefined) return isOnline ? "online" : "offline";
  return "offline";
}

function readStringField(input: unknown, field: string): string {
  if (!input || typeof input !== "object") return "";
  const value = (input as Record<string, unknown>)[field];
  return typeof value === "string" ? value.trim() : "";
}

function readBooleanField(input: unknown, field: string): boolean | undefined {
  if (!input || typeof input !== "object") return undefined;
  const value = (input as Record<string, unknown>)[field];
  return typeof value === "boolean" ? value : undefined;
}

function makeFormDefaults(env: Record<string, string | undefined>): LoginFormState {
  return {
    userId: readLoginEnvText(env.VITE_FLARE_USER_ID, ""),
    token: "",
    dataUrl: readLoginEnvText(env.VITE_FLARE_DATA_URL, ""),
    tenantId: readLoginEnvText(env.VITE_FLARE_TENANT_ID, "0"),
  };
}

/**
 * 热启动会话档案：登录成功后持久化，下次启动免登录直接
 * prepare(本地库) → 本地出图 → 后台 connect，实现秒级热启动。
 * 示例应用用 localStorage 存 dev token；生产应用应换安全存储。
 */
export interface SavedSessionProfile {
  userId: string;
  tenantId: string;
  /** Empty for an SDK-managed session: the SDK issues a new connect token when it resumes. */
  token: string;
  dataUrl: string;
  savedAtMs: number;
}

const SAVED_SESSION_STORAGE_KEY = "flare-core:saved-session:v1";

function savedSessionStorage(): Storage | undefined {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      return window.localStorage;
    }
  } catch {
    // storage 被禁用（隐私模式等）时静默降级为无热启动
  }
  return undefined;
}

export function loadSavedSessionProfile(): SavedSessionProfile | undefined {
  const storage = savedSessionStorage();
  if (!storage) return undefined;
  try {
    const raw = storage.getItem(SAVED_SESSION_STORAGE_KEY);
    if (!raw) return undefined;
    const parsed = JSON.parse(raw) as Partial<SavedSessionProfile>;
    const userId = String(parsed.userId ?? "").trim();
    // SDK 托管登录(只输 user id)存下的 token 恒为空:恢复时由 SDK 重新签发,所以空 token 照样热启动。
    // 连到哪里不在档案里:那是构建期的接入配置。
    if (!userId) return undefined;
    return {
      userId,
      tenantId: String(parsed.tenantId ?? "").trim() || "0",
      token: String(parsed.token ?? "").trim(),
      dataUrl: String(parsed.dataUrl ?? "").trim(),
      savedAtMs: Number(parsed.savedAtMs) || 0,
    };
  } catch {
    return undefined;
  }
}

export function persistSavedSessionProfile(profile: SavedSessionProfile): void {
  const storage = savedSessionStorage();
  if (!storage) return;
  try {
    storage.setItem(SAVED_SESSION_STORAGE_KEY, JSON.stringify(profile));
  } catch {
    // 配额满等写失败只影响下次热启动，不影响本次会话
  }
}

export function clearSavedSessionProfile(): void {
  const storage = savedSessionStorage();
  if (!storage) return;
  try {
    storage.removeItem(SAVED_SESSION_STORAGE_KEY);
  } catch {
    // 与写失败同理
  }
}

const sdkLabDefaults: SdkLabState = {
  buildOp: "create_text",
  dispatchOp: "search",
  messageText: "",
  messageId: "",
  query: "",
  peerUserId: "",
  userIds: "",
  fileId: "",
  reaction: "👍",
  capability: "",
  mediaUrl: "",
  mediaCacheRoot: "memory://flare-core-web-app/media-cache",
  mediaCacheMaxBytes: 134217728,
  downloadSubfolder: "flare-im",
  downloadKey: "",
  displayFileName: "",
  sourcePath: "",
  sourceUrl: "",
  remoteFileId: "",
  heartbeatNatTimeoutSecs: 60,
  tokenTtlSecs: 3600,
  draft: "",
  jsonParams: "{}",
};

const sdkEventSources = [
  "lifecycle",
  "connection",
  "access",
  "update",
  "message",
  "conversation",
  "sync",
  "presence",
  "media",
  "capability",
  "view",
] as const;

const messageDispatchOptions = [
  { label: "Search", value: "search" },
  { label: "Search In Conversation", value: "search_in_conversation" },
  { label: "Get", value: "get" },
  { label: "Get Raw", value: "get_raw" },
  { label: "Edit Text", value: "edit_text_by_message_id" },
  { label: "Edit Rich Doc", value: "edit_rich_doc_by_message_id" },
  { label: "Delete Self", value: "delete_for_self" },
  { label: "Delete Everyone", value: "delete_for_everyone" },
  { label: "Add Reaction", value: "add_reaction" },
  { label: "Remove Reaction", value: "remove_reaction" },
  { label: "Pin Message", value: "pin_by_message_id" },
  { label: "Unpin Message", value: "unpin_by_message_id" },
  { label: "Mark Important", value: "mark_by_message_id" },
  { label: "Mark With Color", value: "mark_with_color" },
  { label: "Unmark", value: "unmark_by_message_id" },
  { label: "Typing", value: "typing" },
  { label: "Mark Read", value: "mark_read" },
  { label: "Mark Read And Burn", value: "mark_read_and_burn" },
];

export { getMessageText } from "@flare-im/vue-ui/utils";

const timelineRefreshingDispatchOps = new Set([
  "edit_text_by_message_id",
  "edit_rich_doc_by_message_id",
  "delete_for_self",
  "delete_for_everyone",
  "add_reaction",
  "remove_reaction",
  "pin_by_message_id",
  "unpin_by_message_id",
  "mark_by_message_id",
  "mark_with_color",
  "unmark_by_message_id",
  "mark_read",
  "mark_read_and_burn",
]);

export function shouldRefreshTimelineAfterDispatch(op: string): boolean {
  return timelineRefreshingDispatchOps.has(op);
}

/** proto `MarkType`：0=UNSPECIFIED, 1=IMPORTANT, 2=TODO, 3=DONE, 4=CUSTOM。 */
export const MARK_TYPE_IMPORTANT = 1;

/** 标记默认色。核心侧要求 color 非空字符串，调用方不关心颜色时用它兜底。 */
export const DEFAULT_MARK_COLOR = "#F5A623";

export function buildMessageDispatchParams(input: {
  conversationId: string;
  messageId: string;
  text?: string;
  keyword?: string;
  emoji?: string;
  markType?: number;
  color?: string;
  jsonParams?: Record<string, unknown>;
}): Record<string, unknown> {
  return {
    conversationId: input.conversationId,
    messageId: input.messageId,
    clientMsgId: input.messageId,
    text: input.text ?? "",
    keyword: input.keyword ?? "",
    emoji: input.emoji ?? "",
    // 标记类操作的契约是 messageId + markType(i32) + color(string)，
    // 见 bindings/shared 的 mark_by_message_id 分支。此前这里两个都不产出，
    // 只能靠 SDK Lab 的自由 JSON 补，于是消息右键菜单里的"标记"必然失败，
    // 报 INVALID_PARAMETER。markType 走 json_i32，写成字符串同样会被拒。
    markType: input.markType ?? MARK_TYPE_IMPORTANT,
    color: input.color ?? DEFAULT_MARK_COLOR,
    ...(input.jsonParams ?? {}),
  };
}

function parseJsonParams(source: string): Record<string, unknown> {
  const raw = source.trim();
  if (!raw) return {};
  try {
    const value = JSON.parse(raw);
    return value && typeof value === "object" && !Array.isArray(value) ? value : {};
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    throw new Error(`jsonParams must be a valid JSON object: ${detail}`);
  }
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

const devTokenDefaults = {
  issuer: "flare-im-core",
  ttlSecs: 3600,
};

// 发送交接的防御性安全网：远长于核心 reliable_queue 的 ~40s 终态窗口，仅用于兜底 settle-as-pending，
// 不作为失败判据（失败只由核心 SendFailed 事件或 sendMessage 同步 reject 决定）。
const SEND_PENDING_SAFETY_MS = 90_000;
const HOME_CONVERSATION_LOAD_TIMEOUT_MS = 8_000;
const STARTUP_HOME_SYNC_TIMEOUT_MS = 8_000;
const SYNC_CONVERSATION_SUMMARIES_TIMEOUT_MS = 8_000;
const CONVERSATION_LIST_VIEW_OPEN_TIMEOUT_MS = 8_000;
const LOGIN_SESSION_RESET_TIMEOUT_MS = 3_000;
// 冷启动登录的绝大部分时间是取 WASM，而不是登录本身。
//
// bridge 的 ensureRuntime 是懒初始化：首个 invoke 触发下载 4.7MB（gzip 后
// 1.55MB）的 wasm，这段时间全记在 login.init 名下。实测把它拆开看：
//   链路 ~40KB/s 时，wasm 单独就要 34s，login.init 之外的部分不到 1s。
// 也就是说这个死线量的是**用户网速**，不是服务端或客户端的处理耗时。
//
// 8s 的旧值只够 200KB/s 以上的链路。慢一点就随机失败，而失败时客户端一个
// 网络包都没发出去（连接建立在 wasm 之后），表象是「服务端不可达」，
// 真因是自己的死线先到期 —— 这个误导性极强，排查时绕了很久。
//
// 不要用「先热身再登录」绕开：init 前可用的操作有限，拿 diagnostics 去热
// 会一直等到 client.init() 返回，而 init 排在热身之后，直接自锁
// （实测总耗时从 9.1s 恶化到 33.5s）。
const CORE_LOGIN_STEP_TIMEOUT_MS = 30_000;
const CORE_LOGIN_TIMEOUT_MS = 120_000;
const TIMELINE_OPEN_TIMEOUT_MS = 10_000;
const MESSAGE_SYNC_TIMEOUT_MS = 12_000;

function stringDetails(details: Record<string, unknown>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(details).map(([key, value]) => [key, String(value ?? "")]),
  );
}

function sdkOperationTimeoutError(operation: string, timeoutMs: number): Error {
  const error = new Error(`${operation} timed out after ${timeoutMs}ms`);
  (error as Error & { code?: string; operation?: string }).code = "timeout";
  (error as Error & { code?: string; operation?: string }).operation = operation;
  return error;
}

function sendAckDetails(ack: SendMessageResponse): Record<string, string> {
  return {
    ackId: ack.ackId,
    clientMsgId: ack.clientMsgId,
    conversationId: ack.conversationId,
    errorCode: String(ack.errorCode),
    errorMessage: ack.errorMessage,
    seq: String(ack.seq),
    serverId: ack.serverId,
    success: String(ack.success),
    timestamp: String(ack.timestamp),
  };
}

function sendAckFailureError(ack: SendMessageResponse): Error {
  const message = ack.errorMessage || "message.send failed";
  const error = new Error(message);
  (error as Error & { code?: string; details?: SendMessageResponse }).code = String(ack.errorCode || "send_ack_failed");
  (error as Error & { code?: string; details?: SendMessageResponse }).details = ack;
  return error;
}

function isFinalSendAck(ack: SendMessageResponse): boolean {
  return ack.success === true && (ack.serverId.trim() !== "" || ack.seq > 0);
}

function isQueuedSendAck(ack: SendMessageResponse): boolean {
  return ack.success === false && ack.errorCode === 0 && ack.serverId.trim() === "" && ack.seq === 0;
}

function sendAckMatches(ack: SendMessageResponse, message: Message): boolean {
  const clientMsgId = message.clientMsgId.trim();
  if (clientMsgId && ack.clientMsgId === clientMsgId) return true;
  const serverId = message.serverId.trim();
  return Boolean(serverId && ack.serverId === serverId);
}

function sendAckFromEvent(event: unknown): SendMessageResponse | undefined {
  if (!event || typeof event !== "object") return undefined;
  const record = event as { ack?: unknown };
  return record.ack && typeof record.ack === "object"
    ? record.ack as SendMessageResponse
    : undefined;
}

function sendFailureFromEvent(event: unknown): { clientMsgId: string; reason: string } | undefined {
  if (!event || typeof event !== "object") return undefined;
  const record = event as { type?: unknown; event?: unknown; clientMsgId?: unknown; reason?: unknown; message?: unknown };
  const isSendFailedEnvelope = record.type === "message" && record.event === "send_failed";
  if (!isSendFailedEnvelope && record.clientMsgId === undefined) return undefined;
  const clientMsgId = typeof record.clientMsgId === "string" ? record.clientMsgId.trim() : "";
  if (!clientMsgId) return undefined;
  return {
    clientMsgId,
    reason: typeof record.reason === "string"
      ? record.reason
      : typeof record.message === "string"
        ? record.message
        : "message.send failed",
  };
}

function requiredStringParam(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  if (typeof value === "string" && value.trim()) return value;
  throw new Error(`${key} is required`);
}

function optionalStringParam(source: Record<string, unknown>, key: string): string | undefined {
  const value = source[key];
  return typeof value === "string" && value.trim() ? value : undefined;
}

function recordParam(source: Record<string, unknown>, key: string): Record<string, unknown> {
  const value = source[key];
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function optionalRecordParam<T extends object>(source: Record<string, unknown>, key: string): T | undefined {
  const value = recordParam(source, key);
  return Object.keys(value).length ? value as T : undefined;
}

function requiredNumberParam(source: Record<string, unknown>, key: string): number {
  const value = Number(source[key]);
  if (Number.isFinite(value)) return value;
  throw new Error(`${key} is required`);
}

function stringListParam(source: Record<string, unknown>, key: string): string[] {
  const value = source[key];
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean);
}

function stringMapParam(source: Record<string, unknown>, key: string): Record<string, string> | undefined {
  const value = recordParam(source, key);
  const entries = Object.entries(value)
    .map(([entryKey, entryValue]) => [entryKey, String(entryValue ?? "").trim()] as const)
    .filter(([, entryValue]) => entryValue);
  return entries.length ? Object.fromEntries(entries) : undefined;
}

function messageContentParam(source: Record<string, unknown>, key: string): MessageContent {
  const value = source[key];
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${key} is required`);
  }
  const content = value as Partial<MessageContent>;
  if (!content.contentType || !Object.values(MessageContentType).includes(content.contentType as MessageContentType)) {
    throw new Error(`${key}.contentType is invalid`);
  }
  return {
    contentType: content.contentType as MessageContentType,
    data: recordParam(value as Record<string, unknown>, "data"),
  };
}

function contentTypeParam(source: Record<string, unknown>): MessageContentType {
  const raw = requiredStringParam(source, "contentType");
  if (!Object.values(MessageContentType).includes(raw as MessageContentType)) {
    throw new Error("contentType is invalid");
  }
  return raw as MessageContentType;
}

export function desktopNotificationBodyForMessage(message: Message): string {
  switch (message.content?.contentType ?? messageContentTypeFromPreview(message.textPreview)) {
    case MessageContentType.Text:
      return translateFlare("notify.sent.text");
    case MessageContentType.Image:
      return translateFlare("notify.sent.image");
    case MessageContentType.ImageGroup:
      return translateFlare("notify.sent.imageGroup");
    case MessageContentType.Video:
      return translateFlare("notify.sent.video");
    case MessageContentType.Audio:
      return translateFlare("notify.sent.audio");
    case MessageContentType.File:
      return translateFlare("notify.sent.file");
    case MessageContentType.Sticker:
    case MessageContentType.Emoji:
      return translateFlare("notify.sent.emoji");
    case MessageContentType.Location:
      return translateFlare("notify.sent.location");
    case MessageContentType.Card:
      return translateFlare("notify.sent.card");
    case MessageContentType.Schedule:
      return translateFlare("notify.sent.schedule");
    case MessageContentType.Task:
      return translateFlare("notify.sent.task");
    case MessageContentType.Vote:
      return translateFlare("notify.sent.vote");
    case MessageContentType.Notification:
      return translateFlare("notify.sent.notification");
    case MessageContentType.Announcement:
      return translateFlare("notify.sent.announcement");
    case MessageContentType.RichText:
      return translateFlare("notify.sent.richText");
    case MessageContentType.LinkCard:
      return translateFlare("notify.sent.link");
    case MessageContentType.Forward:
      return translateFlare("notify.sent.forward");
    case MessageContentType.Thread:
      return translateFlare("notify.sent.thread");
    case MessageContentType.MiniProgram:
      return translateFlare("notify.sent.miniProgram");
    case MessageContentType.System:
      return translateFlare("notify.sent.system");
    case MessageContentType.Quote:
      return translateFlare("notify.sent.quote");
    default:
      return message.textPreview.trim() ? translateFlare("notify.sent.text") : translateFlare("notify.sent.generic");
  }
}

function messageContentTypeFromPreview(preview: string): MessageContentType | undefined {
  const key = storedPreviewKey(preview);
  switch (key) {
    case "im.preview.user_text":
      return MessageContentType.Text;
    case "im.preview.rich_text":
      return MessageContentType.RichText;
    case "im.preview.file":
      return MessageContentType.File;
    case "im.preview.image":
      return MessageContentType.Image;
    case "im.preview.video":
      return MessageContentType.Video;
    case "im.preview.audio":
      return MessageContentType.Audio;
    case "im.preview.location":
      return MessageContentType.Location;
    case "im.preview.card":
      return MessageContentType.Card;
    case "im.preview.sticker":
      return MessageContentType.Sticker;
    case "im.preview.emoji":
      return MessageContentType.Emoji;
    case "im.preview.quote":
      return MessageContentType.Quote;
    case "im.preview.link":
      return MessageContentType.LinkCard;
    case "im.preview.forward_empty":
    case "im.preview.forward_many":
      return MessageContentType.Forward;
    case "im.preview.thread":
      return MessageContentType.Thread;
    case "im.preview.mini_program":
      return MessageContentType.MiniProgram;
    case "im.preview.image_group":
      return MessageContentType.ImageGroup;
    case "im.preview.system":
      return MessageContentType.System;
    case "im.preview.notification":
      return MessageContentType.Notification;
    case "im.preview.vote":
      return MessageContentType.Vote;
    case "im.preview.task":
      return MessageContentType.Task;
    case "im.preview.schedule":
      return MessageContentType.Schedule;
    case "im.preview.announcement":
      return MessageContentType.Announcement;
    case "im.preview.custom":
      return MessageContentType.Custom;
    case "im.preview.placeholder":
      return MessageContentType.Placeholder;
    default:
      return undefined;
  }
}

function storedPreviewKey(preview: string): string {
  const trimmed = preview.trim();
  if (!trimmed.startsWith("{")) return "";
  try {
    const parsed = JSON.parse(trimmed) as unknown;
    if (!parsed || typeof parsed !== "object") return "";
    const key = (parsed as Record<string, unknown>).k;
    return typeof key === "string" ? key : "";
  } catch {
    return "";
  }
}

export function useFlareCoreClient(options: UseFlareCoreClientOptions) {
  const env = options.env ?? {};
  const defaultSdkRuntimeStatus = options.runtimeStatus ?? "browser-wasm";
  const appClient = options.createClient();
  const client = appClient;
  const form = reactive({ ...makeFormDefaults(env) });
  // A build without an access configuration cannot connect anywhere: the sign-in page says why and offers no sign-in.
  const accessConfigError = ref(sdkConfigProblem());
  const sdkLab = reactive({ ...sdkLabDefaults });
  const conversationFilters = reactive<ConversationFilterState>({
    filter: "all",
    includeArchived: false,
    conversationType: "",
  });

  const initialized = ref(false);
  const loggedIn = ref(false);
  const busy = ref(false);
  /**
   * The core's `connection://status`, whole as it arrives (null before the SDK has reported one). The app shell
   * hands it to the kit's `FlareConnectionNotice` unchanged; flows here read only its phase.
   */
  const connectionStatus = shallowRef<ConnectionStatus | null>(null);
  const connectionPhase = computed(() => connectionStatus.value?.phase ?? "idle");
  const currentUserId = ref("");
  const sessionActive = ref(false);
  const isConnected = ref(false);
  const homeSyncing = ref(false);
  const homeSyncReady = ref(false);
  const homeSyncError = ref("");
  const homeSyncProgress = ref<HomeSyncProgress>({
    step: "idle",
    title: translateFlare("sync.prepareTitle"),
    detail: translateFlare("sync.prepareDetail"),
    percent: 0,
  });
  const sdkRuntimeStatus = ref<SdkRuntimeStatus>(defaultSdkRuntimeStatus);
  const activeConversationId = ref("");
  const conversations = ref<Conversation[]>([]);
  const messages = ref<Message[]>([]);
  const messageSearchResults = ref<Message[]>([]);
  let activeSearchGeneration = 0;
  function invalidateActiveSearch(): void {
    activeSearchGeneration += 1;
    messageSearchResults.value = [];
  }
  watch([activeConversationId, currentUserId], invalidateActiveSearch, { flush: 'sync' });
  const diagnostics = ref<Record<string, unknown>>({});
  const events = ref<RuntimeEventLogItem[]>([]);
  const conversationSyncing = ref(false);
  const conversationSyncError = ref("");
  const messageSyncing = ref(false);
  const messageOpening = ref(false);
  const messageSyncError = ref("");
  const labBusy = ref(false);
  const labResult = ref<Record<string, unknown>>({});
  const activeConversation = ref<Conversation>();

  // Receive-side typing indicator. The Rust core aggregates inbound per-user typing into
  // TypingAggregate events (with TTL + auto-expiry), so here we only mirror the latest live
  // set per conversation; no client-side timer needed.
  const typingUsersByConversation = ref<Map<string, string[]>>(new Map());
  const activeConversationTypingUsers = computed<string[]>(() => {
    const list = typingUsersByConversation.value.get(activeConversationId.value) ?? [];
    const self = currentUserId.value;
    return self ? list.filter((id) => id !== self) : list;
  });
  const typingAggregateSub = client.events.onTypingAggregateChanged((event) => {
    const next = new Map(typingUsersByConversation.value);
    const ids = event.typingUserIds ?? [];
    if (ids.length > 0) {
      next.set(event.conversationId, ids);
    } else {
      next.delete(event.conversationId);
    }
    typingUsersByConversation.value = next;
  });
  onBeforeUnmount(() => typingAggregateSub.unsubscribe());
  const peerPresence = ref<Record<string, string>>({});
  const totalUnread = ref(0);
  const activeLatestMessageId = ref("");
  const pinnedMessages = ref<Message[]>([]);
  const messageBuildCatalog = ref<MessageBuildCatalogEntry[]>([]);
  const messageHasMore = ref(true);
  const loadingOlderMessages = ref(false);
  const messageBuildOptions = computed(() => {
    return messageBuildCatalog.value.map((entry) => ({
      label: `${entry.method} · ${entry.contentType}${entry.stability === "stable" ? "" : ` · ${entry.stability}`}`,
      value: String(entry.op),
    }));
  });

  // WASM 运行时预热：app 挂载（登录屏渲染）即后台加载+实例化 3.2MB 运行时，
  // 用户输入账号期间完成下载/编译，登录点击不再背 wasm 冷加载。
  // sdk.version 是无会话直连操作；失败静默（登录路径会正常重试加载）。
  if (typeof window !== "undefined") {
    void Promise.resolve()
      .then(() => client.diagnostics.getSdkVersion())
      .catch(() => {});
  }

  let eventId = 1;
  let messageOpeningTimer: ReturnType<typeof setTimeout> | undefined;
  // before expiry so the core always reconnects with a valid token instead of looping forever
  let tokenRefreshTimer: ReturnType<typeof setTimeout> | undefined;
  let pendingConversationSummarySync: Promise<void> | undefined;
  let conversationListViewId = "";
  // revision：已应用到 messages 的视图版本号。view.updated 按版本号逐次加 1 推来，跳号时取快照整体替换。
  let activeTimelineView: { conversationId: string; viewId: string; revision: number } | null = null;
  let markReadTimer: ReturnType<typeof setTimeout> | undefined;
  let markReadInFlight: Promise<void> | undefined;
  let realtimeSafetyPollTimer: number | undefined;
  let realtimeSafetyPollInFlight = false;
  let realtimeSafetyPollFailureCount = 0;
  let realtimeSafetyPollNextAt = 0;
  let lastOutgoingSendAt = 0;
  let incomingConversationRefreshTimer: number | undefined;
  let activeConversationRefreshTimer: number | undefined;
  let incomingConversationRefreshInFlight = false;
  let activeOutgoingSends = 0;
  const activeTimelineAtBottom = ref(true);
  const lastMarkedReadSeqByConversation = new Map<string, number>();
  const initialHistoryRepairTried = new Set<string>();

  function messageMatchesId(message: Message, id: string): boolean {
    return Boolean(id && (message.serverId === id || message.clientMsgId === id));
  }

  function isPinnedMessage(message: Message): boolean {
    return message.attributes?.pinned === "true";
  }

  function currentSnapshotReadSeq(conversationId: string): number {
    const conversationSeq = conversations.value.find((item) => item.conversationId === conversationId)?.maxSeq ?? 0;
    const messageSeq = messages.value
      .filter((message) => message.conversationId === conversationId)
      .reduce((max, message) => Math.max(max, Number(message.conversationSeq) || 0), 0);
    return Math.max(conversationSeq, messageSeq);
  }

  async function listConversations(options: {
    query?: string;
    includeArchived?: boolean;
    offset?: number;
    limit?: number;
  } = {}): Promise<readonly Conversation[]> {
    if (options.query) {
      const response = await client.conversations.listConversationsByQuery({
        keyword: options.query,
        includeArchived: options.includeArchived ?? false,
        unreadOnly: false,
        mentionMeOnly: false,
        pinnedOnly: false,
        hasDraftOnly: false,
        hasMarkedMessages: false,
        conversationTypes: [],
        limit: options.limit,
      });
      return response.conversations;
    }
    if (options.offset !== undefined || options.limit !== undefined) {
      const response = await client.conversations.listConversationsPaginated({
        offset: options.offset ?? 0,
        limit: options.limit ?? 50,
        includeArchived: options.includeArchived ?? false,
      });
      return response.conversations;
    }
    const response = options.includeArchived
      ? await client.conversations.listConversationsIncludingArchived()
      : await client.conversations.listConversations();
    return response.conversations;
  }

  async function bootstrapHome(conversationLimit = 100) {
    return await client.conversations.bootstrapHomeTimeline({ conversationLimit });
  }

  async function loadHomeConversations(conversationLimit = 100): Promise<Conversation[]> {
    try {
      const homeSnapshot = await withTimeout(
        Promise.resolve().then(() => bootstrapHome(conversationLimit)),
        HOME_CONVERSATION_LOAD_TIMEOUT_MS,
        () => sdkOperationTimeoutError("conversation.bootstrap_home", HOME_CONVERSATION_LOAD_TIMEOUT_MS),
      );
      return [...homeSnapshot.conversations];
    } catch (error) {
      log("home_bootstrap_degraded", errorMessage(error));
    }
    try {
      const fallbackConversations = await withTimeout(
        Promise.resolve().then(() => listConversations({ limit: conversationLimit })),
        HOME_CONVERSATION_LOAD_TIMEOUT_MS,
        () => sdkOperationTimeoutError("conversation.list", HOME_CONVERSATION_LOAD_TIMEOUT_MS),
      );
      return [...fallbackConversations];
    } catch (error) {
      log("home_conversations_degraded", errorMessage(error));
      return [...conversations.value];
    }
  }

  async function openPeerConversationRaw(peerUserId: string): Promise<Conversation> {
    return await client.conversations.getOneConversation({
      sourceId: peerUserId,
      conversationType: "single",
    });
  }

  async function openGroupConversationRaw(userIds: readonly string[]): Promise<Conversation> {
    return await client.conversations.getGroupConversationByUserIds({
      userIds: [...userIds],
    });
  }

  function parseGroupMemberIds(raw: string): string[] {
    const ids = raw
      .split(/[\s,，、;；|]+/)
      .map((id) => id.trim())
      .filter((id) => id.length > 0);
    const current = currentUserId.value.trim();
    if (current) {
      ids.unshift(current);
    }
    return [...new Set(ids)];
  }

  async function listMessages(request: {
    conversationId: string;
    beforeSeq?: number;
    limit?: number;
  }): Promise<readonly Message[]> {
    const response = await client.messages.listMessages({
      conversationId: request.conversationId,
      beforeSeq: request.beforeSeq ?? 0,
      limit: request.limit ?? MESSAGE_PAGE_SIZE,
    });
    return response.messages;
  }

  /**
   * 把一条消息交接给核心可靠发送管线，并反映核心的终态。
   *
   * 发送的权威生命周期归**核心** reliable_queue：乐观入队即返回、in-flight 跟踪、
   * 10s 单次 ack 超时 + 3 次幂等重试 + 每秒落库对账 + 迟到 ack 恢复，最终必落一个
   * 终态（`SendAck` 成功 / `SendFailed` 失败，生产窗口 ~40s）；且核心会把消息 store
   * 直接更新为 sent/failed（气泡经视图 delta 呈现，是唯一真相）。
   *
   * 因此这里**不再自建更短的失败死线**（历史上 30s 定时器会把一条 SendAck 下行帧丢/迟、
   * 但其实已投递的消息误报为失败）。promise 只在：核心**终态事件**（最终 SendAck→成功 /
   * SendFailed→失败）、或**同步 reject**（未登录/校验错等 `sendMessage` 本身失败）时 settle。
   * 另留一条远长于核心窗口的防御性安全网（`SEND_PENDING_SAFETY_MS`），仅在核心终态事件
   * 也丢失时 settle-as-pending（不判失败、不改气泡），避免调用方 await 泄漏。
   */
  async function sendMessageWithTimeout(
    message: Message,
    callback?: MessageSendCallback,
  ): Promise<SendMessageResponse> {
    return await new Promise<SendMessageResponse>((resolve, reject) => {
      let settled = false;
      let timeout: ReturnType<typeof setTimeout> | undefined;
      let subscription: { unsubscribe(): void } | undefined;

      const cleanup = () => {
        if (timeout) {
          clearTimeout(timeout);
          timeout = undefined;
        }
        subscription?.unsubscribe();
        subscription = undefined;
      };

      const fail = (error: Error, details: Record<string, unknown> = {}) => {
        if (settled) return;
        settled = true;
        cleanup();
        callback?.onFailure?.({
          clientMsgId: message.clientMsgId,
          reason: error.message,
          error: {
            code: (error as Error & { code?: string }).code ?? "send_failed",
            message: error.message,
            operation: "message.send",
            details: stringDetails(details),
          },
        });
        reject(error);
      };

      const succeed = (ack: SendMessageResponse) => {
        if (settled) return;
        settled = true;
        cleanup();
        callback?.onSuccess?.({ ack });
        resolve(ack);
      };

      // 防御性安全网：仅在核心终态事件也丢失时兜底。不调 onSuccess/onFailure、不改气泡，
      // 只 resolve 一个 pending 形态的 ack 解除调用方 await；气泡终态仍由核心 store→delta 呈现。
      const resolvePending = () => {
        if (settled) return;
        settled = true;
        cleanup();
        resolve({
          ackId: "",
          serverId: "",
          clientMsgId: message.clientMsgId,
          conversationId: message.conversationId,
          seq: 0,
          timestamp: Date.now(),
          success: false,
          errorCode: 0,
          errorMessage: "",
        });
      };

      subscription = client.events.addEventListener(((event: unknown) => {
        const ack = sendAckFromEvent(event);
        if (ack && sendAckMatches(ack, message)) {
          if (isFinalSendAck(ack)) {
            succeed(ack);
          } else if (!isQueuedSendAck(ack)) {
            fail(sendAckFailureError(ack), sendAckDetails(ack));
          }
          return;
        }
        const failure = sendFailureFromEvent(event);
        if (failure?.clientMsgId === message.clientMsgId) {
          fail(new Error(failure.reason), failure);
        }
      }) as never);

      // 防御性安全网：远长于核心 ~40s 窗口，仅在核心终态事件也丢失时 settle-as-pending。
      // 不再有独立的失败死线——失败只由核心 SendFailed 事件或同步 reject 决定。
      timeout = setTimeout(resolvePending, SEND_PENDING_SAFETY_MS);

      void client.messages.sendMessage({ message })
        .then((ack) => {
          if (settled) return;
          if (isFinalSendAck(ack)) {
            succeed(ack);
          } else if (!isQueuedSendAck(ack)) {
            fail(sendAckFailureError(ack), sendAckDetails(ack));
          }
        })
        .catch((error: unknown) => {
          const normalized = error instanceof Error ? error : new Error(String(error));
          fail(normalized);
        });
    });
  }

  async function buildTypedMessage(request: BuildAndSendMessageRequest): Promise<Message> {
    const params = request.params ?? {};
    const op = String(request.op);
    switch (op) {
      case MessageBuildOp.CreateText:
        return client.messageBuilder.buildText({
          conversationId: request.conversationId,
          text: requiredStringParam(params, "text"),
          mentionUsers: stringListParam(params, "mentionUsers"),
        });
      case MessageBuildOp.CreateEmoji:
        return client.messageBuilder.buildEmoji({
          conversationId: request.conversationId,
          emoji: requiredStringParam(params, "emoji"),
        });
      case MessageBuildOp.CreateSticker:
        return client.messageBuilder.buildSticker({
          conversationId: request.conversationId,
          stickerId: requiredStringParam(params, "stickerId"),
          packageId: optionalStringParam(params, "packageId"),
        });
      case MessageBuildOp.CreateImage:
        return client.messageBuilder.buildImage({
          conversationId: request.conversationId,
          imageId: requiredStringParam(params, "imageId"),
          payload: optionalRecordParam<ImageContentPayload>(params, "payload"),
        });
      case MessageBuildOp.CreateImageGroup:
        {
          const payload = recordParam(params, "payload") as Partial<ImageGroupContentPayload>;
          if (!Array.isArray(payload.images) || payload.images.length === 0) {
            throw new Error("payload.images is required");
          }
          return client.messageBuilder.buildImageGroup({
            conversationId: request.conversationId,
            payload: payload as ImageGroupContentPayload,
          });
        }
      case MessageBuildOp.CreateVideo:
        return client.messageBuilder.buildVideo({
          conversationId: request.conversationId,
          videoId: requiredStringParam(params, "videoId"),
          payload: optionalRecordParam<VideoContentPayload>(params, "payload"),
        });
      case MessageBuildOp.CreateAudio:
        return client.messageBuilder.buildAudio({
          conversationId: request.conversationId,
          audioId: requiredStringParam(params, "audioId"),
          payload: optionalRecordParam<AudioContentPayload>(params, "payload"),
        });
      case MessageBuildOp.CreateFile:
        return client.messageBuilder.buildFile({
          conversationId: request.conversationId,
          fileId: requiredStringParam(params, "fileId"),
          payload: optionalRecordParam<FileContentPayload>(params, "payload"),
        });
      case MessageBuildOp.CreateLocation:
        return client.messageBuilder.buildLocation({
          conversationId: request.conversationId,
          latitude: requiredNumberParam(params, "latitude"),
          longitude: requiredNumberParam(params, "longitude"),
          title: optionalStringParam(params, "title"),
          address: optionalStringParam(params, "address"),
        });
      case MessageBuildOp.CreateLinkCard:
        return client.messageBuilder.buildLinkCard({
          conversationId: request.conversationId,
          url: requiredStringParam(params, "url"),
          title: optionalStringParam(params, "title"),
          description: optionalStringParam(params, "description"),
          thumbnailUrl: optionalStringParam(params, "thumbnailUrl"),
          siteName: optionalStringParam(params, "siteName"),
        });
      case MessageBuildOp.CreateCard:
        return client.messageBuilder.buildCard({
          conversationId: request.conversationId,
          id: requiredStringParam(params, "id"),
          cardType: optionalStringParam(params, "cardType"),
          title: optionalStringParam(params, "title"),
          subtitle: optionalStringParam(params, "subtitle"),
          avatar: optionalStringParam(params, "avatar"),
        });
      case MessageBuildOp.CreateMiniProgram:
        return client.messageBuilder.buildMiniProgram({
          conversationId: request.conversationId,
          appId: requiredStringParam(params, "appId"),
          pagePath: optionalStringParam(params, "pagePath"),
          title: optionalStringParam(params, "title"),
          thumbnailUrl: optionalStringParam(params, "thumbnailUrl"),
          extra: stringMapParam(params, "extra"),
        });
      case MessageBuildOp.CreateRichDoc:
        {
          const markdownSource = optionalStringParam(params, "markdown");
          const docJsonSource = optionalStringParam(params, "docJson");
          const htmlSource = optionalStringParam(params, "html");
          const normalized = docJsonSource
            ? await client.messageBuilder.normalizeRichDocFromDocJson({
              docJson: docJsonSource,
            })
            : htmlSource
              ? await client.messageBuilder.normalizeRichDocFromHtml({
                html: htmlSource,
              })
              : await client.messageBuilder.normalizeRichDocFromMarkdown({
                markdown: markdownSource ?? requiredStringParam(params, "markdown"),
              });
          const sourcePayloadBase = normalized.sourcePayload
            ? Object.fromEntries(
              Object.entries(normalized.sourcePayload)
                .map(([entryKey, entryValue]) => [entryKey, String(entryValue ?? "")] as const),
            )
            : {};
          const sourcePayload = markdownSource
            ? { ...sourcePayloadBase, markdown: markdownSource }
            : Object.keys(sourcePayloadBase).length
              ? sourcePayloadBase
              : undefined;
          return client.messageBuilder.buildRichDoc({
            conversationId: request.conversationId,
            docJson: normalized.docJson,
            contentSchema: normalized.contentSchema,
            plainText: normalized.plainText,
            inputFormat: normalized.inputFormat,
            sourcePayload,
            title: optionalStringParam(params, "title"),
            searchText: normalized.searchText,
            renderHintsJson: JSON.stringify(normalized.renderHints),
          });
        }
      case MessageBuildOp.CreateQuote:
        return client.messageBuilder.buildQuote({
          conversationId: request.conversationId,
          quotedMessageId: requiredStringParam(params, "quotedMessageId"),
          text: requiredStringParam(params, "text"),
          quotedSenderId: optionalStringParam(params, "quotedSenderId"),
          quotedTextPreview: optionalStringParam(params, "quotedTextPreview"),
          quotedContent: messageContentParam(params, "quotedContent"),
        });
      case MessageBuildOp.CreateThreadReply:
        return client.messageBuilder.buildThreadReply({
          conversationId: request.conversationId,
          threadId: requiredStringParam(params, "threadId"),
          text: requiredStringParam(params, "text"),
        });
      case MessageBuildOp.CreateSystem:
        return client.messageBuilder.buildSystem({
          conversationId: request.conversationId,
          eventKind: requiredStringParam(params, "eventKind"),
          body: requiredStringParam(params, "body"),
        });
      case MessageBuildOp.CreateNotification:
        return client.messageBuilder.buildNotification({
          conversationId: request.conversationId,
          title: requiredStringParam(params, "title"),
          body: requiredStringParam(params, "body"),
        });
      case MessageBuildOp.CreateVote:
        return client.messageBuilder.buildVote({
          conversationId: request.conversationId,
          voteId: requiredStringParam(params, "voteId"),
          title: requiredStringParam(params, "title"),
          options: stringListParam(params, "options"),
          participantUserIds: stringListParam(params, "participantUserIds"),
        });
      case MessageBuildOp.CreateTask:
        return client.messageBuilder.buildTask({
          conversationId: request.conversationId,
          taskId: requiredStringParam(params, "taskId"),
          title: requiredStringParam(params, "title"),
          status: optionalStringParam(params, "status"),
          participantUserIds: stringListParam(params, "participantUserIds"),
        });
      case MessageBuildOp.CreateSchedule:
        return client.messageBuilder.buildSchedule({
          conversationId: request.conversationId,
          scheduleId: requiredStringParam(params, "scheduleId"),
          title: requiredStringParam(params, "title"),
          startTimeMs: requiredNumberParam(params, "startTimeMs"),
          endTimeMs: requiredNumberParam(params, "endTimeMs"),
          participantUserIds: stringListParam(params, "participantUserIds"),
        });
      case MessageBuildOp.CreateAnnouncement:
        return client.messageBuilder.buildAnnouncement({
          conversationId: request.conversationId,
          title: requiredStringParam(params, "title"),
          body: requiredStringParam(params, "body"),
        });
      case MessageBuildOp.CreateCustom:
        return client.messageBuilder.buildCustom({
          conversationId: request.conversationId,
          type: requiredStringParam(params, "type"),
        });
      case MessageBuildOp.CreatePlaceholder:
        return client.messageBuilder.buildPlaceholder({
          conversationId: request.conversationId,
          reason: requiredStringParam(params, "reason"),
        });
      case MessageBuildOp.CreateWithContent:
        return client.messageBuilder.buildWithContent({
          conversationId: request.conversationId,
          content: {
            contentType: contentTypeParam(params),
            data: recordParam(params, "data"),
          },
        });
      default:
        throw new FlareSdkException(
          "invalidParameter",
          `unsupported message builder op: ${op}`,
          "message_builder.build",
          { op },
        );
    }
  }

  async function searchMessages(request: {
    conversationId?: string;
    keyword: string;
    kinds?: readonly MessageSearchKind[];
    limit?: number;
    includeRecalled?: boolean;
    fromTime?: number;
    toTime?: number;
  }): Promise<readonly Message[]> {
    const query = {
      conversationId: request.conversationId,
      keyword: request.keyword,
      fromTime: request.fromTime,
      toTime: request.toTime,
      kinds: request.kinds ? [...request.kinds] : [],
      limit: request.limit ?? 50,
      includeRecalled: request.includeRecalled ?? false,
    };
    const response = await client.messages.searchMessagesByQuery(query);
    return response.messages;
  }

  async function dispatchMessage(op: string, params: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await client.messages.dispatchMessage({ op, params }) as Record<string, unknown>;
  }

  async function refreshCoreDiagnostics(): Promise<CoreDiagnosticsSnapshot> {
    const [
      sdkVersion,
      ffiContract,
      dataRoot,
      runtimeHealth,
      currentUser,
      active,
      connected,
      status,
    ] = await Promise.all([
      client.diagnostics.getSdkVersion(),
      client.diagnostics.getFfiContractVersion(),
      client.diagnostics.getDataRoot(),
      client.diagnostics.getRuntimeHealth(),
      client.currentUserId(),
      client.sessionActive(),
      client.isConnected(),
      client.connection.getStatus(),
    ]);
    return {
      sdkVersion: sdkVersion as Record<string, unknown>,
      ffiContract: ffiContract as Record<string, unknown>,
      dataRoot: dataRoot as Record<string, unknown>,
      runtimeHealth: runtimeHealth as unknown as Record<string, unknown>,
      currentUser,
      sessionActive: active,
      isConnected: connected,
      connectionStatus: status,
    };
  }

  async function refreshCoreMessageBuildCatalog(): Promise<readonly MessageBuildCatalogEntry[]> {
    const response = await client.messageBuilder.listSupportedBuildOperations();
    return response.entries;
  }

  async function resetCoreSessionForLogin(): Promise<void> {
    await withTimeout(
      closeOpenViews("login_reset"),
      LOGIN_SESSION_RESET_TIMEOUT_MS,
      () => sdkOperationTimeoutError("login.reset_views", LOGIN_SESSION_RESET_TIMEOUT_MS),
    ).catch((error) => {
      log("login_reset_views_failed", errorMessage(error));
    });
    const logout = (client as FlareImClient & { logout?: () => Promise<void> }).logout;
    if (!logout) {
      log("login_logout_previous_skipped", "unsupported");
      return;
    }
    const hasActiveSession = loggedIn.value || sessionActive.value || await withTimeout(
      client.sessionActive(),
      LOGIN_SESSION_RESET_TIMEOUT_MS,
      () => sdkOperationTimeoutError("login.session_active_probe", LOGIN_SESSION_RESET_TIMEOUT_MS),
    ).catch((error) => {
      log("login_session_active_probe_failed", errorMessage(error));
      return false;
    });
    if (!hasActiveSession) {
      log("login_logout_previous_skipped", "inactive");
      return;
    }
    await withTimeout(
      Promise.resolve().then(() => logout.call(client)),
      LOGIN_SESSION_RESET_TIMEOUT_MS,
      () => sdkOperationTimeoutError("login.logout_previous", LOGIN_SESSION_RESET_TIMEOUT_MS),
    ).catch((error) => {
      log("login_logout_previous_failed", errorMessage(error));
    });
  }

  /**
   * The init request of one session: where to connect and the host's own settings come from the build
   * (`options.sdkConfig`), the tenant and data root from the sign-in. Two ways to authenticate: app-hosted, a
   * connect token the host already holds is used as it is; SDK-managed, without one the SDK issues the connect token
   * through the core API of the access point it is on and renews it before expiry. The client never signs tokens
   * itself (that would put the signing key in the browser).
   */
  function coreSdkConfig(request: { dataUrl: string; tenantId: string; token: string }): SdkConfig {
    return {
      ...options.sdkConfig(),
      dataUrl: request.dataUrl,
      tenantId: request.tenantId,
      ...(request.token ? {} : { auth: {} }),
    };
  }

  /** Why this build cannot connect anywhere, or "" when it can. */
  function sdkConfigProblem(): string {
    try {
      options.sdkConfig();
      return "";
    } catch (error) {
      return errorMessage(error);
    }
  }

  let initBeforeSignInRun: Promise<boolean> | undefined;

  async function initForSignInPage(): Promise<boolean> {
    if (initialized.value) return true;
    if (accessConfigError.value || hasSavedSession()) return false;
    try {
      await client.init(coreSdkConfig({ dataUrl: form.dataUrl, tenantId: form.tenantId, token: "" }));
      return true;
    } catch (error) {
      log("init_before_sign_in_failed", errorMessage(error));
      return false;
    }
  }

  /**
   * Initializes the SDK ahead of any sign-in, so the update center runs on the sign-in page too: where to connect is
   * the build's, and the tenant here is only the form's default. Answers whether the SDK is initialized; a sign-in
   * initializes again with its own tenant, and a saved session initializes on its way in.
   */
  function initBeforeSignIn(): Promise<boolean> {
    initBeforeSignInRun ??= initForSignInPage().then((ready) => {
      if (!ready) initBeforeSignInRun = undefined;
      return ready;
    });
    return initBeforeSignInRun;
  }

  async function initAndLoginCore(request: {
    dataUrl: string;
    tenantId: string;
    userId: string;
    token: string;
  }): Promise<{ session: CoreSessionSnapshot; diagnostics: CoreDiagnosticsSnapshot; messageBuildCatalog: readonly MessageBuildCatalogEntry[] }> {
    const token = request.token.trim();
    const sdkConfig = coreSdkConfig({ ...request, token });
    // The sign-in page's init must not land after this one and put the default tenant back.
    await initBeforeSignInRun;
    await resetCoreSessionForLogin();
    await withTimeout(
      client.init(sdkConfig),
      CORE_LOGIN_STEP_TIMEOUT_MS,
      () => sdkOperationTimeoutError("login.init", CORE_LOGIN_STEP_TIMEOUT_MS),
    );
    await withTimeout(
      client.events.subscribeEvents({ sources: [...sdkEventSources] }),
      CORE_LOGIN_STEP_TIMEOUT_MS,
      () => sdkOperationTimeoutError("login.subscribe_events", CORE_LOGIN_STEP_TIMEOUT_MS),
    );
    await withTimeout(
      client.login(token ? { userId: request.userId, token } : { userId: request.userId }),
      CORE_LOGIN_TIMEOUT_MS,
      () => sdkOperationTimeoutError("login.core", CORE_LOGIN_TIMEOUT_MS),
    );
    const [status, catalog, coreDiagnostics] = await withTimeout(
      Promise.all([
        client.connection.getStatus(),
        refreshCoreMessageBuildCatalog(),
        refreshCoreDiagnostics(),
      ]),
      CORE_LOGIN_STEP_TIMEOUT_MS,
      () => sdkOperationTimeoutError("login.diagnostics", CORE_LOGIN_STEP_TIMEOUT_MS),
    );
    return {
      session: {
        initialized: true,
        loggedIn: true,
        userId: request.userId,
        connectionStatus: status,
      },
      diagnostics: coreDiagnostics,
      messageBuildCatalog: catalog,
    };
  }

  function canApplyConversationListView(): boolean {
    return conversationFilters.filter === "all"
      && !conversationFilters.includeArchived
      && !conversationFilters.conversationType;
  }

  function applyConversationListViewSnapshot(snapshot: {
    conversations: readonly Conversation[];
    totalUnread?: number;
  }): void {
    if (!canApplyConversationListView()) return;
    const authoritative = snapshot.conversations
      .filter((item) => item.conversationId.trim())
      .map((item) => ({ ...item }));
    conversations.value = authoritative;
    ensureActiveConversationSelection();
    refreshDerivedState();
    if (snapshot.totalUnread !== undefined) {
      totalUnread.value = Math.max(0, Number(snapshot.totalUnread) || 0);
    }
  }

  function applyTimelineViewSnapshot(viewId: string, snapshot: {
    conversation?: Conversation;
    messages: readonly Message[];
    hasOlder: boolean;
  }, revision: number): void {
    const activeView = activeTimelineView;
    if (!activeView || viewId !== activeView.viewId) return;
    activeView.revision = revision;
    const conversationId = (
      snapshot.conversation?.conversationId
      ?? snapshot.messages.find((message) => message.conversationId?.trim())?.conversationId
      ?? ""
    ).trim();
    const targetId = activeView.conversationId;
    if (conversationId && conversationId !== targetId) return;
    if (targetId !== activeConversationId.value.trim()) return;

    messages.value = [...snapshot.messages];
    messageHasMore.value = snapshot.hasOlder;
    refreshDerivedState();
    scheduleVisibleMarkRead("timeline_snapshot");
  }

  function applyViewSnapshot(viewId: string, snapshot: ViewUpdate["snapshot"], revision: number): void {
    if (!snapshot) return;
    if (snapshot.viewType === "conversationList") {
      if (viewId !== conversationListViewId) return;
      applyConversationListViewSnapshot(snapshot.data);
      return;
    }
    if (snapshot.viewType === "timeline") {
      applyTimelineViewSnapshot(viewId, snapshot.data, revision);
    }
  }

  function boundedDeltaIndex(index: number, length: number): number {
    if (!Number.isFinite(index)) return length;
    return Math.max(0, Math.min(Math.trunc(index), length));
  }

  function applyIndexedDeltaOps<T>(
    current: readonly T[],
    ops: readonly ViewDeltaOperation[],
    keyOf: (item: T) => string,
    decodeItem: (op: ViewDeltaOperation) => T | undefined,
  ): T[] {
    const next = [...current];
    const indexByKey = (key: string) => next.findIndex((item) => keyOf(item) === key);
    for (const op of ops) {
      const key = op.key.trim();
      if (!key) continue;
      if (op.op === "remove") {
        const existingIndex = indexByKey(key);
        if (existingIndex >= 0) next.splice(existingIndex, 1);
        continue;
      }
      if (op.op === "move") {
        const existingIndex = indexByKey(key);
        if (existingIndex < 0) continue;
        const [item] = next.splice(existingIndex, 1);
        next.splice(boundedDeltaIndex(op.index, next.length), 0, item);
        continue;
      }
      const item = decodeItem(op);
      if (!item) continue;
      const existingIndex = indexByKey(key);
      if (op.op === "insert") {
        if (existingIndex >= 0) next.splice(existingIndex, 1);
        next.splice(boundedDeltaIndex(op.index, next.length), 0, item);
        continue;
      }
      if (op.op === "update" && existingIndex >= 0) {
        next[existingIndex] = item;
      }
    }
    return next;
  }

  function decodeConversationDeltaItem(op: ViewDeltaOperation): Conversation | undefined {
    if (!op.item) return undefined;
    const item = conversationFromJson(op.item);
    return item.conversationId.trim() === op.key.trim() ? { ...item } : undefined;
  }

  function applyConversationListViewDelta(viewId: string, delta: ViewDeltaPayload): void {
    if (viewId !== conversationListViewId || delta.viewType !== "conversationList") return;
    if (!canApplyConversationListView()) return;
    conversations.value = applyIndexedDeltaOps(
      conversations.value,
      delta.ops ?? [],
      (item) => item.conversationId.trim(),
      decodeConversationDeltaItem,
    );
    ensureActiveConversationSelection();
    refreshDerivedState();
    if (delta.totalUnread !== undefined) {
      totalUnread.value = Math.max(0, Number(delta.totalUnread) || 0);
    }
  }

  /** 时间线视图的行键：clientMsgId，没有时 serverId，都没有时 seq:<会话>:<seq>（与核心 row_key 相同）。 */
  function timelineRowKey(message: Message): string {
    return message.clientMsgId || message.serverId || `seq:${message.conversationId}:${message.conversationSeq}`;
  }

  /**
   * 按核心视图的增量规则应用：删 remove；原位替换 upsert；prepend 放最前、append 放最后；
   * reorder 非空时按它重排；最后取三个状态字段与 conversation。
   */
  function applyTimelineViewDelta(viewId: string, delta: ViewDeltaPayload): void {
    const activeView = activeTimelineView;
    if (!activeView || viewId !== activeView.viewId || delta.viewType !== "timeline") return;
    const targetId = activeView.conversationId;
    if (targetId !== activeConversationId.value.trim()) return;
    const removed = new Set(delta.remove ?? []);
    const upserts = new Map((delta.upsert ?? []).map((message) => [timelineRowKey(message), message]));
    let next = messages.value
      .filter((message) => !removed.has(timelineRowKey(message)))
      .map((message) => upserts.get(timelineRowKey(message)) ?? message);
    next = [...(delta.prepend ?? []), ...next, ...(delta.append ?? [])];
    if (delta.reorder) {
      const byKey = new Map(next.map((message) => [timelineRowKey(message), message]));
      next = delta.reorder.flatMap((key) => {
        const message = byKey.get(key);
        return message ? [message] : [];
      });
    }
    messages.value = next;
    if (delta.hasOlder !== undefined) {
      messageHasMore.value = delta.hasOlder;
    }
    refreshDerivedState();
    scheduleVisibleMarkRead("timeline_delta");
  }

  /** 版本号跳了（或翻页的结果还没随事件到达）：取当前快照整体替换。 */
  async function resyncTimelineView(viewId: string, reason: string): Promise<void> {
    try {
      const response = await client.views.timelineSnapshot({ viewId });
      const activeView = activeTimelineView;
      if (!activeView || activeView.viewId !== viewId || response.revision < activeView.revision) return;
      applyViewSnapshot(viewId, response.snapshot, response.revision);
      log("view_timeline_snapshot", `${reason}:${viewId}:${response.revision}`);
    } catch (error) {
      log("view_timeline_snapshot_failed", `${reason}:${viewId}: ${errorMessage(error)}`);
    }
  }

  function applyViewDelta(viewId: string, delta: ViewUpdate["delta"]): void {
    if (!delta) return;
    if (delta.viewType === "conversationList") {
      applyConversationListViewDelta(viewId, delta);
      return;
    }
    if (delta.viewType === "timeline") {
      applyTimelineViewDelta(viewId, delta);
    }
  }

  function handleViewUpdate(update: ViewUpdate): void {
    const activeView = activeTimelineView;
    if (activeView && update.viewId === activeView.viewId) {
      if (update.revision <= activeView.revision) return;
      if (update.revision !== activeView.revision + 1) {
        void resyncTimelineView(update.viewId, "revision_gap");
        return;
      }
      activeView.revision = update.revision;
    }
    if (update.kind === "delta") {
      applyViewDelta(update.viewId, update.delta);
      return;
    }
    applyViewSnapshot(update.viewId, update.snapshot, update.revision);
  }

  async function openConversationListView(reason: string): Promise<void> {
    if (conversationListViewId || !canApplyConversationListView()) return;
    try {
      const response = await withTimeout(
        Promise.resolve().then(() => client.views.openConversationList({ conversationLimit: 100 })),
        CONVERSATION_LIST_VIEW_OPEN_TIMEOUT_MS,
        () => sdkOperationTimeoutError("view.conversation_list.open", CONVERSATION_LIST_VIEW_OPEN_TIMEOUT_MS),
      );
      conversationListViewId = response.viewId;
      applyViewSnapshot(response.viewId, response.snapshot, response.revision);
      log("view_conversations_open", `${reason}:${conversationListViewId}`);
    } catch (error) {
      log("view_conversations_open_failed", `${reason}: ${errorMessage(error)}`);
    }
  }

  async function openTimelineView(conversationId: string, reason: string, options: { force?: boolean } = {}): Promise<void> {
    const targetId = conversationId.trim();
    if (!targetId) return;
    if (activeTimelineView?.conversationId === targetId && !options.force) return;
    const replacingDifferentConversation = Boolean(
      activeTimelineView?.conversationId && activeTimelineView.conversationId !== targetId,
    );
    await closeActiveTimelineView(`replace:${reason}`);
    if (replacingDifferentConversation && activeConversationId.value.trim() === targetId) {
      messages.value = [];
      pinnedMessages.value = [];
      messageHasMore.value = true;
      refreshDerivedState();
    }
    try {
      const response = await withTimeout(
        client.views.openTimeline({
          conversationId: targetId,
          messageLimit: MESSAGE_PAGE_SIZE,
        }),
        TIMELINE_OPEN_TIMEOUT_MS,
        () => sdkOperationTimeoutError("view.timeline.open", TIMELINE_OPEN_TIMEOUT_MS),
      );
      activeTimelineView = { conversationId: targetId, viewId: response.viewId, revision: response.revision };
      applyViewSnapshot(response.viewId, response.snapshot, response.revision);
      log("view_timeline_open", `${reason}:${targetId}:${response.viewId}`);
    } catch (error) {
      log("view_timeline_open_failed", `${reason}:${targetId}: ${errorMessage(error)}`);
      throw error;
    }
  }

  function activeTimelineSeqStats(conversationId: string): { count: number; minSeq: number } {
    const targetId = conversationId.trim();
    if (!targetId) return { count: 0, minSeq: Number.POSITIVE_INFINITY };
    const activeMessages = messages.value.filter((message) => message.conversationId === targetId);
    const minSeq = activeMessages.reduce((min, message) => {
      const seq = Number(message.conversationSeq) || 0;
      return seq > 0 ? Math.min(min, seq) : min;
    }, Number.POSITIVE_INFINITY);
    return { count: activeMessages.length, minSeq };
  }

  /**
   * 只在打开后**确实不够用**时才回填，不能只看「没加载到第 1 条」。
   *
   * 原条件是 `minSeq > 1`，对任何有历史的会话都恒成立：2 万条消息的会话每次打开
   * 都会同步拉最多 8 页 × 200 = 1600 条。这些批量读占满 WASM 的单槽 invoke 链，
   * 用户开完会话的**第一次发送**只能排队 —— 实测 Enter→上屏 1299ms，
   * 而同一会话里的第二次发送只要 61ms。乐观上屏本该是零等待的。
   *
   * 回填要保住的是另一件事：本地库太空时打开只拿到零星几条，时间线短到没法滚动，
   * 服务端的历史回填能力就一次都不会被调用。所以判据改成「这一页都没装满」——
   * 那才是真的不够用；装满了就交给用户滚动时的懒加载。
   */
  function shouldRepairInitialTimelineHistory(conversationId: string): boolean {
    const targetId = conversationId.trim();
    if (!targetId || initialHistoryRepairTried.has(targetId)) return false;
    const stats = activeTimelineSeqStats(targetId);
    if (stats.count === 0) return false;
    if (stats.count >= MESSAGE_PAGE_SIZE) return false;
    return Number.isFinite(stats.minSeq) && stats.minSeq > 1;
  }

  async function repairInitialTimelineHistoryIfNeeded(conversationId: string, reason: string): Promise<void> {
    const targetId = conversationId.trim();
    if (!shouldRepairInitialTimelineHistory(targetId)) return;
    initialHistoryRepairTried.add(targetId);
    try {
      let repairedPages = 0;
      for (let page = 0; page < INITIAL_HISTORY_REPAIR_MAX_PAGES; page += 1) {
        const before = activeTimelineSeqStats(targetId);
        if (!Number.isFinite(before.minSeq) || before.minSeq <= 1) break;
        await loadOlderMessages({ force: true, limit: INITIAL_HISTORY_REPAIR_SYNC_LIMIT });
        const after = activeTimelineSeqStats(targetId);
        if (after.count <= before.count && after.minSeq >= before.minSeq) break;
        repairedPages += 1;
        if (!messageHasMore.value) break;
      }
      if (repairedPages > 0) {
        const stats = activeTimelineSeqStats(targetId);
        log("view_timeline_history_repair", `${targetId}:min_seq_gap:${repairedPages}:${stats.count}`);
      }
    } catch (error) {
      log("view_timeline_history_repair_failed", `${targetId}: ${errorMessage(error)}`);
    }
  }

  async function closeActiveTimelineView(reason: string): Promise<void> {
    const current = activeTimelineView;
    if (!current) return;
    activeTimelineView = null;
    try {
      await client.views.close({ viewId: current.viewId });
      log("view_timeline_close", `${reason}:${current.conversationId}:${current.viewId}`);
    } catch (error) {
      log("view_timeline_close_failed", `${reason}:${current.conversationId}: ${errorMessage(error)}`);
    }
  }

  async function closeConversationListView(reason: string): Promise<void> {
    const viewId = conversationListViewId;
    if (!viewId) return;
    conversationListViewId = "";
    try {
      await client.views.close({ viewId });
      log("view_conversations_close", `${reason}:${viewId}`);
    } catch (error) {
      log("view_conversations_close_failed", `${reason}:${viewId}: ${errorMessage(error)}`);
    }
  }

  async function unsubscribeAllEvents(reason: string): Promise<void> {
    try {
      await client.events.unsubscribeAll();
      log("events_unsubscribe_all", reason);
    } catch (error) {
      log("events_unsubscribe_all_failed", `${reason}: ${errorMessage(error)}`);
    }
  }

  async function closeOpenViews(reason: string): Promise<void> {
    await closeActiveTimelineView(reason);
    await closeConversationListView(reason);
  }

  async function disposeOpenViewsAndEvents(reason: string): Promise<void> {
    await closeOpenViews(reason);
    await unsubscribeAllEvents(reason);
  }

  function ensureActiveConversationSelection(): void {
    const current = activeConversationId.value.trim();
    if (!current) {
      return;
    }
    if (!conversations.value.some((item) => item.conversationId === current)) {
      activeConversationId.value = "";
    }
  }

  async function markConversationRead(conversationId: string): Promise<number> {
    const targetId = conversationId.trim();
    if (!targetId) return 0;
    const readSeq = currentSnapshotReadSeq(targetId);
    if (readSeq <= 0) return 0;
    await client.conversations.markConversationRead({ conversationId: targetId, readSeq });
    return readSeq;
  }

  function patchConversationReadState(conversationId: string, readSeq: number): void {
    let changed = false;
    conversations.value = conversations.value.map((item) => {
      if (item.conversationId !== conversationId) return item;
      changed = true;
      return {
        ...item,
        unreadCount: 0,
        lastReadSeq: Math.max(Number(item.lastReadSeq) || 0, readSeq),
      };
    });
    if (changed) {
      refreshDerivedState();
    }
  }

  function setActiveTimelineAtBottom(atBottom: boolean): void {
    activeTimelineAtBottom.value = atBottom;
    if (atBottom) {
      scheduleVisibleMarkRead("bottom_visible");
    }
  }

  function scheduleVisibleMarkRead(reason: string): void {
    if (!activeTimelineAtBottom.value || !activeConversationId.value.trim()) return;
    if (markReadTimer) clearTimeout(markReadTimer);
    markReadTimer = setTimeout(() => {
      markReadTimer = undefined;
      void markActiveConversationVisibleRead(reason);
    }, 80);
  }

  async function markActiveConversationVisibleRead(reason: string): Promise<void> {
    if (markReadInFlight) {
      await markReadInFlight;
    }
    if (!activeTimelineAtBottom.value) return;
    const conversationId = activeConversationId.value.trim();
    if (!conversationId) return;
    const readSeq = currentSnapshotReadSeq(conversationId);
    if (readSeq <= 0) return;
    if ((lastMarkedReadSeqByConversation.get(conversationId) ?? 0) >= readSeq) return;
    markReadInFlight = (async () => {
      const appliedSeq = await markConversationRead(conversationId);
      lastMarkedReadSeqByConversation.set(conversationId, appliedSeq);
      patchConversationReadState(conversationId, appliedSeq);
      log("mark_read_visible", `${reason}:${conversationId}:${appliedSeq}`);
    })().catch((error) => {
      log("mark_read_visible_failed", `${reason}: ${errorMessage(error)}`);
    }).finally(() => {
      markReadInFlight = undefined;
    });
    await markReadInFlight;
  }

  async function enterActiveConversation(reason: string): Promise<void> {
    const conversationId = activeConversationId.value.trim();
    if (!conversationId) return;
    beginMessageOpening();
    messageSyncing.value = true;
    messageSyncError.value = "";
    try {
      await openTimelineView(conversationId, reason);
      void repairInitialTimelineHistoryIfNeeded(conversationId, reason);
    } catch (error) {
      messageSyncError.value = errorMessage(error);
      log("message_open_failed", `${reason}:${conversationId}: ${messageSyncError.value}`);
    } finally {
      finishMessageOpening(conversationId);
      messageSyncing.value = false;
    }
    await markConversationRead(conversationId).catch((error) => {
      log("mark_read_failed", `${reason}: ${errorMessage(error)}`);
    });
    scheduleVisibleMarkRead(reason);
  }

  async function syncMessagesFromKnownCursor(conversationId: string, limit = MESSAGE_PAGE_SIZE): Promise<void> {
    if (!conversationId) return;
    await withTimeout(
      client.sync.syncMessages({ conversationId, lastSeq: 0, limit }),
      MESSAGE_SYNC_TIMEOUT_MS,
      () => sdkOperationTimeoutError("sync.messages", MESSAGE_SYNC_TIMEOUT_MS),
    );
  }

  function syncConversationSummaries(): Promise<void> {
    if (!pendingConversationSummarySync) {
      pendingConversationSummarySync = withTimeout(
        Promise.resolve().then(() => client.sync.syncConversationSummaries()),
        SYNC_CONVERSATION_SUMMARIES_TIMEOUT_MS,
        () => sdkOperationTimeoutError("sync.conversation_summaries", SYNC_CONVERSATION_SUMMARIES_TIMEOUT_MS),
      )
        .finally(() => {
          pendingConversationSummarySync = undefined;
        });
    }
    return pendingConversationSummarySync;
  }

  async function trySyncConversationSummaries(reason: string): Promise<boolean> {
    try {
      await syncConversationSummaries();
      return true;
    } catch (error) {
      log("sync_conversation_summaries_degraded", `${reason}:${errorMessage(error)}`);
      return false;
    }
  }

  async function backfillVisibleConversationHistories(reason: string): Promise<void> {
    const historyConversations = await listConversations({ includeArchived: true });
    const conversationIds = [
      ...new Set(historyConversations.map((item) => item.conversationId.trim()).filter(Boolean)),
    ];
    if (conversationIds.length === 0) return;

    const strict = reason === "manual_sync";
    let totalPages = 0;
    let completed = 0;
    const failures: string[] = [];

    for (const [index, conversationId] of conversationIds.entries()) {
      try {
        let round = 0;
        let response: Awaited<ReturnType<typeof client.sync.backfillConversationHistory>> | undefined;
        do {
          round += 1;
          if (homeSyncing.value) {
            setHomeSyncProgress({
              step: "history",
              title: translateFlare("sync.backfillTitle"),
              detail: translateFlare("sync.backfillDetail", { index: index + 1, total: conversationIds.length, round }),
              percent: Math.min(92, 72 + Math.round(((index + 1) / conversationIds.length) * 18)),
            });
          }
          const current = await withTimeout(
            Promise.resolve().then(() => client.sync.backfillConversationHistory({
              conversationId,
              limit: FULL_HISTORY_BACKFILL_SYNC_LIMIT,
              maxPages: FULL_HISTORY_BACKFILL_MAX_PAGES_PER_CALL,
            })),
            HISTORY_BACKFILL_CONVERSATION_TIMEOUT_MS,
            () => sdkOperationTimeoutError("sync.conversation_history_backfill", HISTORY_BACKFILL_CONVERSATION_TIMEOUT_MS),
          );
          response = current;
          totalPages += Number(current.pagesLoaded) || 0;
          if (current.completed || current.pagesLoaded <= 0) {
            break;
          }
        } while (round < FULL_HISTORY_BACKFILL_MAX_ROUNDS);

        if (!response?.completed) {
          const detail = `${conversationId}: history backfill incomplete after ${round} rounds`;
          failures.push(detail);
          log("history_backfill_incomplete", `${reason}:${detail}`);
          if (strict) {
            throw new Error(detail);
          }
          continue;
        }

        completed += 1;
        log(
          "history_backfill",
          `${reason}:${conversationId}:rounds=${round}:oldest=${response.oldestSeqAfter}:done=${response.completed}`,
        );
      } catch (error) {
        const detail = `${conversationId}: ${errorMessage(error)}`;
        failures.push(detail);
        log("history_backfill_failed", `${reason}:${detail}`);
        if (strict) {
          throw error;
        }
      }
    }

    if (failures.length > 0) {
      const detail = translateFlare("sync.backfillIncomplete", { failed: failures.length, total: conversationIds.length, detail: failures.slice(0, 3).join("; ") });
      if (strict) {
        throw new Error(detail);
      }
      log("history_backfill_degraded", `${reason}:${detail}`);
      return;
    }

    log("history_backfill_done", `${reason}:${completed}/${conversationIds.length}:pages=${totalPages}`);
  }

  function log(label: string, detail = ""): void {
    events.value = [{ id: eventId++, label, detail, at: Date.now() }, ...events.value].slice(0, 24);
    if (typeof console !== "undefined") {
      console.info("[flare-web]", label, detail);
    }
  }

  function nowMs(): number {
    return typeof performance !== "undefined" ? performance.now() : Date.now();
  }

  function logDuration(label: string, start: number): void {
    const detail = `${Math.round(nowMs() - start)}ms`;
    log(label, detail);
    if (typeof console !== "undefined") {
      console.info("[flare-web]", label, detail);
    }
  }

  function refreshDerivedState(): void {
    const activeId = activeConversationId.value.trim();
    totalUnread.value = conversations.value.reduce(
      (sum, item) => sum + Math.max(0, Number(item.unreadCount) || 0),
      0,
    );
    activeConversation.value = conversations.value.find((item) => item.conversationId === activeId);
    const activeMessages = messages.value.filter((message) => message.conversationId === activeId);
    const latest = activeMessages.reduce<Message | undefined>((current, message) => {
      if (!current) return message;
      const messageSeq = Number(message.conversationSeq) || 0;
      const currentSeq = Number(current.conversationSeq) || 0;
      if (messageSeq !== currentSeq) return messageSeq > currentSeq ? message : current;
      return (Number(message.createdAt) || 0) >= (Number(current.createdAt) || 0) ? message : current;
    }, undefined);
    activeLatestMessageId.value =
      activeConversation.value?.lastMessageId || latest?.serverId || latest?.clientMsgId || "";
    pinnedMessages.value = activeMessages.filter(isPinnedMessage);
    setDesktopUnreadCount(totalUnread.value);
  }

  function isDocumentForeground(): boolean {
    if (typeof document === "undefined") return true;
    return document.visibilityState === "visible" && document.hasFocus();
  }

  function isDocumentVisible(): boolean {
    if (typeof document === "undefined") return true;
    return document.visibilityState === "visible";
  }

  function isRealtimeRefreshConnectionReady(): boolean {
    return connectionPhase.value === "online";
  }

  function startRealtimeSafetyPoll(): void {
    if (typeof window === "undefined" || realtimeSafetyPollTimer) return;
    realtimeSafetyPollTimer = window.setInterval(() => {
      void refreshActiveConversationFromServer("safety_poll");
    }, REALTIME_SAFETY_POLL_INTERVAL_MS);
  }

  async function refreshActiveConversationFromServer(reason: string): Promise<void> {
    if (realtimeSafetyPollInFlight) return;
    if (activeOutgoingSends > 0) return;
    if (Date.now() - lastOutgoingSendAt < REALTIME_SAFETY_POLL_AFTER_SEND_QUIET_MS) return;
    if (Date.now() < realtimeSafetyPollNextAt) return;
    if (!loggedIn.value || !isRealtimeRefreshConnectionReady()) return;
    if (!isDocumentVisible()) return;
    const conversationId = activeConversationId.value.trim();
    if (!conversationId) return;
    if (messageOpening.value || messageSyncing.value || loadingOlderMessages.value) return;
    realtimeSafetyPollInFlight = true;
    try {
      await client.sync.syncConversation({ conversationId });
      await syncMessagesFromKnownCursor(conversationId);
      await refreshConversations({ silent: true });
      // 活动会话已有打开的时间线视图时，不做破坏性的全量 close+open 重开：
      // syncMessagesFromKnownCursor 已把新消息灌入 core，core 观察视图会以 delta
      // (applyTimelineViewDelta) 实时增量刷新已打开的视图。每 12s 无条件全量重开会
      // 反复 close+open 时间线，占满 WASM 单槽 invoke 链，导致 message.send 排不进而 30s
      // 超时、进来的推送也渲染不出（线上表现：双方在线互发都收不到）。仅当视图缺失/错位
      // （无 activeTimelineView 或指向别的会话）时才作为安全网重开。
      if (activeTimelineView?.conversationId !== conversationId) {
        await refreshMessages(conversationId, { silent: true });
      }
      realtimeSafetyPollFailureCount = 0;
      realtimeSafetyPollNextAt = 0;
    } catch (error) {
      realtimeSafetyPollFailureCount += 1;
      realtimeSafetyPollNextAt = Date.now() + Math.min(
        REALTIME_SAFETY_POLL_BACKOFF_MAX_MS,
        REALTIME_SAFETY_POLL_BACKOFF_BASE_MS * (2 ** Math.min(realtimeSafetyPollFailureCount - 1, 4)),
      );
      log("realtime_refresh_failed", `${reason}:${conversationId}: ${errorMessage(error)}`);
    } finally {
      realtimeSafetyPollInFlight = false;
    }
  }

  function scheduleIncomingConversationRefresh(reason: string): void {
    if (!loggedIn.value) return;
    if (typeof window === "undefined") {
      void refreshIncomingConversationSummary(reason);
      return;
    }
    if (incomingConversationRefreshTimer !== undefined) {
      window.clearTimeout(incomingConversationRefreshTimer);
    }
    incomingConversationRefreshTimer = window.setTimeout(() => {
      incomingConversationRefreshTimer = undefined;
      void refreshIncomingConversationSummary(reason);
    }, INCOMING_CONVERSATION_REFRESH_DEBOUNCE_MS);
  }

  async function refreshIncomingConversationSummary(reason: string): Promise<void> {
    if (incomingConversationRefreshInFlight) return;
    incomingConversationRefreshInFlight = true;
    try {
      await refreshConversations({ silent: true });
    } catch (error) {
      log("incoming_conversation_refresh_failed", `${reason}: ${errorMessage(error)}`);
    } finally {
      incomingConversationRefreshInFlight = false;
    }
  }

  /// 去抖的活动会话对账:把消息突发合并成一次 syncConversation+时间线重读(安全网);
  /// 实时增量显示由 core 观察视图 delta 负责,避免每条消息全量重开时间线导致的抖动风暴。
  function scheduleActiveConversationRefresh(reason: string): void {
    if (typeof window === "undefined") {
      void refreshActiveConversationFromServer(reason);
      return;
    }
    if (activeConversationRefreshTimer !== undefined) {
      window.clearTimeout(activeConversationRefreshTimer);
    }
    activeConversationRefreshTimer = window.setTimeout(() => {
      activeConversationRefreshTimer = undefined;
      void refreshActiveConversationFromServer(reason);
    }, ACTIVE_CONVERSATION_REFRESH_DEBOUNCE_MS);
  }

  function handleIncomingMessageNotification(hint: IncomingMessageHint): void {
    scheduleIncomingConversationRefresh("incoming_message");
    // 活动会话的时间线由 core 观察视图 delta(applyTimelineViewDelta)实时增量渲染,不在这里做
    // 全量重开(close+open)——那会撕毁/重建视图造成抖动与消息闪烁。对账交给 12s 安全轮询兜底。
    // scheduleActiveConversationRefresh("event_hint"); // removed: redundant churn vs view delta

    const message = hint.message;
    if (!message) return;
    const senderId = message.senderId.trim();
    const selfUserId = (currentUserId.value || form.userId).trim();
    if (senderId && selfUserId && senderId === selfUserId) return;

    const conversationId = message.conversationId.trim();
    const conversation = conversations.value.find((item) => item.conversationId === conversationId);
    if (conversation?.isMuted) return;

    const kind = desktopNotificationKindForMessage(message);
    const foregroundInActiveConversation =
      kind !== "call" &&
      isDocumentForeground() &&
      conversationId &&
      conversationId === activeConversationId.value.trim();
    if (foregroundInActiveConversation) return;

    const senderLabel = message.senderDisplayName.trim() || message.senderName.trim() || senderId || "Flare IM";
    const title = kind === "call" ? translateFlare("call.startedBy", { sender: senderLabel }) : senderLabel;
    const body = kind === "call" ? callNotificationBody(message) : desktopNotificationBodyForMessage(message);
    emitDesktopNotification({
      kind,
      title,
      body,
      conversationId,
      messageId: message.serverId || message.clientMsgId,
      senderId,
      unreadCount: Math.max(1, totalUnread.value),
      requireAttention: true,
      playSound: true,
      dedupeKey: message.serverId || message.clientMsgId || `${conversationId}:${message.conversationSeq}`,
    });
  }

  function desktopNotificationKindForMessage(message: Message): DesktopNotificationKind {
    return looksLikeCallMessage(message) ? "call" : "message";
  }

  function looksLikeCallMessage(message: Message): boolean {
    const text = [
      message.textPreview,
      message.content?.contentType,
      ...Object.values(message.attributes ?? {}),
      ...Object.values(message.content?.data ?? {}).map((value) => String(value ?? "")),
    ].join(" ").toLowerCase();
    return /\brtc\.call\b|\bcall\b|\bwebrtc\b|\bsfu\b/.test(text);
  }

  function callNotificationBody(message: Message): string {
    return firstNonEmpty(
      message.textPreview,
      readStringField(message.content?.data, "title"),
      readStringField(message.content?.data, "body"),
    ) || translateFlare("call.incoming");
  }

  function firstNonEmpty(...values: Array<string | undefined>): string {
    return values.map((value) => value?.trim() ?? "").find(Boolean) ?? "";
  }

  function readStringField(record: unknown, field: string): string | undefined {
    if (!record || typeof record !== "object") return undefined;
    const value = (record as Record<string, unknown>)[field];
    return typeof value === "string" ? value : undefined;
  }

  function stableNotificationKey(payload: unknown): string {
    try {
      return JSON.stringify(payload) || "";
    } catch {
      return String(payload ?? "");
    }
  }

  function patchMessageById(
    messageId: string,
    patcher: (message: Message) => Message,
  ): void {
    let changed = false;
    messages.value = messages.value.map((message) => {
      if (!messageMatchesId(message, messageId)) return message;
      changed = true;
      return patcher(message);
    });
    if (changed) {
      refreshDerivedState();
    }
  }

  function removeMessageById(messageId: string): void {
    const next = messages.value.filter((message) => !messageMatchesId(message, messageId));
    if (next.length === messages.value.length) return;
    messages.value = next;
    refreshDerivedState();
  }

  function applyReactionChanged(hint: ReactionChangedHint): void {
    const conversationId = (hint.conversationId ?? "").trim();
    const messageId = (hint.serverMsgId ?? "").trim();
    const emoji = (hint.emoji ?? "").trim();
    const userId = (hint.userId ?? "").trim();
    const action = Number(hint.action ?? 0);
    if (
      !conversationId ||
      conversationId !== activeConversationId.value.trim() ||
      !messageId ||
      !emoji ||
      !userId ||
      (action !== 1 && action !== 2)
    ) {
      return;
    }
    patchLocalReaction(messageId, emoji, userId, action);
  }

  function patchLocalReaction(messageId: string, emoji: string, userId: string, action: number): void {
    if (!messageId || !emoji || !userId || (action !== 1 && action !== 2)) return;

    let changed = false;
    messages.value = messages.value.map((message) => {
      if (!messageMatchesId(message, messageId)) return message;
      const reactions: ReactionEntry[] = (message.reactions ?? []).map((reaction) => ({
        ...reaction,
        userIds: [...(reaction.userIds ?? [])],
      }));
      const index = reactions.findIndex((reaction) => reaction.emoji === emoji);
      if (action === 1) {
        if (index >= 0) {
          const reaction = reactions[index];
          if (!reaction.userIds.includes(userId)) {
            reaction.userIds.push(userId);
            changed = true;
          }
          const nextCount = Math.max(Number(reaction.count) || 0, reaction.userIds.length);
          if (reaction.count !== nextCount) {
            reaction.count = nextCount;
            changed = true;
          }
        } else {
          reactions.push({ emoji, count: 1, userIds: [userId] });
          changed = true;
        }
      } else if (index >= 0) {
        const reaction = reactions[index];
        const nextUserIds = reaction.userIds.filter((id) => id !== userId);
        if (nextUserIds.length !== reaction.userIds.length || reaction.count !== nextUserIds.length) {
          changed = true;
        }
        reaction.userIds = nextUserIds;
        reaction.count = nextUserIds.length;
        if (reaction.count <= 0) {
          reactions.splice(index, 1);
        }
      }
      return { ...message, reactions };
    });
    if (changed) {
      refreshDerivedState();
    }
  }

  function beginMessageOpening(): void {
    if (messageOpeningTimer) {
      clearTimeout(messageOpeningTimer);
      messageOpeningTimer = undefined;
    }
    messageOpening.value = true;
  }

  function finishMessageOpening(conversationId: string): void {
    if (messageOpeningTimer) {
      clearTimeout(messageOpeningTimer);
    }
    messageOpeningTimer = setTimeout(() => {
      if (activeConversationId.value === conversationId) {
        messageOpening.value = false;
      }
      messageOpeningTimer = undefined;
    }, 240);
  }

  function resetMessageOpening(): void {
    if (messageOpeningTimer) {
      clearTimeout(messageOpeningTimer);
      messageOpeningTimer = undefined;
    }
    messageOpening.value = false;
  }

  /** Takes the core's current status: the `connection://status` events keep it current after that. */
  async function refreshConnectionStatus(): Promise<void> {
    connectionStatus.value = await client.connection.getStatus();
  }

  async function refreshConnectionStatusSafely(reason: string): Promise<void> {
    try {
      await refreshConnectionStatus();
    } catch (error) {
      log("connection_status_refresh_failed", `${reason}: ${errorMessage(error)}`);
    }
  }

  function setHomeSyncProgress(progress: HomeSyncProgress): void {
    homeSyncProgress.value = progress;
  }

  function errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }

  function isDatabaseLockedError(error: unknown): boolean {
    return /database is locked|code:\s*(5|517)\b/i.test(errorMessage(error));
  }

  function isTimeoutError(error: unknown): boolean {
    const code = error && typeof error === "object"
      ? (error as { code?: unknown }).code
      : undefined;
    return code === "timeout" || /timed out|invoke_timeout/i.test(errorMessage(error));
  }

  function wait(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function errorPayload(error: unknown, operation: string): Record<string, unknown> {
    return reportSdkError(error, operation);
  }

  /** 传输层把「CONNECT_ACK 之前被服务端断开」升级成了 AUTHENTICATION_FAILED，这里识别它。 */
  function isTokenRejectedError(error: unknown): boolean {
    return /AUTHENTICATION_FAILED|TOKEN_REJECTED/.test(errorMessage(error));
  }

  function isRuntimeUnavailableError(error: unknown): boolean {
    if (!error || typeof error !== "object") {
      return false;
    }
    const shaped = error as { code?: unknown; operation?: unknown };
    return shaped.code === "runtimeUnavailable" || shaped.operation === "wasm.load";
  }

  async function runLab<T extends Record<string, unknown> | unknown[] | void>(
    operation: string,
    action: () => Promise<T>,
  ): Promise<void> {
    labBusy.value = true;
    try {
      const result = await action();
      labResult.value = result === undefined ? { ok: true, operation } : ({ operation, result } as Record<string, unknown>);
      log(operation, "ok");
    } catch (error) {
      labResult.value = errorPayload(error, operation);
      log(`${operation}_failed`, errorMessage(error));
    } finally {
      labBusy.value = false;
    }
  }

  async function refreshConversations(options: ConversationRefreshOptions = {}): Promise<void> {
    if (!options.silent) {
      conversationSyncing.value = true;
      conversationSyncError.value = "";
    }
    try {
      const filter = conversationFilters.filter;
      let nextConversations: Conversation[];
      if (filter === "archived") {
        // includeArchived 的语义是"额外带上归档会话"，不是"只要归档会话"。
        // 直接拿它当归档筛选用，列表会原样返回全部会话——筛选看起来生效了
        // （高亮切了），内容却一条没少。SDK 没有 archivedOnly 查询，所以在
        // 取回后按 isArchived 收窄。
        nextConversations = keepArchivedConversations(
          await listConversations({ includeArchived: true }),
        );
      } else if (conversationFilters.includeArchived) {
        nextConversations = [...await listConversations({ includeArchived: true })];
      } else if (conversationFilters.conversationType) {
        const response = await client.conversations.listConversationsByQuery({
          keyword: "",
          includeArchived: conversationFilters.includeArchived,
          unreadOnly: filter === "unread",
          mentionMeOnly: filter === "mention",
          pinnedOnly: filter === "pinned",
          hasDraftOnly: filter === "draft",
          hasMarkedMessages: false,
          conversationTypes: conversationFilters.conversationType ? [conversationFilters.conversationType as never] : [],
          limit: 100,
        });
        nextConversations = [...response.conversations];
      } else if (filter !== "all") {
        const response = await client.conversations.listConversationsByQuery({
          keyword: "",
          includeArchived: conversationFilters.includeArchived,
          unreadOnly: filter === "unread",
          mentionMeOnly: filter === "mention",
          pinnedOnly: filter === "pinned",
          hasDraftOnly: filter === "draft",
          hasMarkedMessages: false,
          conversationTypes: [],
          limit: 100,
        });
        nextConversations = [...response.conversations];
      } else {
        const snapshot = await bootstrapHome(100);
        nextConversations = [...snapshot.conversations];
      }
      if (filter === "unread") {
        nextConversations = nextConversations.filter((item) => Number(item.unreadCount) > 0);
      }
      if (filter === "muted") {
        nextConversations = nextConversations.filter((item) => item.isMuted);
      }
      conversations.value = nextConversations.filter((item) => item.conversationId.trim());
      if (!activeConversationId.value) {
        ensureActiveConversationSelection();
      }
      refreshDerivedState();
      await openConversationListView("refresh");
    } catch (error) {
      if (!options.silent) {
        conversationSyncError.value = errorMessage(error);
        log("conversation_sync_failed", conversationSyncError.value);
      }
      throw error;
    } finally {
      if (!options.silent) {
        conversationSyncing.value = false;
      }
    }
  }

  async function setConversationFilter(filter: ConversationFilter): Promise<void> {
    conversationFilters.filter = filter;
    conversationFilters.includeArchived = filter === "archived";
    await refreshConversations();
  }

  async function refreshMessages(
    conversationId = activeConversationId.value,
    options: MessageRefreshOptions = {},
  ): Promise<void> {
    messageSyncError.value = "";
    const targetId = conversationId.trim();
    if (!targetId) {
      messages.value = [];
      messageHasMore.value = false;
      refreshDerivedState();
      return;
    }
    if (!options.silent) {
      messageSyncing.value = true;
    }
    try {
      if (activeConversationId.value.trim() !== targetId) return;
      await openTimelineView(targetId, options.silent ? "silent_refresh" : "refresh", { force: true });
    } catch (error) {
      const detail = errorMessage(error);
      log("message_sync_failed", detail);
      messageSyncError.value = detail;
      throw error;
    } finally {
      if (!options.silent) {
        messageSyncing.value = false;
      }
    }
  }

  async function loadOlderMessages(options: LoadOlderMessagesOptions = {}): Promise<void> {
    const conversationId = activeConversationId.value.trim();
    const activeView = activeTimelineView;
    if (
      !conversationId
      || !activeView
      || activeView.conversationId !== conversationId
      || loadingOlderMessages.value
      || (!options.force && !messageHasMore.value)
    ) {
      return;
    }
    loadingOlderMessages.value = true;
    messageSyncError.value = "";
    try {
      const response = await client.views.loadOlderTimeline({
        viewId: activeView.viewId,
        messageLimit: options.limit ?? MESSAGE_PAGE_SIZE,
      });
      if (
        activeConversationId.value.trim() !== conversationId
        || activeTimelineView?.viewId !== response.viewId
      ) {
        return;
      }
      // 这一页只经 view.updated 推来；返回值说它在哪个版本里。事件还没到时取快照，保证返回前已应用。
      if ((activeTimelineView?.revision ?? 0) < response.revision) {
        await resyncTimelineView(response.viewId, "load_older");
      } else {
        refreshDerivedState();
      }
      log("view_timeline_load_older", `${conversationId}:${response.loadedCount}:${response.revision}`);
    } catch (error) {
      messageSyncError.value = errorMessage(error);
      log("message_sync_failed", messageSyncError.value);
      throw error;
    } finally {
      loadingOlderMessages.value = false;
    }
  }

  async function searchConversationsWithKeyword(keyword: string): Promise<void> {
    const query = keyword.trim();
    conversationSyncing.value = true;
    conversationSyncError.value = "";
    try {
      if (!query) {
        await refreshConversations();
        return;
      }
      const response = await client.conversations.listConversationsByQuery({
        keyword: query,
        includeArchived: conversationFilters.includeArchived,
        unreadOnly: false,
        mentionMeOnly: false,
        pinnedOnly: false,
        hasDraftOnly: false,
        hasMarkedMessages: false,
        conversationTypes: [],
        limit: 100,
      });
      conversations.value = [...response.conversations];
      refreshDerivedState();
    } catch (error) {
      conversationSyncError.value = errorMessage(error);
      throw error;
    } finally {
      conversationSyncing.value = false;
    }
  }

  async function refreshActivePeerPresence(peerUserId: string): Promise<string> {
    if (!peerUserId) return "offline";
    try {
      const dto = await client.presence.getUserPresence({ userId: peerUserId });
      await client.presence.subscribeUserPresence({ userIds: [peerUserId] });
      const status = presenceStatusFromCoreDto(dto);
      peerPresence.value = { ...peerPresence.value, [peerUserId]: status };
      if (/busy|dnd/i.test(status)) return "busy";
      if (/offline|away|invisible/i.test(status)) return "offline";
      return "online";
    } catch (error) {
      log("presence_refresh_failed", `${peerUserId}: ${errorMessage(error)}`);
      return peerPresence.value[peerUserId] ?? "offline";
    }
  }

  function applyPresenceChanged(event: PresenceChangedHint): void {
    const userId = String(event.userId ?? "").trim();
    if (!userId) return;
    const status = presenceStatusFromCoreDto(event);
    peerPresence.value = { ...peerPresence.value, [userId]: status };
  }

  async function runSessionDiagnostics(): Promise<void> {
    labBusy.value = true;
    try {
      const appDiagnostics = await refreshCoreDiagnostics();
      diagnostics.value = {
        sdkVersion: {
          ...appDiagnostics.sdkVersion,
          coreSdk: "flare-im-core-sdk",
          adapterBoundary: "TypeScript SDK -> flare-core-sdk-engine/bindings/wasm (real IMClient)",
          wasmBinding: {
            status: sdkRuntimeStatus.value,
            source: "flare-core-sdk-engine/bindings/wasm",
          },
        },
        ffi: appDiagnostics.ffiContract,
        dataRoot: appDiagnostics.dataRoot,
        runtimeHealth: appDiagnostics.runtimeHealth,
        currentUser: appDiagnostics.currentUser,
        sessionActive: appDiagnostics.sessionActive,
        isConnected: appDiagnostics.isConnected,
        connectionStatus: appDiagnostics.connectionStatus,
      };
      connectionStatus.value = appDiagnostics.connectionStatus;
      labResult.value = diagnostics.value;
      log("diagnostics", appDiagnostics.connectionStatus.phase);
      messageBuildCatalog.value = [...await refreshCoreMessageBuildCatalog()];
    } finally {
      labBusy.value = false;
    }
  }

  async function refreshMessageBuildCatalog(): Promise<void> {
    messageBuildCatalog.value = [...await refreshCoreMessageBuildCatalog()];
    if (!messageBuildCatalog.value.some((entry) => String(entry.op) === sdkLab.buildOp)) {
      sdkLab.buildOp = String(messageBuildCatalog.value[0]?.op ?? "create_text");
    }
  }

  async function initializeAndLogin(): Promise<void> {
    busy.value = true;
    const loginStartedAt = nowMs();
    homeSyncReady.value = false;
    homeSyncError.value = "";
    setHomeSyncProgress({
      step: "session",
      title: translateFlare("sync.connectTitle"),
      detail: translateFlare("sync.connectDetail"),
      percent: 8,
    });
    try {
      const tokenStartedAt = nowMs();
      const identity = applyLoginIdentity();
      logDuration("login_token_ready", tokenStartedAt);
      // 留空 = SDK 托管（核心签发并续期）；填了 = 应用托管（原样使用）。
      const token = String(form.token ?? "").trim();
      const coreLoginStartedAt = nowMs();
      // The protocol and the access point are the core's choice, per the build's access configuration.
      const snapshot = await initAndLoginCore({
        dataUrl: form.dataUrl,
        tenantId: identity.tenantId,
        userId: identity.userId,
        token,
      });
      logDuration("login_core_ready", coreLoginStartedAt);
      initialized.value = snapshot.session.initialized;
      loggedIn.value = snapshot.session.loggedIn;
      connectionStatus.value = snapshot.session.connectionStatus;
      currentUserId.value = snapshot.session.userId ?? identity.userId;
      sessionActive.value = Boolean(snapshot.diagnostics?.sessionActive);
      isConnected.value = Boolean(snapshot.diagnostics?.isConnected);
      sdkRuntimeStatus.value = defaultSdkRuntimeStatus;
      messageBuildCatalog.value = [...snapshot.messageBuildCatalog];
      setHomeSyncProgress({
        step: "session",
        title: translateFlare("sync.sessionReadyTitle"),
        detail: translateFlare("sync.sessionReadyDetail"),
        percent: 18,
      });
      persistSavedSessionProfile(savedSessionProfileFromForm(identity, token));
      log("login", `${identity.userId} connected`);
      logDuration("login_route_ready", loginStartedAt);
    } catch (error) {
      loggedIn.value = false;
      homeSyncReady.value = false;
      sdkRuntimeStatus.value = isRuntimeUnavailableError(error)
        ? "browser-unavailable"
        : defaultSdkRuntimeStatus;
      const detail = errorMessage(error);
      errorPayload(error, "sdk.login");
      log("login_failed", detail);
      if (isTokenRejectedError(error)) {
        // 网关拒掉了本地签发的 token：密钥/签发者与服务端不一致或已过期。
        // 原始错误是一长串 connect failed primary=... 的传输层描述，对用户没有意义。
        throw new Error(translateFlare("login.tokenRejected"), { cause: error });
      }
      throw error;
    } finally {
      busy.value = false;
    }
  }

  function savedSessionProfileFromForm(identity: LoginIdentity, token: string): SavedSessionProfile {
    return {
      userId: identity.userId,
      tenantId: identity.tenantId,
      token,
      dataUrl: form.dataUrl,
      savedAtMs: Date.now(),
    };
  }

  function applySavedSessionToForm(profile: SavedSessionProfile): void {
    form.userId = profile.userId;
    form.tenantId = profile.tenantId;
    form.token = profile.token;
    if (profile.dataUrl) form.dataUrl = profile.dataUrl;
  }

  function hasSavedSession(): boolean {
    return loadSavedSessionProfile() !== undefined;
  }

  let sessionResumeInFlight: Promise<boolean> | undefined;

  /**
   * 热启动路径：本地库直出首屏（prepare + bootstrapStartupHome，不等网络），
   * 连接与增量同步在后台补齐。成功返回 true 时 UI 可直接进入工作台。
   */
  function resumeSavedSession(): Promise<boolean> {
    if (loggedIn.value) return Promise.resolve(true);
    sessionResumeInFlight ??= resumeSavedSessionInner().finally(() => {
      sessionResumeInFlight = undefined;
    });
    return sessionResumeInFlight;
  }

  async function resumeSavedSessionInner(): Promise<boolean> {
    const profile = loadSavedSessionProfile();
    if (!profile) return false;
    const resumeStartedAt = nowMs();
    busy.value = true;
    setHomeSyncProgress({
      step: "session",
      title: translateFlare("sync.restoreTitle"),
      detail: translateFlare("sync.restoreDetail"),
      percent: 30,
    });
    try {
      applySavedSessionToForm(profile);
      // SDK 托管会话(空 token)热恢复同样交给 SDK 签发,与登录路径 initAndLoginCore 一致。
      await client.init(coreSdkConfig({ dataUrl: form.dataUrl, tenantId: profile.tenantId, token: profile.token }));
      await client.events.subscribeEvents({ sources: [...sdkEventSources] });
      await withTimeout(
        client.prepare({ userId: profile.userId, token: profile.token }),
        CORE_LOGIN_STEP_TIMEOUT_MS,
        () => sdkOperationTimeoutError("login.prepare", CORE_LOGIN_STEP_TIMEOUT_MS),
      );
      initialized.value = true;
      loggedIn.value = true;
      currentUserId.value = profile.userId;
      sdkRuntimeStatus.value = defaultSdkRuntimeStatus;
      // T0 本地水合：后台收敛等 connect 成功后再启动，避免离线时空转
      const startupHome = await withTimeout(
        client.sync.bootstrapStartupHome({
          conversationLimit: 100,
          startBackgroundConvergence: false,
          backfillVisibleHistories: false,
          historyBackfillLimit: FULL_HISTORY_BACKFILL_SYNC_LIMIT,
          historyBackfillMaxPagesPerConversation: FULL_HISTORY_BACKFILL_MAX_ROUNDS,
          historyBackfillMaxConversations: 100,
        }),
        STARTUP_HOME_SYNC_TIMEOUT_MS,
        () => sdkOperationTimeoutError("sync.bootstrap_startup_home", STARTUP_HOME_SYNC_TIMEOUT_MS),
      );
      applyConversationListViewSnapshot(startupHome.snapshot);
      await openConversationListView("hot_resume");
      ensureActiveConversationSelection();
      refreshDerivedState();
      homeSyncReady.value = true;
      setHomeSyncProgress({
        step: "ready",
        title: translateFlare("sync.localReadyTitle"),
        detail: translateFlare("sync.localReadyDetail"),
        percent: 100,
      });
      log("session_resume_local_ready", `${conversations.value.length} conversations`);
      logDuration("session_resume_local_ready", resumeStartedAt);
      void connectResumedSessionInBackground(profile);
      return true;
    } catch (error) {
      log("session_resume_failed", errorMessage(error));
      clearSavedSessionProfile();
      loggedIn.value = false;
      homeSyncReady.value = false;
      setHomeSyncProgress({
        step: "idle",
        title: translateFlare("sync.prepareTitle"),
        detail: translateFlare("sync.prepareDetail"),
        percent: 0,
      });
      return false;
    } finally {
      busy.value = false;
    }
  }

  async function connectResumedSessionInBackground(profile: SavedSessionProfile): Promise<void> {
    const connectStartedAt = nowMs();
    try {
      try {
        await client.connect(
          profile.token ? { userId: profile.userId, token: profile.token } : { userId: profile.userId },
        );
      } catch (error) {
        // A failure the link recovers from by itself (offline, timeouts, overload) is not an error here: the SDK
        // keeps the session and `connection://status` says how it goes. What is left is final, such as a rejected
        // token. A saved app-hosted token may have expired or been revoked: connect without it, the SDK issues one.
        if (!profile.token) throw error;
        log("session_resume_connect_retry", errorMessage(error));
        await client.connect({ userId: profile.userId });
        form.token = "";
        persistSavedSessionProfile(
          savedSessionProfileFromForm(
            { userId: profile.userId, tenantId: profile.tenantId },
            "",
          ),
        );
      }
      isConnected.value = true;
      sessionActive.value = true;
      await refreshConnectionStatusSafely("session_resume");
      logDuration("session_resume_connected", connectStartedAt);
      // 连接建立后启动前台收敛，把离线期间的增量补齐（core 内部静默去重）
      void client.sync.bootstrapStartupHome({
        conversationLimit: 100,
        startBackgroundConvergence: true,
        backfillVisibleHistories: false,
        historyBackfillLimit: FULL_HISTORY_BACKFILL_SYNC_LIMIT,
        historyBackfillMaxPagesPerConversation: FULL_HISTORY_BACKFILL_MAX_ROUNDS,
        historyBackfillMaxConversations: 100,
      }).then((startupHome) => {
        applyConversationListViewSnapshot(startupHome.snapshot);
        refreshDerivedState();
      }).catch((error) => {
        log("session_resume_convergence_failed", errorMessage(error));
      });
      try {
        messageBuildCatalog.value = [...await refreshCoreMessageBuildCatalog()];
      } catch (error) {
        log("session_resume_catalog_failed", errorMessage(error));
      }
    } catch (error) {
      // Not a sign-out either: the local view stays readable and the connection notice follows
      // `connection://status`, which offers signing in again when the session is over.
      log("session_resume_connect_failed", errorMessage(error));
      await refreshConnectionStatusSafely("session_resume_connect_failed");
    }
  }

  async function syncHomeBeforeEnter(): Promise<void> {
    if (!loggedIn.value) {
      throw new Error(translateFlare("error.loginBeforeSync"));
    }
    if (homeSyncReady.value && conversations.value.length) {
      return;
    }
    homeSyncing.value = true;
    homeSyncError.value = "";
    const syncStartedAt = nowMs();
    try {
      setHomeSyncProgress({
        step: "session",
        title: translateFlare("sync.checkTitle"),
        detail: translateFlare("sync.checkDetail"),
        percent: 20,
      });
      await refreshConnectionStatusSafely("home_sync");
      setHomeSyncProgress({
        step: "conversations",
        title: translateFlare("sync.syncTitle"),
        detail: translateFlare("sync.syncDetail"),
        percent: 45,
      });
      const startupHome = await withTimeout(
        Promise.resolve().then(() => client.sync.bootstrapStartupHome({
          conversationLimit: 100,
          startBackgroundConvergence: true,
          backfillVisibleHistories: false,
          historyBackfillLimit: FULL_HISTORY_BACKFILL_SYNC_LIMIT,
          historyBackfillMaxPagesPerConversation: FULL_HISTORY_BACKFILL_MAX_ROUNDS,
          historyBackfillMaxConversations: 100,
        })),
        STARTUP_HOME_SYNC_TIMEOUT_MS,
        () => sdkOperationTimeoutError("sync.bootstrap_startup_home", STARTUP_HOME_SYNC_TIMEOUT_MS),
      );
      setHomeSyncProgress({
        step: "unread",
        title: translateFlare("sync.applyTitle"),
        detail: translateFlare("sync.applyDetail"),
        percent: 70,
      });
      applyConversationListViewSnapshot(startupHome.snapshot);
      await openConversationListView("home_sync");
      ensureActiveConversationSelection();
      refreshDerivedState();
      if (startupHome.degradedReason) {
        log("home_startup_sync_degraded", startupHome.degradedReason);
      }
      setHomeSyncProgress({
        step: "preview",
        title: translateFlare("sync.previewTitle"),
        detail: startupHome.backgroundConvergenceStarted
          ? translateFlare("sync.previewDetailBackground")
          : translateFlare("sync.previewDetail"),
        percent: 90,
      });
      homeSyncReady.value = true;
      setHomeSyncProgress({
        step: "ready",
        title: translateFlare("sync.doneTitle"),
        detail: translateFlare("sync.doneDetail"),
        percent: 100,
      });
      log("home_sync_ready", `${conversations.value.length} conversations`);
      logDuration("home_sync_ready", syncStartedAt);
    } catch (error) {
      homeSyncReady.value = false;
      homeSyncError.value = errorMessage(error);
      setHomeSyncProgress({
        step: "failed",
        title: translateFlare("sync.failedTitle"),
        detail: homeSyncError.value || translateFlare("sync.failedDetail"),
        percent: 100,
      });
      log("home_sync_failed", homeSyncError.value);
      throw error;
    } finally {
      homeSyncing.value = false;
    }
  }

  function applyLoginIdentity(): LoginIdentity {
    const identity = normalizeLoginIdentityForSdk(form);
    form.userId = identity.userId;
    form.tenantId = identity.tenantId;
    return identity;
  }

  /**
   * 业务端推送用户资料(名称/头像)到本地身份缓存。读路径(消息/会话)批量 join 缓存渲染
   * 当前身份;缓存 miss 回退消息内嵌的发送时快照。业务同步好友/用户/群有变化时调用。
   */
  async function upsertUserProfiles(
    profiles: Array<{ userId: string; nickname?: string; avatarUrl?: string }>,
  ): Promise<void> {
    const sanitized = profiles
      .map((p) => ({
        userId: String(p.userId ?? "").trim(),
        nickname: String(p.nickname ?? ""),
        avatarUrl: String(p.avatarUrl ?? ""),
      }))
      .filter((p) => p.userId.length > 0);
    if (sanitized.length === 0) return;
    await client.user.upsertUserProfiles({ profiles: sanitized });
    log("user", `upsert_profiles:${sanitized.length}`);
  }

  // DEV-only 调试钩子:便于在浏览器/E2E 中验证身份缓存写入口(生产构建不挂载)。
  if (typeof window !== "undefined" && import.meta.env?.DEV) {
    (window as unknown as Record<string, unknown>).__flareUpsertUserProfiles =
      upsertUserProfiles;
  }

  async function logout(): Promise<void> {
    invalidateActiveSearch();
    clearSavedSessionProfile();
    await disposeOpenViewsAndEvents("logout");
    await client.logout();
    loggedIn.value = false;
    homeSyncReady.value = false;
    homeSyncing.value = false;
    resetMessageOpening();
    messageSyncing.value = false;
    conversationListViewId = "";
    activeTimelineView = null;
    homeSyncError.value = "";
    setHomeSyncProgress({
      step: "idle",
      title: translateFlare("sync.prepareTitle"),
      detail: translateFlare("sync.prepareDetail"),
      percent: 0,
    });
    await refreshConnectionStatusSafely("logout");
    log("logout", "session closed");
  }

  async function selectConversation(conversationId: string): Promise<void> {
    activeConversationId.value = conversationId;
    refreshDerivedState();
    await enterActiveConversation("select");
  }

  function localStateForMessage(
    message: Message,
    patch: Partial<NonNullable<Message["localState"]>>,
  ): NonNullable<Message["localState"]> {
    return {
      failed: false,
      isLocal: false,
      sending: false,
      sortTs: message.localState?.sortTs ?? message.clientCreatedAt ?? Date.now(),
      uploadProgress: 0,
      uploading: false,
      ...message.localState,
      ...patch,
    };
  }

  function patchMessageByClientId(
    clientMsgId: string,
    update: (message: Message) => Message,
  ): boolean {
    const id = clientMsgId.trim();
    if (!id) return false;
    let changed = false;
    messages.value = messages.value.map((item) => {
      if (item.clientMsgId !== id) return item;
      changed = true;
      return update(item);
    });
    return changed;
  }

  function localTimelineSortTs(message: Message): number {
    return message.timelineSortTs || message.clientCreatedAt || message.createdAt || Date.now();
  }

  function outgoingTimelineKey(message: Message): string {
    return message.timelineKey.trim()
      || (message.clientMsgId ? `client:${message.clientMsgId}` : "")
      || message.serverId.trim();
  }

  function patchConversationLastOutgoing(message: Message): void {
    const conversationId = message.conversationId.trim();
    if (!conversationId) return;
    const preview = message.textPreview.trim();
    const at = localTimelineSortTs(message);
    const lastMessageId = message.serverId.trim() || message.clientMsgId.trim();
    let changed = false;
    const patch = (item: Conversation): Conversation => {
      if (item.conversationId !== conversationId) return item;
      changed = true;
      return {
        ...item,
        draft: "",
        lastMessageAt: at,
        lastMessageId: lastMessageId || item.lastMessageId,
        lastMessagePreview: preview || item.lastMessagePreview,
        lastSenderId: message.senderId || currentUserId.value || item.lastSenderId,
        lastSenderNickname: message.senderDisplayName || message.senderName || item.lastSenderNickname,
        updatedAt: Math.max(Number(item.updatedAt) || 0, at),
        updatedAtTs: Math.max(Number(item.updatedAtTs ?? item.updatedAt) || 0, at),
      };
    };
    conversations.value = conversations.value.map(patch);
    if (activeConversation.value?.conversationId === conversationId) {
      activeConversation.value = patch(activeConversation.value);
    }
    if (changed) {
      refreshDerivedState();
    }
  }

  function upsertOutgoingMessageInActiveTimeline(
    message: Message,
    localStatePatch: Partial<NonNullable<Message["localState"]>>,
  ): void {
    const conversationId = message.conversationId.trim();
    if (!conversationId || conversationId !== activeConversationId.value.trim()) return;
    const timelineKey = outgoingTimelineKey(message);
    const timelineSortTs = localTimelineSortTs(message);
    const nextMessage: Message = {
      ...message,
      timelineKey,
      timelineSortTs,
      createdAt: message.createdAt || timelineSortTs,
      updatedAt: message.updatedAt || timelineSortTs,
      status: message.status > 0 ? message.status : 1,
      localState: localStateForMessage(
        { ...message, timelineKey, timelineSortTs },
        localStatePatch,
      ),
    };
    const clientMsgId = nextMessage.clientMsgId.trim();
    const serverId = nextMessage.serverId.trim();
    const existingIndex = messages.value.findIndex((item) =>
      (clientMsgId && item.clientMsgId === clientMsgId)
      || (timelineKey && item.timelineKey === timelineKey)
      || (serverId && item.serverId === serverId),
    );
    if (existingIndex >= 0) {
      const next = [...messages.value];
      next[existingIndex] = {
        ...next[existingIndex],
        ...nextMessage,
        localState: localStateForMessage(nextMessage, localStatePatch),
      };
      messages.value = next;
    } else {
      messages.value = [...messages.value, nextMessage];
    }
    patchConversationLastOutgoing(nextMessage);
  }

  function markMessageSending(message: Message): void {
    upsertOutgoingMessageInActiveTimeline(message, {
      failed: false,
      isLocal: true,
      sending: true,
      // 不要在这里写死 uploading: false。
      //
      // 带本地媒体的消息由**核心**置为 uploading 并按字节回填 upload_progress
      // （send_with_media 在上传前就落库并发总线）。这里一刀切成 false 会把核心的
      // 上传态盖掉，气泡上的进度覆盖层就永远不显示——线上实测 8MB 图片上传约 1.2s，
      // 核心存储里确实是 uploading:true，而 UI 全程 uploading:0。
      //
      // 保留消息自身的上传态：纯文本本来就没有，媒体则跟随核心。
      uploading: message.localState?.uploading ?? false,
      uploadProgress: message.localState?.uploadProgress ?? 0,
    });
  }

  function markMessageSent(message: Message, ack: SendMessageResponse): void {
    patchMessageByClientId(ack.clientMsgId || message.clientMsgId, (item) => ({
      ...item,
      serverId: ack.serverId || item.serverId,
      conversationSeq: ack.seq > 0 ? ack.seq : item.conversationSeq,
      updatedAt: ack.timestamp > 0 ? ack.timestamp : item.updatedAt,
      status: Math.max(item.status, 2),
      localState: localStateForMessage(item, {
        failed: false,
        isLocal: true,
        sending: false,
        uploading: false,
        uploadProgress: 100,
      }),
    }));
  }

  function markMessageFailed(message: Message): void {
    patchMessageByClientId(message.clientMsgId, (item) => ({
      ...item,
      localState: localStateForMessage(item, {
        failed: true,
        isLocal: true,
        sending: false,
        uploading: false,
      }),
    }));
  }

  async function sendBuiltMessage(message: Message, callback?: MessageSendCallback): Promise<void> {
    markMessageSending(message);
    activeOutgoingSends += 1;
    lastOutgoingSendAt = Date.now();
    try {
      await sendMessageWithTimeout(message, {
        onSuccess: ({ ack }) => {
          markMessageSent(message, ack);
          log("send_ack", `${ack.conversationId}#${ack.seq}`);
          callback?.onSuccess?.({ ack });
        },
        onFailure: (failure) => {
          markMessageFailed(message);
          log("send_failed", failure.reason);
          callback?.onFailure?.(failure);
        },
      });
    } catch (error) {
      markMessageFailed(message);
      throw error;
    } finally {
      activeOutgoingSends = Math.max(0, activeOutgoingSends - 1);
      lastOutgoingSendAt = Date.now();
    }
  }

  function conversationMentionUserIds(conversation: Conversation | null | undefined): string[] {
    if (!conversation) return [];
    const currentUserId = form.userId.trim();
    const ids = new Set<string>();
    const add = (value: unknown): void => {
      if (typeof value !== "string") return;
      const id = value.trim();
      if (!id || id === currentUserId) return;
      ids.add(id);
    };
    for (const participant of conversation.participants ?? []) add(participant.userId);
    for (const participant of conversation.memberPreview ?? []) add(participant.userId);
    const channel = conversation.channelId?.trim() ?? "";
    if (channel.startsWith("users:")) {
      for (const item of channel.slice("users:".length).split(/[,\s，、;；|]+/)) add(item);
    }
    return [...ids];
  }

  
  async function sendText(text: string, mentionUsers: readonly string[] = []): Promise<void> {
    if (!activeConversationId.value) {
      throw new Error(translateFlare("error.openConversationBeforeSend"));
    }
    const conversationId = activeConversationId.value;
    try {
      // 提及由**核心**从正文解析（`@全员` / `@所有人` / `@all` / `@某人`，含中文显示名）。
      // 这里只把用户显式选中的人透传过去，与核心的解析结果取并集。
      // 曾经在这一层用 `/(^|\s)@all(\s|$)/i` 判定 @全员：中文打 `@全员` 不生效，
      // 而其余四端根本不解析 —— 同样的文字在不同端产生不同的消息。
      const draft = await client.messageBuilder.buildText({
        conversationId,
        text,
        mentionUsers: [...mentionUsers],
        mentionAll: false,
      });
      await sendBuiltMessage(draft);
      void clearConversationDraft(conversationId).catch((error) => {
        log("draft_clear_failed", errorMessage(error));
      });
    } catch (error) {
      log("send_failed", errorMessage(error));
      throw error;
    }
  }

  async function sendTypedMessage(request: Omit<BuildAndSendMessageRequest, "conversationId"> & { conversationId?: string }): Promise<void> {
    const conversationId = request.conversationId ?? activeConversationId.value;
    if (!conversationId) return;
    const draft = await buildTypedMessage({
      conversationId,
      op: request.op,
      params: request.params ?? {},
      callback: request.callback,
    });
    await sendBuiltMessage(draft, request.callback);
    log("send_message", draft.clientMsgId || draft.serverId || conversationId);
  }

  async function buildAndSendMessage(op = sdkLab.buildOp, overrides: Record<string, unknown> = {}): Promise<void> {
    if (!activeConversationId.value) {
      throw new Error(translateFlare("error.openConversationBeforeSend"));
    }
    const conversationId = activeConversationId.value;
    const params = {
      text: sdkLab.messageText,
      emoji: sdkLab.messageText || sdkLab.reaction,
      ...parseJsonParams(sdkLab.jsonParams),
      ...overrides,
    };
    try {
      const draft = await buildTypedMessage({
        op,
        conversationId,
        params,
      });
      await sendBuiltMessage(draft);
      void clearConversationDraft(conversationId).catch((error) => {
        log("draft_clear_failed", errorMessage(error));
      });
      log("send_message", draft.clientMsgId || draft.serverId || conversationId);
    } catch (error) {
      throw error;
    }
  }

  async function buildFromComposerAction(op: string, composerText = ""): Promise<void> {
    if (op === "create_text") {
      await sendText(composerText || sdkLab.messageText);
      return;
    }
    await buildAndSendMessage(op, { text: composerText || sdkLab.messageText });
  }

  async function resendFailedMessage(clientMsgId: string): Promise<void> {
    const message = messages.value.find((item) => item.clientMsgId === clientMsgId);
    if (!message) return;
    await sendBuiltMessage(message);
  }

  async function forwardMessagesToConversation(request: {
    conversationId: string;
    messageIds: string[];
    merge?: boolean;
    title?: string;
  }): Promise<Message> {
    // 必须传完整消息而不是 id 存根：转发的载荷要把原文内容嵌进去，核心侧的
    // forward_item_from_source 会读 content / senderId / conversationId。
    // 早先按契约传 { sourceMessageId }，反序列化成 IMMessage 时缺必填字段直接
    // INVALID_PARAMETER，转发每次都失败——契约本身写错了，已在 spec 侧改为
    // MessageList。
    const sources = request.messageIds.map((messageId) => {
      const found = messages.value.find((row) => messageMatchesId(row, messageId));
      if (!found) {
        throw new Error(translateFlare("error.forwardSourceMissing", { id: messageId }));
      }
      return found;
    });
    const draft = await client.messageBuilder.buildForward({
      conversationId: request.conversationId,
      sourceMessages: sources,
      merge: request.merge ?? false,
      title: request.title ?? "",
    });
    await sendBuiltMessage(draft);
    return draft;
  }

  async function sendEmoji(emoji: string): Promise<void> {
    await buildAndSendMessage("create_emoji", { emoji });
  }

  async function sendSticker(sticker: string | {
    stickerId: string;
    packageId?: string;
    url?: string;
    width?: number;
    height?: number;
    stickerFormat?: string;
    format?: string;
  }): Promise<void> {
    const payload = typeof sticker === "string" ? { stickerId: sticker } : sticker;
    await buildAndSendMessage("create_sticker", payload);
  }

  async function addReaction(messageId: string, emoji: string): Promise<void> {
    const conversationId = activeConversationId.value.trim();
    const target = messages.value.find((message) => messageMatchesId(message, messageId));
    if (!conversationId || !messageId || !emoji) return;
    const wireMessageId = target?.serverId?.trim() || messageId;
    const clientMsgId = target?.clientMsgId?.trim() || messageId;
    await client.messages.addReaction({
      conversationId,
      messageId: wireMessageId,
      clientMsgId,
      emoji,
    });
    patchLocalReaction(messageId, emoji, currentUserId.value.trim(), 1);
  }

  async function removeReaction(messageId: string, emoji: string): Promise<void> {
    const conversationId = activeConversationId.value.trim();
    const target = messages.value.find((message) => messageMatchesId(message, messageId));
    if (!conversationId || !messageId || !emoji) return;
    const wireMessageId = target?.serverId?.trim() || messageId;
    const clientMsgId = target?.clientMsgId?.trim() || messageId;
    await client.messages.removeReaction({
      conversationId,
      messageId: wireMessageId,
      clientMsgId,
      emoji,
    });
    patchLocalReaction(messageId, emoji, currentUserId.value.trim(), 2);
  }

  async function toggleReaction(messageId: string, emoji: string): Promise<void> {
    const userId = currentUserId.value.trim();
    const target = messages.value.find((message) => messageMatchesId(message, messageId));
    const active = target?.reactions?.some((reaction) =>
      reaction.emoji === emoji && (reaction.userIds ?? []).includes(userId),
    );
    if (active) {
      await removeReaction(messageId, emoji);
      return;
    }
    await addReaction(messageId, emoji);
  }

  async function saveActiveDraft(draft: string): Promise<void> {
    if (!activeConversationId.value) return;
    await clearConversationDraft(activeConversationId.value, draft);
  }

  function patchConversationDraft(conversationId: string, draft: string): void {
    const targetId = conversationId.trim();
    if (!targetId) return;
    let changed = false;
    conversations.value = conversations.value.map((item) => {
      if (item.conversationId !== targetId || item.draft === draft) return item;
      changed = true;
      return { ...item, draft };
    });
    if (activeConversation.value?.conversationId === targetId && activeConversation.value.draft !== draft) {
      activeConversation.value = { ...activeConversation.value, draft };
      changed = true;
    }
    if (changed) {
      refreshDerivedState();
    }
  }

  async function clearConversationDraft(conversationId: string, draft = ""): Promise<void> {
    if (!conversationId) return;
    patchConversationDraft(conversationId, draft);
    const retryDelays = [180, 420, 900] as const;
    for (let attempt = 0; attempt <= retryDelays.length; attempt += 1) {
      try {
        await client.conversations.updateConversationDraft({ conversationId, draft });
        patchConversationDraft(conversationId, draft);
        return;
      } catch (error) {
        const delay = retryDelays[attempt];
        if (!isDatabaseLockedError(error) || delay === undefined) {
          if (!draft && isTimeoutError(error)) return;
          log("draft_clear_failed", errorMessage(error));
          return;
        }
        await wait(delay);
      }
    }
  }

  async function sendTyping(typing = true): Promise<void> {
    if (!activeConversationId.value) return;
    if (connectionPhase.value !== "online") return;
    try {
      await client.messages.setTyping({ conversationId: activeConversationId.value, typing });
    } catch (error) {
      // Typing is best effort; a dropped link shows up in `connection://status`, not here.
      if (/OPERATION_TIMEOUT|NOT_CONNECTED|CLOSING|CLOSED|typing|realtime control/i.test(errorMessage(error))) return;
      throw error;
    }
  }

  async function searchActiveMessages(
    keyword: string,
    kinds: readonly MessageSearchKind[],
    timeRange: FlareSearchTimeRange = {},
  ): Promise<void> {
    const own = ++activeSearchGeneration;
    const conversationId = activeConversationId.value;
    const query = keyword.trim();
    messageSearchResults.value = [];
    if (!query) return;
    if (!validSearchTimeRange(timeRange)) throw new Error("搜索时间范围无效");
    try {
      const results = await searchMessages({
        conversationId,
        keyword: query,
        fromTime: timeRange.fromTime,
        toTime: timeRange.toTime,
        kinds: [...kinds],
        limit: 50,
        includeRecalled: false,
      });
      if (own === activeSearchGeneration && conversationId === activeConversationId.value) {
        messageSearchResults.value = [...results];
      }
    } catch (error) {
      if (own === activeSearchGeneration) throw error;
    }
  }

  async function editMessageText(messageId: string, text: string): Promise<void> {
    const targetId = messageId.trim();
    const nextText = text.trim();
    if (!targetId || !nextText) return;
    try {
      await client.messages.editTextByMessageId({
        messageId: targetId,
        text: nextText,
      });
    } catch (error) {
      log("edit.failed", errorMessage(error));
      throw error;
    }
  }

  async function setMessagePinned(
    messageId: string,
    pinned: boolean,
    options: { scope?: "conversation" | "self" } = {},
  ): Promise<void> {
    const targetId = messageId.trim();
    if (!targetId) return;
    const request = {
      messageId: targetId,
      scope: options.scope === "self" ? 1 : 0,
    };
    const call = pinned
      ? client.messages.pinMessageById(request)
      : client.messages.unpinMessageById(request);
    try {
      await call;
    } catch (error) {
      log(pinned ? "pin.failed" : "unpin.failed", errorMessage(error));
      throw error;
    }
  }

  async function deleteMessageForSelf(messageId: string): Promise<void> {
    const targetId = messageId.trim();
    if (!targetId) return;
    try {
      await client.messages.deleteMessageForSelf({
        messageId: targetId,
      });
      removeMessageById(targetId);
    } catch (error) {
      log("delete.failed", errorMessage(error));
      throw error;
    }
  }

  async function recallMessageById(messageId: string): Promise<void> {
    const targetId = messageId.trim();
    if (!targetId) return;
    try {
      await client.messages.recallMessage({
        messageId: targetId,
      });
    } catch (error) {
      log("recall.failed", errorMessage(error));
      throw error;
    }
  }

  async function runDispatch(op = sdkLab.dispatchOp): Promise<void> {
    // 走 runLab：此前这里既不捕获异常也不管 labBusy，dispatchMessage 一旦 reject，
    // labResult 的赋值根本不会发生，异常直接冲出点击处理器变成 unhandled rejection。
    // 界面上于是完全没有反馈——结果面板停在上一次的输出，既没有报错也没有 loading，
    // 看起来就像"按钮没反应"。消息右键菜单里的标记等操作同样经由这里，一并失声。
    await runLab("message.dispatch", async () => {
      const messageIdValue = sdkLab.messageId || activeLatestMessageId.value;
      const params = buildMessageDispatchParams({
        conversationId: activeConversationId.value,
        messageId: messageIdValue,
        text: sdkLab.messageText,
        keyword: sdkLab.query,
        emoji: sdkLab.reaction,
        jsonParams: parseJsonParams(sdkLab.jsonParams),
      });
      const result = await dispatchMessage(op, params);
      if (shouldRefreshTimelineAfterDispatch(op)) {
        await refreshActiveChat();
      }
      return result as Record<string, unknown>;
    });
  }

  async function syncActiveConversation(): Promise<void> {
    conversationSyncing.value = true;
    conversationSyncError.value = "";
    try {
      if (activeConversationId.value) {
        await client.sync.syncConversation({ conversationId: activeConversationId.value });
        await syncMessagesFromKnownCursor(activeConversationId.value);
      }
      await refreshActiveChat();
      log("sync", activeConversationId.value || "all");
    } catch (error) {
      conversationSyncError.value = errorMessage(error);
      log("sync_failed", conversationSyncError.value);
      throw error;
    } finally {
      conversationSyncing.value = false;
    }
  }

  async function refreshActiveChat(): Promise<void> {
    await refreshConversations();
    await refreshMessages();
  }

  async function deleteActiveConversation(conversationId = activeConversationId.value): Promise<boolean> {
    if (!conversationId) return false;
    await client.conversations.deleteConversation({ conversationId });
    if (activeConversationId.value === conversationId) {
      activeConversationId.value = "";
      resetMessageOpening();
      refreshDerivedState();
      messages.value = [];
    }
    await refreshConversations();
    return true;
  }

  async function syncConversationsFromServer(): Promise<void> {
    conversationSyncing.value = true;
    conversationSyncError.value = "";
    try {
      await syncConversationSummaries();
      await refreshConversations();
      await backfillVisibleConversationHistories("manual_sync");
      if (activeConversationId.value) {
        await client.sync.syncConversation({ conversationId: activeConversationId.value });
        await syncMessagesFromKnownCursor(activeConversationId.value);
        await refreshMessages();
      }
      log("sync_conversations", activeConversationId.value || "list");
    } catch (error) {
      conversationSyncError.value = errorMessage(error);
      log("sync_failed", conversationSyncError.value);
      throw error;
    } finally {
      conversationSyncing.value = false;
    }
  }

  async function runConversationOperation(kind: string, conversationId = activeConversationId.value): Promise<void> {
    log("conversation_operation_start", `${kind}:${conversationId}`);
    if (kind === "mark_unread") {
      await client.conversations.markConversationUnread({ conversationId });
    } else if (kind === "mark_read") {
      await markConversationRead(conversationId);
    } else if (kind === "pin" || kind === "unpin") {
      await client.conversations.setConversationPinned({ conversationId, pinned: kind === "pin" });
    } else if (kind === "mute" || kind === "unmute") {
      await client.conversations.setConversationMuted({ conversationId, muted: kind === "mute" });
    } else if (kind === "archive" || kind === "unarchive") {
      await client.conversations.setConversationArchived({ conversationId, archived: kind === "archive" });
    } else if (kind === "clear_history") {
      await client.conversations.clearLocalChatHistory({ conversationId });
    } else if (kind === "draft") {
      await client.conversations.updateConversationDraft({ conversationId, draft: sdkLab.draft });
    } else if (kind === "delete") {
      await deleteActiveConversation(conversationId);
    } else {
      labResult.value = { conversations: await listConversations() };
    }
    await refreshConversations();
    // Metadata changes must not reopen the timeline and immediately mark it read.
    if ((kind === "clear_history" || kind === "mark_read") && activeConversationId.value === conversationId) {
      await refreshMessages();
    }
    log("conversation_operation_complete", `${kind}:${conversationId}`);
  }

  async function runSyncOperation(kind: string): Promise<void> {
    if (kind === "read") {
      await markConversationRead(activeConversationId.value);
    } else if (kind === "messages") {
      messageSyncing.value = true;
      messageSyncError.value = "";
      try {
        await syncMessagesFromKnownCursor(activeConversationId.value);
      } catch (error) {
        messageSyncError.value = errorMessage(error);
        log("message_sync_failed", messageSyncError.value);
        throw error;
      } finally {
        messageSyncing.value = false;
      }
    } else {
      await client.sync.syncConversation({ conversationId: activeConversationId.value });
    }
    await refreshConversations();
    await refreshMessages();
  }

  async function runPresenceOperation(kind: string): Promise<void> {
    await runLab(`presence.${kind}`, async () => {
      const userIds = sdkLab.userIds.split(",").map((item) => item.trim()).filter(Boolean);
      if (kind === "get") {
        return await client.presence.getUserPresence({ userId: userIds[0] ?? form.userId });
      }
      if (kind === "subscribe") {
        await client.presence.subscribeUserPresence({ userIds });
        return { subscribed: userIds };
      }
      return await client.presence.batchGetUserPresence({ userIds });
    });
  }

  async function runMediaOperation(kind: string): Promise<void> {
    await runLab(`media.${kind}`, async () => {
      const params = parseJsonParams(sdkLab.jsonParams);
      if (kind === "clear") {
        await client.media.clearMediaCache();
        return { cleared: true };
      }
      if (kind === "upload_file" || kind === "upload_image" || kind === "upload_video") {
        const payload = {
          path: sdkLab.sourcePath,
          fileId: sdkLab.fileId,
          fileName: sdkLab.displayFileName,
          ...params,
        };
        if (kind === "upload_image") return await client.media.uploadImage(payload);
        if (kind === "upload_video") return await client.media.uploadVideo(payload);
        return await client.media.uploadFile(payload);
      }
      if (kind === "upload_bytes") {
        const bytes = new TextEncoder().encode(`Flare Web SDK Lab ${new Date().toISOString()}`);
        return await client.media.uploadBytes({
          bytes: Array.from(bytes),
          fileName: sdkLab.displayFileName,
          mimeType: "text/plain",
          ...params,
        });
      }
      if (kind === "delete_file") {
        return await client.media.deleteFile({
          fileId: sdkLab.fileId,
          hardDelete: Boolean(params.hardDelete),
          ...params,
        });
      }
      if (kind === "url") {
        return await client.media.getMediaUrl({ fileId: sdkLab.fileId, mediaUrl: sdkLab.mediaUrl });
      }
      if (kind === "temp_url") {
        return await client.media.getTempDownloadUrl({ fileId: sdkLab.fileId, expiresInSeconds: 900 });
      }
      if (kind === "resolve") {
        return await client.media.resolveMediaAccess({ fileId: sdkLab.fileId, mediaUrl: sdkLab.mediaUrl });
      }
      if (kind === "cache_remote") {
        return await client.media.cacheRemoteMedia({ fileId: sdkLab.fileId, mediaUrl: sdkLab.mediaUrl });
      }
      if (kind === "display_url") {
        return {
          displayUrl: await client.media.resolveDisplayUrl({ fileId: sdkLab.fileId, mediaUrl: sdkLab.mediaUrl }),
        };
      }
      if (kind === "set_root") {
        await client.media.setMediaCacheRoot({ root: sdkLab.mediaCacheRoot });
        return { cacheRoot: sdkLab.mediaCacheRoot };
      }
      if (kind === "set_max") {
        await client.media.setMediaCacheMaxBytes({ maxBytes: sdkLab.mediaCacheMaxBytes });
        return { maxBytes: sdkLab.mediaCacheMaxBytes };
      }
      if (kind === "download_subfolder") {
        await client.media.setUserDownloadSubfolder({ subfolder: sdkLab.downloadSubfolder });
        return await client.media.getUserDownloadSubfolder();
      }
      if (kind === "saved_path") {
        return await client.media.getUserDownloadSavedPath({ downloadKey: sdkLab.downloadKey, fileId: sdkLab.fileId });
      }
      if (kind === "delete_download") {
        await client.media.deleteUserDownloadRecord({ downloadKey: sdkLab.downloadKey, fileId: sdkLab.fileId });
        return { deleted: sdkLab.downloadKey || sdkLab.fileId };
      }
      if (kind === "cancel_download") {
        const cancelled = await client.media.cancelUserFileDownload({ downloadKey: sdkLab.downloadKey, fileId: sdkLab.fileId });
        return { cancelled };
      }
      if (kind === "download_file") {
        return await client.media.downloadFileToDownloads({
          downloadKey: sdkLab.downloadKey,
          fileId: sdkLab.fileId,
          displayFileName: sdkLab.displayFileName,
          sourcePath: sdkLab.sourcePath || undefined,
          sourceHttpUrl: sdkLab.sourceUrl || undefined,
          remoteFileId: sdkLab.remoteFileId || sdkLab.fileId || undefined,
          expiresIn: 900,
        });
      }
      if (kind === "stats") {
        return await client.media.getMediaCacheStats();
      }
      throw new FlareSdkException(
        "invalidParameter",
        `unsupported media operation: ${kind}`,
        "media.lab",
        { kind },
      );
    });
  }

  async function runCapabilityOperation(kind: string): Promise<void> {
    await runLab(`capability.${kind}`, async () => {
      if (kind === "list") {
        return await client.capabilities.listCapabilities({});
      }
      return await client.capabilities.dispatchCapability({
        operation: "web.echo",
        capability: sdkLab.capability,
        payload: parseJsonParams(sdkLab.jsonParams),
      });
    });
  }

  /**
   * The SDK Lab's connection and access probes. Network and foreground reports are not among them: the platform
   * lifecycle the SDK installs at init owns those.
   */
  async function runConnectionOperation(kind: string): Promise<void> {
    await runLab(`connection.${kind}`, async () => {
      if (kind === "reconnect_now") {
        await client.connection.reconnectNow();
        await refreshConnectionStatusSafely("lab.reconnect_now");
        return { reconnecting: true, status: connectionStatus.value };
      }
      if (kind === "disconnect") {
        await client.connection.disconnect();
        await refreshConnectionStatusSafely("lab.disconnect");
        return { disconnected: true, status: connectionStatus.value };
      }
      if (kind === "access_status") {
        return { ...await client.access.getStatus() };
      }
      if (kind === "access_points") {
        return await client.access.listAccessPoints();
      }
      if (kind === "access_diagnostics") {
        return { diagnostics: await client.access.exportDiagnostics() };
      }
      await refreshConnectionStatus();
      return { status: connectionStatus.value };
    });
  }

  /** The connection notice's "retry now": the core drops its backoff and tries at once. */
  async function reconnectNow(): Promise<void> {
    try {
      await client.connection.reconnectNow();
    } catch (error) {
      log("reconnect_now_failed", errorMessage(error));
    }
  }

  /**
   * The connection notice's "sign in again" (kicked, or the session expired): the local session ends even when the
   * server no longer accepts the logout, and the shell goes back to the sign-in page.
   */
  async function signInAgain(): Promise<void> {
    try {
      await logout();
    } catch (error) {
      log("logout_failed", errorMessage(error));
      clearSavedSessionProfile();
      loggedIn.value = false;
      homeSyncReady.value = false;
    }
  }

  async function runSessionOperation(kind: string): Promise<void> {
    await runLab(`session.${kind}`, async () => {
      if (kind === "runtime_health") {
        return { ...await client.diagnostics.getRuntimeHealth() };
      }
      if (kind === "heartbeat_interval") {
        return { ...await client.heartbeatEffectiveInterval() };
      }
      if (kind === "heartbeat_nat_timeout") {
        await client.setHeartbeatNatTimeout({
          natTimeoutSecs: sdkLab.heartbeatNatTimeoutSecs > 0 ? sdkLab.heartbeatNatTimeoutSecs : undefined,
        });
        return { ...await client.heartbeatEffectiveInterval() };
      }
      if (kind === "update_access_token") {
        // 客户端不再签发：这里只把登录页高级区里粘贴的 token 应用到核心（应用托管形态的演示）。
        const accessToken = String(form.token ?? "").trim();
        if (!accessToken) {
          throw new Error(translateFlare("login.tokenManagedByCore"));
        }
        await client.updateAccessToken({ accessToken, tenantId: form.tenantId });
        return { updated: true, tokenLength: accessToken.length };
      }
      if (kind === "current_user") {
        return await client.currentUserId();
      }
      if (kind === "session_active") {
        return {
          active: await client.sessionActive(),
          connected: await client.isConnected(),
        };
      }
      if (kind === "prepare") {
        // sdk.prepare：登录前预热（已 init 后可单独触发；LoginRequest = { userId, token }）。
        const prepareUserId = (currentUserId.value || form.userId).trim();
        await client.prepare({
          userId: prepareUserId,
          token: String(form.token ?? "").trim(),
        });
        return { prepared: true, userId: prepareUserId };
      }
      if (kind === "uninit") {
        // sdk.uninit：释放底层 runtime（破坏性，需重新 init/login）。
        await client.uninit();
        initialized.value = false;
        loggedIn.value = false;
        return { uninit: true };
      }
      if (kind === "hard_reset") {
        // sdk.hard_reset：进程级硬重置（清空本地状态）。
        await client.hardReset();
        initialized.value = false;
        loggedIn.value = false;
        return { hardReset: true };
      }
      if (kind === "send_no_oss") {
        // message.send_no_oss：不走 OSS 上传的直发（文本探针）。
        if (!activeConversationId.value) {
          throw new Error(translateFlare("error.openConversationBeforeSend"));
        }
        const draft = await client.messageBuilder.buildText({
          conversationId: activeConversationId.value,
          text: "send_no_oss lab probe",
        });
        const ack = await client.messages.sendMessageNoOss({ message: draft });
        return { sentNoOss: true, ack };
      }
      return await refreshCoreDiagnostics();
    });
  }

  async function runEventOperation(): Promise<void> {
    await runLab("events.subscribe", async () => await client.events.subscribeEvents({
      sources: [...sdkEventSources],
    }) as unknown as Record<string, unknown>);
  }

  async function openPeerConversation(conversationType: "single" | "group" = "single", peerUserId?: string): Promise<void> {
    const resolvedPeer = (peerUserId ?? sdkLab.peerUserId).trim();
    if (!resolvedPeer) return;
    sdkLab.peerUserId = resolvedPeer;
    const conversation = conversationType === "group"
      ? await openGroupConversationRaw(parseGroupMemberIds(resolvedPeer))
      : await openPeerConversationRaw(resolvedPeer);
    activeConversationId.value = conversation.conversationId;
    await refreshConversations();
    await openTimelineView(conversation.conversationId, "open_peer");
    refreshDerivedState();
  }

  // What a reconnect owes is the kit's rule (`FlareConnectionRefresh`, shared with the native kits): a gap drops
  // what nobody could correct while the link was down (who is typing), and coming back online subscribes to and
  // reads again the presence the gap may have missed.
  const connectionRefresh = new FlareConnectionRefresh();
  watch(connectionPhase, (phase) => {
    const work = connectionRefresh.observe(phase);
    if (work.dropStaleBeliefs) typingUsersByConversation.value = new Map();
    if (work.resubscribe || work.reread) {
      for (const peerUserId of Object.keys(peerPresence.value)) void refreshActivePeerPresence(peerUserId);
    }
  });

  let disposeSessionBridge: (() => void) | undefined;
  if (appClient) {
    disposeSessionBridge = bindFlareSessionEvents({
      appClient,
      events,
      connectionStatus,
      loggedIn,
      onIncomingMessage: handleIncomingMessageNotification,
      onPresenceChanged: applyPresenceChanged,
      onReactionChanged: applyReactionChanged,
      onViewUpdated: handleViewUpdate,
    });
  }

  startRealtimeSafetyPoll();

  onBeforeUnmount(() => {
    invalidateActiveSearch();
    if (incomingConversationRefreshTimer !== undefined) {
      clearTimeout(incomingConversationRefreshTimer);
      incomingConversationRefreshTimer = undefined;
    }
    if (activeConversationRefreshTimer !== undefined) {
      clearTimeout(activeConversationRefreshTimer);
      activeConversationRefreshTimer = undefined;
    }
    if (realtimeSafetyPollTimer) {
      clearInterval(realtimeSafetyPollTimer);
      realtimeSafetyPollTimer = undefined;
    }
    disposeSessionBridge?.();
    resetMessageOpening();
    if (markReadTimer) {
      clearTimeout(markReadTimer);
      markReadTimer = undefined;
    }
    void (async () => {
      await disposeOpenViewsAndEvents("unmount");
      await appClient?.dispose();
    })().catch((error) => {
      log("sdk_dispose_failed", errorMessage(error));
    });
  });

  return {
    appClient,
    client: client as FlareImClient,
    form,
    conversationFilters,
    initialized: readonly(initialized),
    loggedIn: readonly(loggedIn),
    busy: readonly(busy),
    accessConfigError: readonly(accessConfigError),
    connectionStatus: readonly(connectionStatus),
    connectionPhase,
    currentUserId: readonly(currentUserId),
    sessionActive: readonly(sessionActive),
    isConnected: readonly(isConnected),
    homeSyncing: readonly(homeSyncing),
    homeSyncReady: readonly(homeSyncReady),
    homeSyncError: readonly(homeSyncError),
    homeSyncProgress: readonly(homeSyncProgress),
    sdkRuntimeStatus: readonly(sdkRuntimeStatus),
    activeConversationId: readonly(activeConversationId),
    activeConversation,
    peerPresence: readonly(peerPresence),
    conversations: readonly(conversations),
    messages: readonly(messages),
    messageSearchResults: readonly(messageSearchResults),
    pinnedMessages: readonly(pinnedMessages),
    messageBuildCatalog: readonly(messageBuildCatalog),
    messageBuildOptions,
    messageDispatchOptions,
    diagnostics: readonly(diagnostics),
    events: readonly(events),
    conversationSyncing: readonly(conversationSyncing),
    conversationSyncError: readonly(conversationSyncError),
    messageSyncing: readonly(messageSyncing),
    messageOpening: readonly(messageOpening),
    messageSyncError: readonly(messageSyncError),
    messageHasMore: readonly(messageHasMore),
    loadingOlderMessages: readonly(loadingOlderMessages),
    sdkLab,
    labBusy: readonly(labBusy),
    labResult: readonly(labResult),
    totalUnread: readonly(totalUnread),
    activeLatestMessageId: readonly(activeLatestMessageId),
    initializeAndLogin,
    initBeforeSignIn,
    resumeSavedSession,
    hasSavedSession,
    syncHomeBeforeEnter,
    upsertUserProfiles,
    logout,
    reconnectNow,
    signInAgain,
    selectConversation,
    setConversationFilter,
    sendText,
    sendTypedMessage,
    buildAndSendMessage,
    buildFromComposerAction,
    resendFailedMessage,
    forwardMessagesToConversation,
    sendEmoji,
    sendSticker,
    addReaction,
    removeReaction,
    toggleReaction,
    editMessageText,
    setMessagePinned,
    deleteMessageForSelf,
    recallMessageById,
    saveActiveDraft,
    clearConversationDraft,
    sendTyping,
    activeConversationTypingUsers,
    searchActiveMessages,
    runDispatch,
    syncActiveConversation,
    syncConversationsFromServer,
    refreshActiveChat,
    enterActiveConversation,
    setActiveTimelineAtBottom,
    loadOlderMessages,
    searchConversationsWithKeyword,
    refreshActivePeerPresence,
    deleteActiveConversation,
    runSessionDiagnostics,
    openPeerConversation,
    runConversationOperation,
    runSyncOperation,
    runPresenceOperation,
    runMediaOperation,
    runCapabilityOperation,
    runConnectionOperation,
    runSessionOperation,
    runEventOperation,
    contentTypes: MessageContentType,
  };
}
