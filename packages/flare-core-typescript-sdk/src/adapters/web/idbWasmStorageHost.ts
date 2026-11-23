const DB_NAME = "flare-core-web-app";
const DB_VERSION = 8;
const WASM_MESSAGES = "wasmMessages";
const WASM_CONVERSATIONS = "wasmConversations";
const WASM_CURSORS = "wasmCursors";
const WASM_PENDING_SENDS = "wasmPendingSends";
const MESSAGE_TIMELINE = "timeline";
const INLINE_FILE_SOURCE_LIMIT = 1024 * 1024;

export const WASM_STORAGE_CHANGED_EVENT = "flare:wasm-storage-changed";

export type WasmStorageChangedDetail = {
  userId: string;
  kind: "message" | "conversation" | "cursor" | "pending_send" | "delete";
  conversationId?: string;
  id?: string;
  message?: Record<string, unknown>;
  conversation?: Record<string, unknown>;
};

// userId is the opaque tenant/user partition supplied by Core, not the account ID.
type PersistMessagePayload = {
  userId: string;
  message: Record<string, unknown>;
};

type PersistMessagesPayload = {
  userId: string;
  messages: Record<string, unknown>[];
};

type LoadSnapshotPayload = { userId?: string; metadataOnly?: boolean };

type ReadMessagesPayload = { userId: string } & (
  | { kind: "ids"; ids: string[] }
  | { kind: "all" }
  | { kind: "timeline"; conversationId: string; beforeSeq?: number; afterSeq?: number; limit?: number; oldestSeq?: number }
);

type StoredMessageRow = PersistMessagePayload & {
  key: string;
  /** Large local file locators. The URL can refer to the same Blob as fileId. */
  localFileSources?: { fileId?: Blob; url?: Blob | "fileId" };
};

type PersistConversationPayload = {
  userId: string;
  conversation: Record<string, unknown>;
};

type PersistCursorPayload = {
  userId: string;
  key: string;
  value: string;
};

type PersistPendingSendPayload = {
  userId: string;
  entry: Record<string, unknown>;
};

type DeletePayload = {
  userId: string;
  id: string;
};

function userPrefix(userId: string): string {
  return userId.trim();
}

function messageKey(userId: string, message: Record<string, unknown>): string {
  const serverId = String(message.serverId ?? "");
  const clientMsgId = String(message.clientMsgId ?? "");
  const conversationId = String(message.conversationId ?? "");
  const seq = String(message.conversationSeq ?? 0).padStart(20, "0");
  return `${userPrefix(userId)}::${conversationId}::${seq}::${serverId || clientMsgId || cryptoSafeId()}`;
}

/**
 * `PendingSendVo` 走 snake_case wire（与 `Message` 的 camelCase 不同），两种都认。
 *
 * 原来只读 `entry.clientMsgId`：对 snake_case 取到 undefined，于是回退成
 * `cryptoSafeId()` —— 主键变成随机 UUID，而删除用的是真实 client_msg_id 拼的键，
 * **永远匹配不上**。后果是待发条目在 IndexedDB 里只增不减；下次登录被重新水化后
 * 队列会**重发已经送达的消息**。Rust 侧 `let _ = delete_pending_send(...)`
 * 又吞掉了错误，所以整个过程无声无息。
 */
function pendingSendClientMsgId(entry: Record<string, unknown>): string {
  return String(entry.client_msg_id ?? entry.clientMsgId ?? "").trim();
}

/** 拿不到 client_msg_id 时返回 null：写一条**删不掉**的行比不写更糟。 */
function pendingSendKey(userId: string, entry: Record<string, unknown>): string | null {
  const clientMsgId = pendingSendClientMsgId(entry);
  if (!clientMsgId) return null;
  return `${userPrefix(userId)}::${clientMsgId}`;
}

function messageConversationId(message: Record<string, unknown>): string {
  return String(message.conversationId ?? "").trim();
}

function conversationIdFromConversation(conversation: Record<string, unknown>): string {
  return String(conversation.conversationId ?? "").trim();
}

/**
 * Cached connection — every save/load/delete reuses one `IDBDatabase` instead of
 * reopening per operation (a snapshot load alone opened 4 connections, each message
 * save 1 more). The cache is cleared if the connection closes or another tab triggers
 * a version change, so the next call transparently reopens.
 */
let dbPromise: Promise<IDBDatabase> | null = null;

function openDbConnection(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onupgradeneeded = () => {
      const db = request.result;
      for (const storeName of [WASM_MESSAGES, WASM_CONVERSATIONS, WASM_CURSORS, WASM_PENDING_SENDS]) {
        const store = db.objectStoreNames.contains(storeName)
          ? request.transaction!.objectStore(storeName)
          : db.createObjectStore(storeName, { keyPath: "key" });
        if (!store.indexNames.contains("userId")) {
          store.createIndex("userId", "userId", { unique: false });
        }
        if (storeName === WASM_MESSAGES) {
          for (const [name, field] of [["serverId", "serverId"], ["clientMsgId", "clientMsgId"]] as const) {
            if (!store.indexNames.contains(name)) {
              store.createIndex(name, ["userId", `message.${field}`], { unique: false });
            }
          }
          if (!store.indexNames.contains(MESSAGE_TIMELINE)) {
            store.createIndex(MESSAGE_TIMELINE, ["userId", "message.conversationId", "message.conversationSeq"]);
          }
        }
      }
    };
    request.onsuccess = () => resolve(request.result);
  });
}

function openDb(): Promise<IDBDatabase> {
  if (!dbPromise) {
    dbPromise = openDbConnection().then((db) => {
      // Drop the cached handle when it goes away so the next call reopens cleanly.
      db.onclose = () => {
        dbPromise = null;
      };
      db.onversionchange = () => {
        db.close();
        dbPromise = null;
      };
      return db;
    });
    // A failed open must not poison the cache.
    dbPromise.catch(() => {
      dbPromise = null;
    });
  }
  return dbPromise;
}

function requestToPromise<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isLargeInlineSource(value: unknown): value is string {
  return typeof value === "string" && value.length > INLINE_FILE_SOURCE_LIMIT && value.startsWith("data:");
}

function messageRowForStorage(key: string, userId: string, message: Record<string, unknown>): StoredMessageRow {
  const { content, localState } = message;
  const row = { key, userId, message };
  if (!isRecord(localState) || localState.isLocal !== true || !isRecord(content) || content.contentType !== "file") {
    return row;
  }
  const fileId = isLargeInlineSource(content.fileId) ? content.fileId : undefined;
  const url = isLargeInlineSource(content.url) ? content.url : undefined;
  if (!fileId && !url) return row;

  // IndexedDB stores Blob bytes outside the structured-clone record, in the same transaction as the message.
  // Rust regenerates the protobuf cache from the restored file content when it hydrates this local row.
  const { encodedContent: _encodedContent, ...stored } = message;
  return {
    ...row,
    message: { ...stored, content: { ...content, fileId: fileId ? "" : content.fileId, url: url ? "" : content.url } },
    localFileSources: {
      fileId: fileId ? new Blob([fileId]) : undefined,
      url: url ? (url === fileId ? "fileId" : new Blob([url])) : undefined,
    },
  };
}

async function restoreMessage(row: StoredMessageRow): Promise<Record<string, unknown>> {
  const { message, localFileSources } = row;
  if (!localFileSources || !isRecord(message.content)) return message;
  const fileId = await localFileSources.fileId?.text();
  const url = localFileSources.url === "fileId" ? fileId : await localFileSources.url?.text();
  return { ...message, content: { ...message.content, fileId: fileId ?? message.content.fileId, url: url ?? message.content.url } };
}

function hasCanonicalOptionalBooleans(record: Record<string, unknown>, keys: readonly string[]): boolean {
  return keys.every((key) => record[key] === undefined || typeof record[key] === "boolean");
}

function hasCanonicalOptionalUnsigned(record: Record<string, unknown>, keys: readonly string[]): boolean {
  return keys.every((key) => {
    const value = record[key];
    return value === undefined || (typeof value === "number" && Number.isInteger(value) && value >= 0);
  });
}

function isCanonicalStoredMessage(message: unknown): message is Record<string, unknown> {
  if (!isRecord(message)) return false;
  if (!hasCanonicalOptionalBooleans(message, ["isRead", "isRecalled", "isEdited", "mentionAll"])) {
    return false;
  }
  const localState = message.localState;
  if (localState === undefined || localState === null) return true;
  if (!isRecord(localState)) return false;
  return hasCanonicalOptionalBooleans(localState, ["sending", "failed", "isLocal", "uploading"])
    && hasCanonicalOptionalUnsigned(localState, ["uploadProgress", "sortTs"]);
}

function isCanonicalStoredConversation(conversation: unknown): conversation is Record<string, unknown> {
  if (!isRecord(conversation)) return false;
  return hasCanonicalOptionalBooleans(conversation, [
    "isPinned",
    "isMuted",
    "isArchived",
    "mentionMe",
  ]);
}

async function deleteRowsByKeys(storeName: string, keys: readonly string[]): Promise<void> {
  if (!keys.length) return;
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(storeName, "readwrite");
    tx.onerror = () => reject(tx.error ?? new Error("IndexedDB transaction failed"));
    tx.onabort = () => reject(tx.error ?? new Error("IndexedDB transaction aborted"));
    tx.oncomplete = () => resolve();
    const store = tx.objectStore(storeName);
    for (const key of keys) {
      store.delete(key);
    }
  });
}

function getAllForUser<T>(
  tx: IDBTransaction,
  storeName: string,
  userId: string,
): Promise<T[]> {
  const index = tx.objectStore(storeName).index("userId");
  return requestToPromise(index.getAll(userId));
}

async function putRow(storeName: string, row: Record<string, unknown>): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(storeName, "readwrite");
    tx.onerror = () => reject(tx.error ?? new Error("IndexedDB transaction failed"));
    tx.onabort = () => reject(tx.error ?? new Error(`IndexedDB ${storeName} transaction aborted`));
    tx.oncomplete = () => resolve();
    tx.objectStore(storeName).put(row);
  });
}

function notifyStorageChanged(detail: WasmStorageChangedDetail): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent<WasmStorageChangedDetail>(WASM_STORAGE_CHANGED_EVENT, { detail }));
}

async function deleteMessageRows(userId: string, id: string): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(WASM_MESSAGES, "readwrite");
    tx.onerror = () => reject(tx.error ?? new Error("IndexedDB transaction failed"));
    tx.onabort = () => reject(tx.error ?? new Error("IndexedDB transaction aborted"));
    tx.oncomplete = () => resolve();
    const store = tx.objectStore(WASM_MESSAGES);
    let foundServer = false;
    const request = store.index("serverId").openCursor([userPrefix(userId), id]);
    request.onsuccess = () => {
      const cursor = request.result;
      if (cursor) {
        foundServer = true;
        cursor.delete();
        cursor.continue();
      } else if (!foundServer) {
        const clients = store.index("clientMsgId").getAll([userPrefix(userId), id]);
        clients.onsuccess = () => {
          const local = clients.result.filter((row) => row.message && (!row.message.serverId || row.message.localState?.isLocal === true));
          if (local.length === 1) store.delete(local[0].key);
        };
      }
    };
  });
}

export async function wasmStorageLoadSnapshot(payload: LoadSnapshotPayload): Promise<string> {
  const userId = payload.userId?.trim();
  if (!userId) {
    return JSON.stringify({ messages: [], conversations: [], cursors: {}, pendingSends: [] });
  }
  const db = await openDb();
  const stores = [WASM_CONVERSATIONS, WASM_CURSORS, WASM_PENDING_SENDS];
  if (!payload.metadataOnly) stores.push(WASM_MESSAGES);
  const tx = db.transaction(stores, "readonly");
  const [messageRows, conversationRows, cursorRows, pendingRows] = await Promise.all([
    payload.metadataOnly ? [] : getAllForUser<StoredMessageRow>(tx, WASM_MESSAGES, userId),
    getAllForUser<{ key: string; conversation: Record<string, unknown> }>(tx, WASM_CONVERSATIONS, userId),
    getAllForUser<{ key: string; value: string; cursorKey?: string }>(tx, WASM_CURSORS, userId),
    getAllForUser<{ key: string; entry: Record<string, unknown> }>(tx, WASM_PENDING_SENDS, userId),
  ]);
  const cursors: Record<string, string> = {};
  for (const row of cursorRows) {
    const cursorKey =
      row.cursorKey ??
      String(row.key).split("::").slice(1).join("::");
    cursors[cursorKey] = row.value;
  }
  const canonicalMessages = messageRows.filter((row) => isCanonicalStoredMessage(row.message));
  const canonicalConversations = conversationRows.filter((row) => isCanonicalStoredConversation(row.conversation));
  const invalidMessageKeys = messageRows
    .filter((row) => !isCanonicalStoredMessage(row.message))
    .map((row) => String((row as { key?: string }).key ?? ""))
    .filter(Boolean);
  const invalidConversationKeys = conversationRows
    .filter((row) => !isCanonicalStoredConversation(row.conversation))
    .map((row) => String((row as { key?: string }).key ?? ""))
    .filter(Boolean);
  void deleteRowsByKeys(WASM_MESSAGES, invalidMessageKeys).catch(() => undefined);
  void deleteRowsByKeys(WASM_CONVERSATIONS, invalidConversationKeys).catch(() => undefined);

  // Prefer the canonical row over old random-key copies of the same pending send.
  const canonicalPending = new Map<string, Record<string, unknown>>();
  for (const row of pendingRows) {
    const key = pendingSendKey(userId, row.entry ?? {});
    if (key === row.key) canonicalPending.set(key, row.entry);
  }
  const orphanPendingRows = pendingRows.filter((row) => {
    const key = pendingSendKey(userId, row.entry ?? {});
    if (!key) return false;
    if (!canonicalPending.has(key)) canonicalPending.set(key, row.entry);
    return row.key !== key;
  });
  if (orphanPendingRows.length) {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(WASM_PENDING_SENDS, "readwrite");
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error ?? new Error("IndexedDB transaction failed"));
      tx.onabort = () => reject(tx.error ?? new Error("pending-send migration aborted"));
      const store = tx.objectStore(WASM_PENDING_SENDS);
      for (const key of new Set(orphanPendingRows.map((row) => pendingSendKey(userId, row.entry)!))) {
        const request = store.get(key);
        request.onsuccess = () => {
          if (request.result) canonicalPending.set(key, request.result.entry);
          else store.put({ key, userId: userPrefix(userId), entry: canonicalPending.get(key)! });
        };
      }
      for (const row of orphanPendingRows) store.delete(row.key);
    });
  }
  return JSON.stringify({
    messages: await Promise.all(canonicalMessages.map(restoreMessage)),
    conversations: canonicalConversations.map((row) => row.conversation),
    cursors,
    pendingSends: [...canonicalPending.values()],
  });
}

function readTimelineRows(
  store: IDBObjectStore,
  userId: string,
  query: Extract<ReadMessagesPayload, { kind: "timeline" }>,
): Promise<StoredMessageRow[]> {
  const { conversationId, afterSeq, beforeSeq, limit, oldestSeq } = query;
  if (limit === 0) return Promise.resolve([]);
  const scope = [userId, conversationId];
  const confirmed = IDBKeyRange.bound(
    [...scope, afterSeq ?? 0],
    [...scope, beforeSeq || []],
    true,
    true,
  );
  const request = store.index(MESSAGE_TIMELINE).openCursor(confirmed, afterSeq === undefined ? "prev" : "next");
  const confirmedRows = new Promise<StoredMessageRow[]>((resolve, reject) => {
    const rows: StoredMessageRow[] = [];
    let lastSeq: unknown;
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const cursor = request.result;
      if (!cursor) return resolve(rows);
      const seq = (cursor.key as IDBValidKey[])[2];
      // Let Core break sequence ties consistently with its timeline comparator.
      if (limit !== undefined && rows.length >= limit && seq !== lastSeq) return resolve(rows);
      if (isCanonicalStoredMessage(cursor.value.message)) {
        rows.push(cursor.value);
        lastSeq = seq;
        if (oldestSeq !== undefined && typeof seq === "number" && seq < oldestSeq) return resolve(rows);
      }
      cursor.continue();
    };
  });
  if (afterSeq !== undefined || beforeSeq) return confirmedRows;
  // Older rows can omit conversationSeq. Their original primary key still encodes zero.
  const prefix = `${userId}::${conversationId}::00000000000000000000::`;
  const zeroRows = requestToPromise<StoredMessageRow[]>(
    store.getAll(IDBKeyRange.bound(prefix, prefix.slice(0, -1) + ";", false, true)),
  );
  return Promise.all([confirmedRows, zeroRows]).then(([rows, zeros]) =>
    rows.concat(zeros.filter((row) => row.userId === userId && row.message?.conversationId === conversationId)),
  );
}

export async function wasmStorageReadMessages(payload: ReadMessagesPayload): Promise<string> {
  const userId = payload.userId?.trim();
  if (!userId) return "[]";
  const db = await openDb();
  const tx = db.transaction(WASM_MESSAGES, "readonly");
  const store = tx.objectStore(WASM_MESSAGES);
  let rows: StoredMessageRow[];
  switch (payload.kind) {
    case "timeline":
      rows = await readTimelineRows(store, userId, payload);
      break;
    case "ids": {
      const requests = [...new Set(payload.ids.filter(Boolean))].flatMap((id) =>
        ["serverId", "clientMsgId"].map((name) => requestToPromise<StoredMessageRow[]>(store.index(name).getAll([userId, id]))),
      );
      const matches = (await Promise.all(requests)).flat();
      rows = [...new Map(matches.map((row) => [row.key, row])).values()];
      break;
    }
    case "all":
      rows = await getAllForUser<StoredMessageRow>(tx, WASM_MESSAGES, userId);
      break;
  }
  return JSON.stringify(await Promise.all(rows.filter((row) => isCanonicalStoredMessage(row.message)).map(restoreMessage)));
}

export async function wasmStorageSaveMessage(payload: PersistMessagePayload): Promise<void> {
  await wasmStorageSaveMessages({ userId: payload.userId, messages: [payload.message ?? {}] });
}

export async function wasmStorageSaveMessages(payload: PersistMessagesPayload): Promise<void> {
  const userId = payload.userId?.trim();
  if (!userId || !payload.messages.length) return;
  const writes = payload.messages.map((message) => ({
    message,
    row: messageRowForStorage(messageKey(userId, message), userId, message),
  }));
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(WASM_MESSAGES, "readwrite");
    tx.onerror = () => reject(tx.error ?? new Error("IndexedDB transaction failed"));
    tx.onabort = () => reject(tx.error ?? new Error("IndexedDB message transaction aborted"));
    tx.oncomplete = () => resolve();
    const store = tx.objectStore(WASM_MESSAGES);
    let index = 0;
    function queueNext() {
      const write = writes[index++];
      if (!write) return;
      const { message, row } = write;
      const put = () => {
        try {
          // Keep writes ordered so an ACK can replace a pending row from this batch.
          store.put(row).onsuccess = queueNext;
        } catch (error) {
          reject(error);
          tx.abort();
        }
      };
      const identities = [["serverId", message.serverId], ["clientMsgId", message.clientMsgId]]
        .filter(([, id]) => typeof id === "string" && id.length > 0);
      if (!identities.length) {
        put();
        return;
      }
      let remaining = identities.length;
      for (const [name, id] of identities) {
        const request = store.index(String(name)).openCursor([userId, String(id)]);
        request.onsuccess = () => {
          const cursor = request.result;
          if (!cursor) {
            if (--remaining === 0) put();
            return;
          }
          const previous = cursor.value.message as Record<string, unknown>;
          const sameServer = previous.serverId && previous.serverId === message.serverId;
          const previousLocal = !previous.serverId || (previous.localState as { isLocal?: boolean } | undefined)?.isLocal === true;
          const sameSend = previous.clientMsgId === message.clientMsgId
            && previous.conversationId === message.conversationId && previous.senderId === message.senderId;
          if (sameServer || (previousLocal && sameSend)) cursor.delete();
          cursor.continue();
        };
      }
    }
    queueNext();
  });
  for (const { message } of writes) {
    notifyStorageChanged({
      userId,
      kind: "message",
      conversationId: messageConversationId(message),
      message,
    });
  }
}

export async function wasmStorageSaveConversation(payload: PersistConversationPayload): Promise<void> {
  const userId = payload.userId?.trim();
  if (!userId) return;
  const conversation = payload.conversation ?? {};
  const conversationId = conversationIdFromConversation(conversation);
  await putRow(WASM_CONVERSATIONS, {
    key: `${userPrefix(userId)}::${conversationId}`,
    userId: userPrefix(userId),
    conversation,
  });
  notifyStorageChanged({
    userId,
    kind: "conversation",
    conversationId,
    conversation,
  });
}

export async function wasmStorageSaveCursor(payload: PersistCursorPayload): Promise<void> {
  const userId = payload.userId?.trim();
  if (!userId || !payload.key) return;
  await putRow(WASM_CURSORS, {
    key: `${userPrefix(userId)}::${payload.key}`,
    userId: userPrefix(userId),
    cursorKey: payload.key,
    value: payload.value,
  });
  notifyStorageChanged({
    userId,
    kind: "cursor",
    id: payload.key,
  });
}

export async function wasmStorageSavePendingSend(payload: PersistPendingSendPayload): Promise<void> {
  const userId = payload.userId?.trim();
  if (!userId) return;
  const entry = payload.entry ?? {};
  const key = pendingSendKey(userId, entry);
  if (!key) {
    throw new Error("pending send has no client_msg_id");
  }
  await putRow(WASM_PENDING_SENDS, {
    key,
    userId: userPrefix(userId),
    entry,
  });
  notifyStorageChanged({
    userId,
    kind: "pending_send",
    id: pendingSendClientMsgId(entry),
  });
}

export async function wasmStorageDeleteMessage(payload: DeletePayload): Promise<void> {
  const userId = payload.userId?.trim();
  if (!userId || !payload.id) return;
  await deleteMessageRows(userId, payload.id);
  notifyStorageChanged({
    userId,
    kind: "delete",
    id: payload.id,
  });
}

export async function wasmStorageDeleteConversation(payload: DeletePayload): Promise<void> {
  const userId = payload.userId?.trim();
  if (!userId || !payload.id) return;
  await deleteRowsByKeys(WASM_CONVERSATIONS, [`${userPrefix(userId)}::${payload.id}`]);
  notifyStorageChanged({
    userId,
    kind: "delete",
    conversationId: payload.id,
    id: payload.id,
  });
}

export async function wasmStorageDeletePendingSend(payload: DeletePayload): Promise<void> {
  const userId = payload.userId?.trim();
  if (!userId || !payload.id) return;
  await deleteRowsByKeys(WASM_PENDING_SENDS, [`${userPrefix(userId)}::${payload.id}`]);
  notifyStorageChanged({
    userId,
    kind: "delete",
    id: payload.id,
  });
}

function cryptoSafeId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return Math.random().toString(36).slice(2);
}

export type WasmStorageHostCallbacks = {
  loadSnapshot: (payload: LoadSnapshotPayload) => Promise<string>;
  readMessages?: (payload: ReadMessagesPayload) => Promise<string>;
  saveMessage: (payload: PersistMessagePayload) => Promise<void>;
  saveMessages?: (payload: PersistMessagesPayload) => Promise<void>;
  saveConversation: (payload: PersistConversationPayload) => Promise<void>;
  saveCursor: (payload: PersistCursorPayload) => Promise<void>;
  savePendingSend: (payload: PersistPendingSendPayload) => Promise<void>;
  deleteMessage: (payload: DeletePayload) => Promise<void>;
  deleteConversation: (payload: DeletePayload) => Promise<void>;
  deletePendingSend: (payload: DeletePayload) => Promise<void>;
};

export function createWasmIndexedDbStorageHost(): WasmStorageHostCallbacks {
  return {
    loadSnapshot: wasmStorageLoadSnapshot,
    readMessages: wasmStorageReadMessages,
    saveMessage: wasmStorageSaveMessage,
    saveMessages: wasmStorageSaveMessages,
    saveConversation: wasmStorageSaveConversation,
    saveCursor: wasmStorageSaveCursor,
    savePendingSend: wasmStorageSavePendingSend,
    deleteMessage: wasmStorageDeleteMessage,
    deleteConversation: wasmStorageDeleteConversation,
    deletePendingSend: wasmStorageDeletePendingSend,
  };
}

/** 仅供测试：主键推导是写入/删除能否对上的唯一依据，必须可单测。 */
export const __testing = {
  pendingSendKey,
  pendingSendClientMsgId,
};
