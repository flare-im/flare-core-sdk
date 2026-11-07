import "fake-indexeddb/auto";

import { describe, expect, it, vi } from "vitest";

import {
  createIndexedDbAccessStoreHost,
  createMemoryAccessStoreHost,
  type WasmAccessStoreHost,
} from "./idbAccessStoreHost";

const bytes = (text: string) => new TextEncoder().encode(text);
const text = (value: Uint8Array | null) => (value ? new TextDecoder().decode(value) : null);

let databases = 0;
function freshDbName(): string {
  databases += 1;
  return `flare-access-test-${databases}`;
}

async function exerciseHost(host: WasmAccessStoreHost): Promise<void> {
  await host.commit([
    { op: "put", key: "flare-access/serial/access/app", value: bytes("41") },
    { op: "put", key: "flare-access/manifest/access/app/current", value: bytes("{\"serial\":41}") },
    { op: "put", key: "flare-access/health/ap/a/net1", value: bytes("a") },
    { op: "put", key: "flare-access/health/ap/b/net1", value: bytes("b") },
    { op: "put", key: "flare-access/health/net/net1", value: bytes("n") },
  ]);
  expect(text(await host.get("flare-access/serial/access/app"))).toBe("41");
  expect(await host.get("flare-access/missing")).toBeNull();

  const scanned = await host.scan("flare-access/health/ap/");
  expect(scanned.map(([key, value]) => [key, text(value)])).toEqual([
    ["flare-access/health/ap/a/net1", "a"],
    ["flare-access/health/ap/b/net1", "b"],
  ]);

  await host.commit([
    { op: "put", key: "flare-access/serial/access/app", value: bytes("42") },
    { op: "delete", key: "flare-access/health/ap/a/net1" },
  ]);
  expect(text(await host.get("flare-access/serial/access/app"))).toBe("42");
  expect(await host.get("flare-access/health/ap/a/net1")).toBeNull();
}

describe("IndexedDB access store host", () => {
  it("gets, commits and scans by prefix", async () => {
    const host = await createIndexedDbAccessStoreHost({ dbName: freshDbName() });
    await exerciseHost(host);
  });

  it("keeps what it stored across a reopen (the next launch's LKG)", async () => {
    const dbName = freshDbName();
    const first = await createIndexedDbAccessStoreHost({ dbName });
    await first.commit([{ op: "put", key: "flare-access/serial/access/app", value: bytes("7") }]);

    const second = await createIndexedDbAccessStoreHost({ dbName });
    expect(text(await second.get("flare-access/serial/access/app"))).toBe("7");
  });

  it("commits all of a batch or none of it", async () => {
    const host = await createIndexedDbAccessStoreHost({ dbName: freshDbName() });
    await host.commit([{ op: "put", key: "flare-access/serial/access/app", value: bytes("1") }]);

    // A key IndexedDB refuses fails the whole transaction: the put before it is rolled back too.
    await expect(host.commit([
      { op: "put", key: "flare-access/serial/access/app", value: bytes("2") },
      { op: "put", key: undefined as unknown as string, value: bytes("x") },
    ])).rejects.toBeTruthy();

    expect(text(await host.get("flare-access/serial/access/app"))).toBe("1");
  });

  it("hands back copies, not the stored buffers", async () => {
    const host = await createIndexedDbAccessStoreHost({ dbName: freshDbName() });
    const value = bytes("abc");
    await host.commit([{ op: "put", key: "k", value }]);
    value[0] = 0;

    const read = await host.get("k");
    expect(text(read)).toBe("abc");
    read![0] = 0;
    expect(text(await host.get("k"))).toBe("abc");
  });

  it("falls back to memory with a diagnostic when IndexedDB is missing", async () => {
    const onDiagnostic = vi.fn();
    const host = await createIndexedDbAccessStoreHost({ indexedDB: null, onDiagnostic });

    expect(onDiagnostic).toHaveBeenCalledTimes(1);
    expect(onDiagnostic.mock.calls[0]?.[0]).toContain("IndexedDB is unavailable");
    await exerciseHost(host);
  });

  it("falls back to memory with a diagnostic when IndexedDB refuses to open", async () => {
    const onDiagnostic = vi.fn();
    const refusing = {
      open: () => { throw new DOMException("The operation is insecure.", "SecurityError"); },
    } as unknown as IDBFactory;

    const host = await createIndexedDbAccessStoreHost({ indexedDB: refusing, onDiagnostic });

    expect(onDiagnostic).toHaveBeenCalledTimes(1);
    expect(onDiagnostic.mock.calls[0]?.[0]).toContain("stays in memory");
    await exerciseHost(host);
  });

  it("memory host behaves like the IndexedDB one", async () => {
    await exerciseHost(createMemoryAccessStoreHost());
  });
});
