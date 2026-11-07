import type { ConnectionStatus, FlareImClient, FlareImEventListener } from "@flare-im/sdk/web";
import type { Message } from "@flare-im/sdk/web";
import type { ViewUpdate } from "@flare-im/sdk/web";
import type { Ref, ShallowRef } from "vue";

export type RuntimeEventLogItem = {
  id: number;
  label: string;
  detail: string;
  at: number;
};

export type IncomingMessageHint = {
  conversationId?: string;
  senderId?: string;
  message?: Message;
};

export type PresenceChangedHint = {
  conversationId?: string;
  userId?: string;
  status?: string;
  extra?: Record<string, string>;
};

export type ReactionChangedHint = {
  conversationId?: string;
  serverMsgId?: string;
  userId?: string;
  emoji?: string;
  action?: number;
};

type ConversationScopedPayload = {
  conversationId?: string;
  conversationIds?: string[];
};

type SessionEventListener = FlareImEventListener & {
  onPresenceChanged?: (payload: unknown) => void;
};

export type SessionBridgeOptions = {
  appClient: FlareImClient;
  events: Ref<RuntimeEventLogItem[]>;
  /** Replaced whole by every `connection://status`; the app shell hands it to the kit's connection notice. */
  connectionStatus: ShallowRef<ConnectionStatus | null>;
  loggedIn: Ref<boolean>;
  /** 收到 core 消息事件后更新本地可见投影 */
  onIncomingMessage?: (hint: IncomingMessageHint) => void;
  /** 收到在线状态推送后刷新本地 presence 状态 */
  onPresenceChanged?: (hint: PresenceChangedHint) => void;
  /** 收到表情回应变更后更新当前消息快照 */
  onReactionChanged?: (hint: ReactionChangedHint) => void;
  /** core observable view 快照更新 */
  onViewUpdated?: (update: ViewUpdate) => void;
};

let nextEventId = 1;

function pushEvent(events: Ref<RuntimeEventLogItem[]>, label: string, detail = ""): void {
  events.value = [{ id: nextEventId++, label, detail, at: Date.now() }, ...events.value].slice(0, 48);
}

function conversationIdFromPayload(payload: unknown): string | undefined {
  const event = payload as ConversationScopedPayload;
  const direct = event.conversationId;
  if (direct?.trim()) return direct.trim();
  const ids = event.conversationIds;
  return ids?.find((id) => id.trim())?.trim();
}

/** The event without the `type` / `event` routing keys the SDK decoder adds: what the typed listeners hand over. */
function eventPayload(payload: unknown): Record<string, unknown> {
  const { type: _type, event: _event, ...rest } = (payload ?? {}) as Record<string, unknown>;
  return rest;
}

function dispatchMappedEvent(listener: SessionEventListener, payload: unknown): void {
  const event = payload && typeof payload === "object"
    ? payload as { type?: unknown; event?: unknown; name?: unknown; state?: unknown }
    : {};
  const type = String(event.type ?? "");
  const name = String(event.name ?? "");
  const kind = String(event.event ?? "");
  if (type === "message") {
    if (kind === "received") listener.onMessageReceived?.(payload as never);
    else if (kind === "received_batch") listener.onMessageReceivedBatch?.(payload as never);
    else if (kind === "send_ack") listener.onMessageSendAck?.(payload as never);
    else if (kind === "send_failed") listener.onMessageSendFailed?.(payload as never);
    else if (kind === "recalled") listener.onMessageRecalled?.(payload as never);
    else if (kind === "edited") listener.onMessageEdited?.(payload as never);
    else if (kind === "deleted") listener.onMessageDeleted?.(payload as never);
    else if (kind === "reaction_changed") listener.onMessageReactionChanged?.(payload as never);
    else if (kind === "read_receipt") listener.onMessageReadReceipt?.(payload as never);
    return;
  }
  if (type === "conversation") {
    if (name === "created") listener.onNewConversation?.(payload as never);
    else if (name === "deleted") listener.onConversationDeleted?.(payload as never);
    else if (name === "unread_count_changed") listener.onTotalUnreadMessageCountChanged?.(payload as never);
    else listener.onConversationChanged?.(payload as never);
    return;
  }
  if (type === "sync") {
    if (name === "finished") listener.onSyncServerFinish?.(payload as never);
    else if (name === "failed") listener.onSyncServerFailed?.(payload as never);
    else if (name === "sync_progress") listener.onSyncProgress?.(payload as never);
    return;
  }
  if (type === "connection") {
    if (kind === "status") listener.onConnectionStatusChanged?.(eventPayload(payload) as unknown as ConnectionStatus);
    return;
  }
  if (type === "access") {
    if (kind === "switched") listener.onAccessSwitched?.(eventPayload(payload) as never);
    else if (kind === "changed") listener.onAccessChanged?.(eventPayload(payload) as never);
    return;
  }
  if (type === "presence" && kind === "changed") {
    listener.onPresenceChanged?.(payload);
    return;
  }
  if (type === "view" && kind === "updated") {
    listener.onViewUpdated?.(payload as never);
    return;
  }
  if (type === "plugin") {
    if (kind === "realtime") listener.onPluginRealtime?.(payload as never);
    else if (kind === "catalog_changed") listener.onPluginCatalogChanged?.(payload as never);
  }
}

export function bindFlareSessionEvents(options: SessionBridgeOptions): () => void {
  const listener: SessionEventListener = {
    // The one connection signal. Kicked, expired, an update required or a suspended tenant arrive as
    // `actionRequired`: the session stays (readable locally) and the kit's notice offers the way out.
    onConnectionStatusChanged: (status) => {
      options.connectionStatus.value = status;
      pushEvent(options.events, "connection_status", [status.phase, status.reason, status.accessPointId, status.protocol].filter(Boolean).join(" "));
    },
    onAccessSwitched: (event) => {
      pushEvent(options.events, "access_switched", `${event.from.ap} → ${event.to.ap} (${event.reason})`);
    },
    onAccessChanged: (event) => {
      pushEvent(options.events, "access_changed", `serial ${event.serial} ${event.source}${event.stale ? " stale" : ""}`);
    },
    onLoggedOut: () => {
      options.loggedIn.value = false;
      pushEvent(options.events, "logged_out", "");
    },
    onLoginFailed: (payload) => {
      options.loggedIn.value = false;
      pushEvent(options.events, "login_failed", String((payload as { reason?: string; message?: string }).message ?? (payload as { reason?: string }).reason ?? ""));
    },
    onMessageReceived: (payload: unknown) => {
      const event = payload as { message?: Message };
      const message = event.message;
      pushEvent(
        options.events,
        "message_received",
        message ? `${message.conversationId ?? ""}#${message.conversationSeq ?? ""}` : "",
      );
      options.onIncomingMessage?.({
        conversationId: message?.conversationId,
        senderId: message?.senderId,
        message,
      });
    },
    onMessageReceivedBatch: (payload: unknown) => {
      const batch = payload as { messages?: Message[] };
      const items = batch.messages ?? [];
      for (const message of items) {
        pushEvent(
          options.events,
          "message_received",
          `${message.conversationId ?? ""}#${message.conversationSeq ?? ""}`,
        );
        options.onIncomingMessage?.({
          conversationId: message.conversationId,
          senderId: message.senderId,
          message,
        });
      }
    },
    onMessageSendAck: (payload: unknown) => {
      const ack = (payload as { ack: { conversationId?: string; seq?: number } }).ack;
      pushEvent(options.events, "send_ack", `${ack.conversationId ?? ""}#${ack.seq ?? ""}`);
    },
    onMessageSendFailed: (payload) => {
      const failure = payload as { reason?: string; clientMsgId?: string };
      pushEvent(options.events, "send_failed", failure.reason ?? failure.clientMsgId ?? "");
    },
    onMessageRecalled: (payload) => {
      pushEvent(options.events, "message_recalled", conversationIdFromPayload(payload) ?? "");
      options.onIncomingMessage?.({ conversationId: conversationIdFromPayload(payload) });
    },
    onMessageEdited: (payload) => {
      pushEvent(options.events, "message_edited", conversationIdFromPayload(payload) ?? "");
      options.onIncomingMessage?.({ conversationId: conversationIdFromPayload(payload) });
    },
    onMessageDeleted: (payload) => {
      pushEvent(options.events, "message_deleted", conversationIdFromPayload(payload) ?? "");
      options.onIncomingMessage?.({ conversationId: conversationIdFromPayload(payload) });
    },
    onMessageReactionChanged: (payload) => {
      pushEvent(options.events, "reaction_changed", conversationIdFromPayload(payload) ?? "");
      const event = payload as ReactionChangedHint;
      options.onReactionChanged?.({
        conversationId: event.conversationId,
        serverMsgId: event.serverMsgId,
        userId: event.userId,
        emoji: event.emoji,
        action: event.action,
      });
      options.onIncomingMessage?.({ conversationId: conversationIdFromPayload(payload) });
    },
    onMessageReadReceipt: (payload) => {
      pushEvent(options.events, "read_receipt", conversationIdFromPayload(payload) ?? "");
      options.onIncomingMessage?.({ conversationId: conversationIdFromPayload(payload) });
    },
    onMessagePinned: (payload) => {
      pushEvent(options.events, "message_pinned", conversationIdFromPayload(payload) ?? "");
      options.onIncomingMessage?.({ conversationId: conversationIdFromPayload(payload) });
    },
    onMessageUnpinned: (payload) => {
      pushEvent(options.events, "message_unpinned", conversationIdFromPayload(payload) ?? "");
      options.onIncomingMessage?.({ conversationId: conversationIdFromPayload(payload) });
    },
    onNewConversation: (payload) => {
      const conversationId = conversationIdFromPayload(payload);
      pushEvent(options.events, "conversation_created", conversationId ?? "");
      if (conversationId) {
        options.onIncomingMessage?.({ conversationId });
      }
    },
    onConversationChanged: (payload) => {
      const conversationId = conversationIdFromPayload(payload);
      pushEvent(options.events, "conversation_changed", conversationId ?? "");
      if (conversationId) {
        options.onIncomingMessage?.({ conversationId });
      }
    },
    onTotalUnreadMessageCountChanged: (payload) => {
      const conversationId = conversationIdFromPayload(payload);
      if (conversationId) {
        options.onIncomingMessage?.({ conversationId });
      }
    },
    onConversationDeleted: (payload) => {
      const conversationId = conversationIdFromPayload(payload);
      pushEvent(options.events, "conversation_deleted", conversationId ?? "");
    },
    onSyncServerFinish: () => {
      pushEvent(options.events, "sync_finish", "");
      options.onIncomingMessage?.({});
    },
    onSyncServerFailed: (payload) => {
      const failure = payload as { reason?: string; message?: string };
      pushEvent(options.events, "sync_failed", failure.message ?? failure.reason ?? "");
    },
    onSyncProgress: (payload) => {
      const progress = payload as { phase?: string; percent?: number };
      pushEvent(options.events, "sync_progress", `${progress.phase ?? ""} ${progress.percent ?? ""}`.trim());
    },
    onPluginRealtime: (payload) => {
      pushEvent(options.events, "plugin_realtime", `${payload.pluginId} ${payload.packetType}`);
    },
    onPluginCatalogChanged: (payload) => {
      pushEvent(options.events, "plugin_catalog_changed", payload.version);
    },
    onPresenceChanged: (payload: unknown) => {
      const event = payload as PresenceChangedHint;
      const userId = event.userId ?? "";
      const status = event.status ?? "";
      pushEvent(options.events, "presence_changed", `${userId}:${status}`);
      options.onPresenceChanged?.(event);
    },
    onViewUpdated: (payload: unknown) => {
      const update = payload as ViewUpdate;
      pushEvent(options.events, "view_updated", `${update.viewId}:${update.kind}`);
      options.onViewUpdated?.(update);
    },
  };

  const subscription = options.appClient.events.addEventListener(
    ((payload: unknown) => dispatchMappedEvent(listener, payload)) as never,
  );

  return () => {
    subscription.unsubscribe();
  };
}

export const flareSessionBridgeTesting = {
  conversationIdFromPayload,
  dispatchMappedEvent,
};

export function mapSdkError(error: unknown, operation: string): Record<string, unknown> {
  const shaped = error as {
    code?: unknown;
    operation?: unknown;
    retryable?: unknown;
    details?: unknown;
    message?: unknown;
  };
  const rawMessage = error instanceof Error ? error.message : String(error);
  const nested = readJsonErrorPayload(rawMessage);
  return {
    unavailable: true,
    code: nested?.code ?? shaped?.code ?? "runtimeUnavailable",
    operation: nested?.operation ?? shaped?.operation ?? operation,
    retryable: shaped?.retryable ?? false,
    message: nested?.message ?? rawMessage,
    details: shaped?.details ?? nested?.details,
  };
}

export function reportSdkError(error: unknown, operation: string): Record<string, unknown> {
  const payload = mapSdkError(error, operation);
  if (typeof console !== "undefined" && typeof console.error === "function") {
    console.error("[flare-core-web-app] SDK operation failed", payload, error);
  }
  return payload;
}

function readJsonErrorPayload(message: string): {
  code?: unknown;
  operation?: unknown;
  message?: unknown;
  details?: unknown;
} | undefined {
  const trimmed = message.trim();
  if (!trimmed.startsWith("{") || !trimmed.endsWith("}")) {
    return undefined;
  }
  try {
    const parsed = JSON.parse(trimmed);
    return parsed && typeof parsed === "object"
      ? parsed as { code?: unknown; operation?: unknown; message?: unknown; details?: unknown }
      : undefined;
  } catch {
    return undefined;
  }
}
