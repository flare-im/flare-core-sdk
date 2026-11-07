import { beforeAll, describe, expect, it } from "vitest";

import { createMemoryAccessStoreHost, type WasmAccessStoreHost } from "./idbAccessStoreHost";
import { loadWasmRuntimeForTests, wasmPkgAvailable } from "./testing/loadWasmRuntimeForTests";

type HookedRuntime = Awaited<ReturnType<typeof loadWasmRuntimeForTests>> & {
  setAccessStoreHost?: (host: unknown) => Promise<void>;
  setConnectTokenRefresher?: (refresher: unknown) => Promise<void>;
};

/** Records which keys the core reads and writes through the page host. */
function recordingHost(): WasmAccessStoreHost & { calls: string[] } {
  const inner = createMemoryAccessStoreHost();
  const calls: string[] = [];
  return {
    calls,
    get: (key) => { calls.push(`get ${key}`); return inner.get(key); },
    commit: (ops) => { calls.push(`commit ${ops.map((op) => `${op.op}:${op.key}`).join(",")}`); return inner.commit(ops); },
    scan: (prefix) => { calls.push(`scan ${prefix}`); return inner.scan(prefix); },
  };
}

const developmentInit = JSON.stringify({
  sdkConfig: {
    tenantId: "0",
    access: { trustMode: "development", developmentEndpoints: { wsUrl: "ws://127.0.0.1:9" } },
  },
});

// The wasm pkg comes from `wasm-pack build` in flare-core-sdk-engine/bindings/wasm; skip without it.
describe.skipIf(!wasmPkgAvailable())("wasm access store host (real runtime)", () => {
  let runtime: HookedRuntime;

  beforeAll(async () => {
    runtime = await loadWasmRuntimeForTests() as HookedRuntime;
  });

  it("loads the access directory through the injected host", async () => {
    expect(typeof runtime.setAccessStoreHost).toBe("function");
    const host = recordingHost();
    await runtime.setAccessStoreHost!(host);
    await runtime.invoke("sdk.init", developmentInit);

    // Pinning waits for the directory: the core has read its health book through the host by then.
    await runtime.invoke("access.pin", JSON.stringify({ accessPointId: "development" }));

    expect(host.calls).toContain("scan flare-access/health/");
    expect(host.calls.every((call) => call.split(" ")[1]?.startsWith("flare-access/") ?? false)).toBe(true);
  });

  it("refuses a host without the three methods", () => {
    expect(() => runtime.setAccessStoreHost!({ get: async () => null })).toThrow(/commit/);
  });
});
