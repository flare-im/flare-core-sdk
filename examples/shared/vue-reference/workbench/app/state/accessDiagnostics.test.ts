import { beforeEach, describe, expect, it, vi } from "vitest";
import { createAccessDiagnostics } from "./accessDiagnostics";

function fakeClient() {
  const listeners: Array<{ onAccessChanged?: () => void }> = [];
  const unsubscribe = vi.fn();
  return {
    listeners,
    unsubscribe,
    access: {
      getStatus: vi.fn(async () => ({ loaded: true, serial: 7 })),
      listAccessPoints: vi.fn(async () => [{ accessPointId: "ap-a" }]),
      pin: vi.fn(async () => ({})),
      unpin: vi.fn(async () => undefined),
      refresh: vi.fn(async () => ({ outcome: "upToDate" })),
      importRecovery: vi.fn(async () => ({ outcome: "adopted", serial: 9 })),
      exportDiagnostics: vi.fn(async () => ({ status: { serial: 7 } })),
    },
    events: {
      addEventListener: vi.fn((listener: { onAccessChanged?: () => void }) => {
        listeners.push(listener);
        return { id: 1, unsubscribe };
      }),
    },
  };
}

describe("the access diagnostics host", () => {
  let fake: ReturnType<typeof fakeClient>;
  const onPinFailed = vi.fn();
  const writeClipboard = vi.fn(async (_text: string) => undefined);
  const host = () => createAccessDiagnostics({ client: fake as never, onPinFailed, writeClipboard });

  beforeEach(() => {
    fake = fakeClient();
    onPinFailed.mockClear();
    writeClipboard.mockReset();
    writeClipboard.mockImplementation(async () => undefined);
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
  });

  it("reads the directory on opening and on every link event, and stops when told to", async () => {
    const page = host();
    const stop = page.follow();
    await vi.waitFor(() => expect(page.status.value).toEqual({ loaded: true, serial: 7 }));
    expect(page.accessPoints.value).toEqual([{ accessPointId: "ap-a" }]);

    fake.access.getStatus.mockResolvedValue({ loaded: true, serial: 8 });
    fake.listeners[0]?.onAccessChanged?.();
    await vi.waitFor(() => expect(page.status.value).toEqual({ loaded: true, serial: 8 }));

    stop();
    expect(fake.unsubscribe).toHaveBeenCalledOnce();
  });

  it("says so when the line is gone from the directory, and reads again", async () => {
    const page = host();
    fake.access.pin.mockRejectedValueOnce(new Error("unknown access point"));
    await page.pin("ap-gone");
    expect(onPinFailed).toHaveBeenCalledOnce();
    expect(fake.access.getStatus).toHaveBeenCalledOnce();
  });

  it("clears the last refresh answer while a round runs, and reads a throw as failed", async () => {
    const page = host();
    page.refreshOutcome.value = "failed";
    fake.access.refresh.mockImplementationOnce(async () => {
      expect(page.refreshOutcome.value).toBeNull();
      expect(page.refreshing.value).toBe(true);
      return { outcome: "adopted" };
    });
    await page.refresh();
    expect(page.refreshOutcome.value).toBe("adopted");

    fake.access.refresh.mockRejectedValueOnce(new Error("CONFIGURATION_ERROR"));
    await page.refresh();
    expect(page.refreshOutcome.value).toBe("failed");
  });

  it("passes a recovery link as it is and carries a rejection's code back to the page", async () => {
    const page = host();
    fake.access.importRecovery.mockResolvedValueOnce({ outcome: "rejected", code: "rollback", serial: 7 } as never);
    await page.importRecovery("flare-recover://v1?p=a&k=b&s=c");
    expect(fake.access.importRecovery).toHaveBeenCalledWith({ link: "flare-recover://v1?p=a&k=b&s=c" });
    expect(page.importResult.value).toMatchObject({ outcome: "rejected", code: "rollback" });
  });

  it("does not stay silent when an import throws", async () => {
    const page = host();
    fake.access.importRecovery.mockRejectedValueOnce(new Error("CONFIGURATION_ERROR"));
    await page.importRecovery("flare-recover://x");
    expect(page.importResult.value).toEqual({ outcome: "rejected" });
    expect(page.importing.value).toBe(false);
  });

  it("copies the diagnostics as readable JSON and reports whether the clipboard took them", async () => {
    const page = host();
    await page.exportDiagnostics();
    expect(writeClipboard).toHaveBeenCalledWith(JSON.stringify({ status: { serial: 7 } }, null, 2));
    expect(page.exportOutcome.value).toBe("copied");

    writeClipboard.mockRejectedValueOnce(new Error("denied"));
    await page.exportDiagnostics();
    expect(page.exportOutcome.value).toBe("failed");
    expect(page.exporting.value).toBe(false);
  });
});
