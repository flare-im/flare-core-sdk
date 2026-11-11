import { describe, expect, it, vi } from "vitest";
import { inspectWebSdk } from "../../../examples/minimal/typescript-client";

function runtimeFixture(failDiagnostics = false) {
  return {
    invoke: vi.fn(async (operation: string) => {
      if (operation === "diagnostics.sdk_version") {
        if (failDiagnostics) throw new Error("diagnostics unavailable");
        return { version: "fixture-sdk" };
      }
      if (operation === "diagnostics.ffi_contract_version") return { version: "fixture-contract" };
      return null;
    }),
    setEventCallback: vi.fn(),
    setStorageHost: vi.fn(),
    setAccessStoreHost: vi.fn(),
    dispose: vi.fn(),
  };
}

describe("minimal public SDK consumer", () => {
  it("reads diagnostics and releases the loaded runtime", async () => {
    const runtime = runtimeFixture();
    const result = await inspectWebSdk(async () => ({ runtime }));
    expect(result).toEqual({ sdk: { version: "fixture-sdk" }, contract: { version: "fixture-contract" } });
    expect(runtime.dispose).toHaveBeenCalledOnce();
  });

  it("releases the runtime when a diagnostic call fails", async () => {
    const runtime = runtimeFixture(true);
    await expect(inspectWebSdk(async () => ({ runtime }))).rejects.toThrow("diagnostics unavailable");
    expect(runtime.dispose).toHaveBeenCalledOnce();
  });
});
