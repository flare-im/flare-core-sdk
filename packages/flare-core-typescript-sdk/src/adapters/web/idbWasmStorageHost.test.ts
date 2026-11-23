import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { IDBCursor, IDBFactory, IDBKeyRange, IDBObjectStore } from "fake-indexeddb";

const stores = ["wasmMessages", "wasmConversations", "wasmCursors", "wasmPendingSends"];
let database: IDBFactory;
let connections: IDBDatabase[];

async function seed(version = 5, index = true) {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const request = database.open("flare-core-web-app", version);
    request.onerror = () => reject(request.error);
    request.onupgradeneeded = () => {
      for (const name of stores) {
        const store = request.result.createObjectStore(name, { keyPath: "key" });
        if (index) store.createIndex("userId", "userId");
      }
    };
    request.onsuccess = () => {
      connections.push(request.result);
      resolve(request.result);
    };
  });
}

beforeEach(() => {
  vi.resetModules();
  database = new IDBFactory();
  connections = [];
  vi.stubGlobal("indexedDB", database);
  vi.stubGlobal("IDBKeyRange", IDBKeyRange);
});
afterEach(() => {
  connections.forEach((db) => db.close());
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("Web storage durability", () => {
  it("deletes exact server and local client IDs without matching prefixes, conversations or other users", async () => {
    const host = await import("./idbWasmStorageHost");
    for (const [userId, serverId, conversationId, clientMsgId] of [
      ["u", "msg-1", "c", "local"], ["u", "msg-10", "c", "other"],
      ["u", "unrelated", "msg-1", "x"], ["other", "msg-1", "c", "local"],
    ]) {
      await host.wasmStorageSaveMessage({ userId, message: { serverId, conversationId, clientMsgId, localState: { isLocal: clientMsgId === "other" } } });
    }
    await host.wasmStorageDeleteMessage({ userId: "u", id: "msg-1" });
    const read = async (userId: string) => JSON.parse(await host.wasmStorageLoadSnapshot({ userId })).messages;
    expect((await read("u")).map((m: { serverId: string }) => m.serverId).sort()).toEqual(["msg-10", "unrelated"]);
    expect(await read("other")).toHaveLength(1);
    await host.wasmStorageDeleteMessage({ userId: "u", id: "other" });
    expect((await read("u"))[0].serverId).toBe("unrelated");
  });

  it.each(["", "local"])("scopes pending aliases and removes the accepted local copy (serverId=%s)", async (serverId) => {
    const host = await import("./idbWasmStorageHost");
    const pending = { serverId, clientMsgId: "local", senderId: "alice", conversationId: "a", localState: { isLocal: true } };
    const other = { serverId: "remote", clientMsgId: "local", senderId: "bob", conversationId: "b" };
    await host.wasmStorageSaveMessage({ userId: "u", message: pending });
    await host.wasmStorageSaveMessage({ userId: "u", message: other });
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages).toHaveLength(2);
    const accepted = { serverId: "accepted", clientMsgId: "local", senderId: "alice", conversationId: "a", conversationSeq: 1 };
    await host.wasmStorageSaveMessage({ userId: "u", message: accepted });
    const messages = JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages;
    expect(messages).toHaveLength(2);
    expect(messages).toEqual(expect.arrayContaining([other, accepted]));
  });

  it("keeps a confirmed client-ID alias after deletion aborts, retries and repeats", async () => {
    const host = await import("./idbWasmStorageHost");
    const first = { serverId: "11111111-1111-4111-8111-111111111111", clientMsgId: "local-a", conversationId: "a" };
    const other = { serverId: "22222222-2222-4222-8222-222222222222", clientMsgId: first.serverId, conversationId: "b" };
    await host.wasmStorageSaveMessage({ userId: "u", message: first });
    await host.wasmStorageSaveMessage({ userId: "u", message: other });
    const remove = IDBCursor.prototype.delete;
    const failure = vi.spyOn(IDBCursor.prototype, "delete").mockImplementationOnce(function (this: IDBCursor) {
      const request = remove.call(this);
      const store = this.source instanceof IDBObjectStore ? this.source : this.source.objectStore;
      store.transaction.abort();
      return request;
    });
    await expect(host.wasmStorageDeleteMessage({ userId: "u", id: first.serverId })).rejects.toThrow();
    failure.mockRestore();
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages).toHaveLength(2);
    await host.wasmStorageDeleteMessage({ userId: "u", id: first.serverId });
    await host.wasmStorageDeleteMessage({ userId: "u", id: first.serverId });
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages).toEqual([other]);
  });

  it.each([[5, true], [5, false], [6, true]] as const)("preserves v%s rows and adds missing indexes (index=%s)", async (version, index) => {
    const db = await seed(version, index);
    await new Promise<void>((resolve) => {
      const tx = db.transaction(stores, "readwrite");
      tx.objectStore(stores[0]).put({ key: "u::c::1::m", userId: "u", message: { serverId: "m" } });
      tx.objectStore(stores[1]).put({ key: "u::c", userId: "u", conversation: { conversationId: "c" } });
      tx.objectStore(stores[2]).put({ key: "u::cursor", userId: "u", value: "7" });
      tx.objectStore(stores[3]).put({ key: "u::pending", userId: "u", entry: { client_msg_id: "pending", message: { text: "offline" } } });
      tx.oncomplete = () => resolve();
    });
    db.close();
    const host = await import("./idbWasmStorageHost");
    const snapshot = JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" }));
    expect(snapshot).toEqual({ messages: [{ serverId: "m" }], conversations: [{ conversationId: "c" }], cursors: { cursor: "7" }, pendingSends: [{ client_msg_id: "pending", message: { text: "offline" } }] });
  });

  it("keeps the canonical pending send over multiple stale random keys across reloads", async () => {
    const host = await import("./idbWasmStorageHost");
    const current = { client_msg_id: "p", message: { text: "current" }, enqueued_at_ms: 30 };
    await host.wasmStorageSavePendingSend({ userId: "scope-a", entry: current });
    const db = await new Promise<IDBDatabase>((resolve, reject) => {
      const request = database.open("flare-core-web-app");
      request.onerror = () => reject(request.error);
      request.onsuccess = () => { connections.push(request.result); resolve(request.result); };
    });
    await new Promise<void>((resolve) => {
      const tx = db.transaction("wasmPendingSends", "readwrite");
      for (const key of ["scope-a::old-1", "scope-a::old-2"]) {
        tx.objectStore("wasmPendingSends").put({ key, userId: "scope-a", entry: { client_msg_id: "p", message: { text: "stale" }, enqueued_at_ms: 1 } });
      }
      tx.oncomplete = () => resolve();
    });
    for (let reload = 0; reload < 2; reload++) {
      expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "scope-a" })).pendingSends).toEqual([current]);
      expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "scope-b" })).pendingSends).toEqual([]);
    }
  });

  it("atomically migrates and deduplicates random keys when the canonical row is absent", async () => {
    const db = await seed(7);
    const entry = { client_msg_id: "p", enqueued_at_ms: 1, message: { text: "offline" } };
    await new Promise<void>((resolve) => {
      const tx = db.transaction("wasmPendingSends", "readwrite");
      for (const key of ["u::old-1", "u::old-2"]) {
        tx.objectStore("wasmPendingSends").put({ key, userId: "u", entry });
      }
      tx.oncomplete = () => resolve();
    });
    db.close();
    const host = await import("./idbWasmStorageHost");
    const put = IDBObjectStore.prototype.put;
    vi.spyOn(IDBObjectStore.prototype, "put").mockImplementationOnce(function (...args) {
      const result = put.apply(this, args);
      this.transaction.abort();
      return result;
    });
    await expect(host.wasmStorageLoadSnapshot({ userId: "u" })).rejects.toBeTruthy();
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).pendingSends).toEqual([entry]);
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).pendingSends).toEqual([entry]);
  });

  it("rolls back an aborted upgrade and succeeds on retry", async () => {
    const db = await seed(5, false);
    await new Promise<void>((resolve) => {
      const tx = db.transaction("wasmPendingSends", "readwrite");
      tx.objectStore("wasmPendingSends").put({ key: "u::pending", userId: "u", entry: { client_msg_id: "pending" } });
      tx.oncomplete = () => resolve();
    });
    db.close();
    const create = IDBObjectStore.prototype.createIndex;
    vi.spyOn(IDBObjectStore.prototype, "createIndex").mockImplementationOnce(function (...args) {
      const result = create.apply(this, args);
      this.transaction.abort();
      return result;
    });
    const host = await import("./idbWasmStorageHost");
    await expect(host.wasmStorageLoadSnapshot({ userId: "u" })).rejects.toBeTruthy();
    const snapshot = JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" }));
    expect(snapshot.pendingSends).toEqual([{ client_msg_id: "pending" }]);
  });

  it("does not confirm a pending-send deletion before its transaction commits", async () => {
    const host = await import("./idbWasmStorageHost");
    await host.wasmStorageSavePendingSend({ userId: "u", entry: { client_msg_id: "pending" } });
    const remove = IDBObjectStore.prototype.delete;
    vi.spyOn(IDBObjectStore.prototype, "delete").mockImplementationOnce(function (...args) {
      const request = remove.apply(this, args);
      request.addEventListener("success", () => this.transaction.abort());
      return request;
    });
    await expect(host.wasmStorageDeletePendingSend({ userId: "u", id: "pending" })).rejects.toBeTruthy();
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).pendingSends).toEqual([{ client_msg_id: "pending" }]);
    await host.wasmStorageDeletePendingSend({ userId: "u", id: "pending" });
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).pendingSends).toEqual([]);
  });

  it("rejects transaction aborts and preserves the optimistic message on a failed ACK write", async () => {
    const host = await import("./idbWasmStorageHost");
    await host.wasmStorageSaveMessage({ userId: "u", message: { clientMsgId: "c", conversationId: "chat" } });
    const put = IDBObjectStore.prototype.put;
    vi.spyOn(IDBObjectStore.prototype, "put").mockImplementationOnce(function (...args) {
      const result = put.apply(this, args);
      this.transaction.abort();
      return result;
    });
    await expect(host.wasmStorageSaveMessage({ userId: "u", message: { serverId: "s", clientMsgId: "c", conversationId: "chat", conversationSeq: 1 } })).rejects.toBeTruthy();
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages).toEqual([{ clientMsgId: "c", conversationId: "chat" }]);
    await host.wasmStorageSaveMessage({ userId: "u", message: { serverId: "s", clientMsgId: "c", conversationId: "chat", conversationSeq: 1 } });
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages).toHaveLength(1);
  });

  it("rolls back a message batch together and retries it in order", async () => {
    const host = await import("./idbWasmStorageHost");
    const pending = { clientMsgId: "c", conversationId: "chat", senderId: "me" };
    const accepted = { ...pending, serverId: "s", conversationSeq: 1 };
    const other = { ...pending, conversationId: "other" };
    await host.wasmStorageSaveMessage({ userId: "u", message: other });
    const batch = { userId: "u", messages: [pending, accepted] };
    const put = IDBObjectStore.prototype.put;
    const spy = vi.spyOn(IDBObjectStore.prototype, "put")
      .mockImplementationOnce(put)
      .mockImplementationOnce(function (...args) {
        const result = put.apply(this, args);
        this.transaction.abort();
        return result;
      });
    await expect(host.wasmStorageSaveMessages(batch)).rejects.toThrow();
    expect(spy.mock.contexts[0].transaction).toBe(spy.mock.contexts[1].transaction);
    spy.mockRestore();
    const read = async () => JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages;
    expect(await read()).toEqual([other]);
    await host.wasmStorageSaveMessages(batch);
    const messages = await read();
    expect(messages).toHaveLength(2);
    expect(messages).toEqual(expect.arrayContaining([other, accepted]));
  });

  it("upgrades a v7 timeline, boots with metadata only and reads scoped message pages", async () => {
    const db = await seed(7);
    const pending = { clientMsgId: "pending", conversationId: "chat", localState: { isLocal: true } };
    await new Promise<void>((resolve) => {
      const tx = db.transaction(stores[0], "readwrite");
      const store = tx.objectStore(stores[0]);
      store.put({ key: "u::chat::00000000000000000000::pending", userId: "u", message: pending });
      for (const [userId, conversationId] of [["u", "chat"], ["u", "other"], ["other", "chat"]]) {
        for (let conversationSeq = 1; conversationSeq <= 8; conversationSeq++) {
          const serverId = `server-${userId}-${conversationId}-${conversationSeq}`;
          store.put({ key: serverId, userId, message: { serverId, conversationId, conversationSeq } });
        }
      }
      tx.oncomplete = () => resolve();
    });
    db.close();
    const host = await import("./idbWasmStorageHost");
    await host.wasmStorageSaveConversation({ userId: "u", conversation: { conversationId: "chat" } });
    const snapshot = JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u", metadataOnly: true }));
    expect(snapshot.messages).toEqual([]);
    expect(snapshot.conversations).toEqual([{ conversationId: "chat" }]);
    const scope = { userId: "u", kind: "timeline", conversationId: "chat", limit: 2 } as const;
    const page = async (cursor: { beforeSeq?: number; afterSeq?: number; oldestSeq?: number; limit?: number } = {}) =>
      JSON.parse(await host.wasmStorageReadMessages({ ...scope, ...cursor }));
    expect((await page()).map((row: { conversationSeq?: number }) => row.conversationSeq)).toEqual([8, 7, undefined]);
    expect((await page({ beforeSeq: 7 })).map((row: { conversationSeq?: number }) => row.conversationSeq)).toEqual([6, 5]);
    expect((await page({ afterSeq: 2 })).map((row: { conversationSeq?: number }) => row.conversationSeq)).toEqual([3, 4]);
    expect((await page({ oldestSeq: 7, limit: 2001 })).map((row: { conversationSeq?: number }) => row.conversationSeq)).toEqual([8, 7, 6, undefined]);
    expect(JSON.parse(await host.wasmStorageReadMessages({ userId: "other", kind: "ids", ids: ["pending"] }))).toEqual([]);
  });

  it("keeps one out-of-line attachment source, hydrates its original fields, and drops it on ACK", async () => {
    const host = await import("./idbWasmStorageHost");
    const source = `data:application/octet-stream;name=large.bin;size=840000;base64,${"YWJj".repeat(280_000)}`;
    const content = { contentType: "file", fileId: source, url: source, fileName: "large.bin", fileSize: 840000 };
    const message = { clientMsgId: "c", conversationId: "chat", senderId: "me", content, localState: { isLocal: true }, encodedContent: [8, 42] };
    const put = vi.spyOn(IDBObjectStore.prototype, "put");

    await host.wasmStorageSaveMessage({ userId: "u", message });

    const row = put.mock.calls[0][0];
    expect(row.message.content).toEqual({ ...content, fileId: "", url: "" });
    expect(row.message).not.toHaveProperty("encodedContent");
    expect(row.localFileSources.url).toBe("fileId");
    expect(await row.localFileSources.fileId.text()).toBe(source);
    expect(message.content.fileId).toBe(source);
    expect(message.encodedContent).toEqual([8, 42]);
    const snapshot = async () => JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages;
    const { encodedContent: _encodedContent, ...hydrated } = message;
    expect(await snapshot()).toEqual([hydrated]);

    const accepted = {
      ...message, serverId: "s", conversationSeq: 1, localState: { isLocal: false },
      content: { ...content, fileId: "stored", url: "" },
    };
    await host.wasmStorageSaveMessage({ userId: "u", message: accepted });
    expect(put.mock.lastCall?.[0]).not.toHaveProperty("localFileSources");
    expect(await snapshot()).toEqual([accepted]);
  });

  it("hydrates a large local URL without replacing the file identifier", async () => {
    const host = await import("./idbWasmStorageHost");
    const url = `data:application/octet-stream;base64,${"YWJj".repeat(280_000)}`;
    const message = {
      serverId: "", clientMsgId: "c", conversationId: "chat", localState: { isLocal: true },
      content: { contentType: "file", fileId: "", url },
    };
    await host.wasmStorageSaveMessage({ userId: "u", message });
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages).toEqual([message]);
    await host.wasmStorageDeleteMessage({ userId: "u", id: "c" });
    expect(JSON.parse(await host.wasmStorageLoadSnapshot({ userId: "u" })).messages).toEqual([]);
  });
});
