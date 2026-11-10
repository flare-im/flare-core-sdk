import { describe, expect, it, vi } from "vitest";
import type { FlarePluginFileAction, FlarePluginFileState, FlarePluginInput } from "@flare-im/vue-ui";
import { PluginFileUploads, pluginFileSessionData } from "../src/pluginFileUploads";
import { deferred, fakePort } from "./support";

const input: FlarePluginInput = { id: "qr", kind: "file", label: "Code", file: {
  accept: ["image/png"], maxBytes: 5,
  upload: { prepareOperation: "test.prepare", completeOperation: "test.complete", purpose: "code" },
} };
const event = (action: FlarePluginFileAction["action"] = "choose", generation = 1, scope = "s"): FlarePluginFileAction =>
  ({ action, input, inputId: input.id, scope, generation, formValues: { kind: "wechat" } });
function harness() {
  const port = fakePort(), choose = vi.fn(async (): Promise<File | null> => new File([new Uint8Array([1, 2])], "code.png", { type: "image/png" }));
  let identity = {};
  let available = true;
  let states: Record<string, FlarePluginFileState> = {};
  const revoke = vi.fn(), preview = vi.fn(), commandId = vi.fn().mockReturnValueOnce("one").mockReturnValueOnce("two");
  const uploads = new PluginFileUploads({ context: () => available ? ({ identity, port, page: { pluginId: "test", page: "payout" }, platform: "web" }) : null,
    choose, changed: (next) => { states = next; }, failure: (kind) => kind,
    preview, commandId, createUrl: () => "blob:local", revokeUrl: revoke });
  return { uploads, port, choose, revoke, preview, commandId, state: () => states.qr, switchOwner: () => { identity = {}; }, disconnect: () => { available = false; } };
}

describe("host file uploads", () => {
  it("captures the displayed viewer without copying balances or borrowing future identity mutations", () => {
    const data = { _session: { tenantId: "app", userId: "before" }, balance: "private" };
    const snapshot = pluginFileSessionData(data);
    data._session.userId = "after";
    expect(snapshot).toEqual({ _session: { tenantId: "app", userId: "before" } });
    expect(pluginFileSessionData(null)).toEqual({ _session: null });
  });
  it("submits selected bytes through Core and keeps only its opaque reference in form state", async () => {
    const h = harness();
    await h.uploads.action(event());
    expect(h.port.uploadFile).toHaveBeenCalledExactlyOnceWith({ page: { pluginId: "test", page: "payout" }, platform: "web",
      inputId: "qr", formValues: { kind: "wechat" }, fileName: "code.png", contentType: "image/png", bytes: [1, 2], commandId: "one" });
    expect(h.state()).toEqual({ scope: "s", generation: 1, phase: "uploaded", fileName: "code.png", preview: true, value: { fileId: "test-file" } });
    await h.uploads.action(event("preview"));
    expect(h.preview).toHaveBeenCalledExactlyOnceWith("blob:local", "code.png");
    h.uploads.clear();
    expect(h.revoke).toHaveBeenCalledExactlyOnceWith("blob:local");
    expect(h.state()).toBeUndefined();
  });
  it("retains the same selected bytes and command on retry, but allocates a new command for replacement", async () => {
    const h = harness();
    h.port.uploadFile.mockRejectedValueOnce(new Error("offline"));
    await h.uploads.action(event());
    expect(h.state().phase).toBe("failed");
    await h.uploads.action(event("retry", 2));
    await h.uploads.action(event("replace", 3));
    expect(h.choose).toHaveBeenCalledTimes(2);
    expect(h.port.uploadFile.mock.calls.map(([r]) => r.commandId)).toEqual(["one", "one", "two"]);
  });
  it.each([new File(["too large"], "code.png", { type: "image/png" }), new File(["x"], "code.html", { type: "text/html" })])(
    "rejects local policy violations before any transfer", async (file) => {
      const h = harness(); h.choose.mockResolvedValue(file);
      await h.uploads.action(event());
      expect(h.state()).toMatchObject({ phase: "failed", error: "policy" });
      expect(h.port.uploadFile).not.toHaveBeenCalled();
    });
  it("drops a late completion after a controller change or viewer switch", async () => {
    for (const invalidate of [true, false]) {
      const h = harness(), pending = deferred<{ fileId: string }>();
      h.port.uploadFile.mockImplementation(() => pending.promise);
      const action = h.uploads.action(event());
      await vi.waitFor(() => expect(h.port.uploadFile).toHaveBeenCalledOnce());
      if (invalidate) await h.uploads.action(event("invalidate", 2)); else h.switchOwner();
      pending.resolve({ fileId: "late" }); await action;
      expect(h.state().value).toBeUndefined();
      expect(h.state().phase).not.toBe("uploaded");
    }
  });
  it("does not let stale removal invalidate a new mounted form", async () => {
    const h = harness();
    await h.uploads.action(event("choose", 1, "new"));
    await h.uploads.action(event("invalidate", 2, "old"));
    expect(h.state()).toMatchObject({ scope: "new", phase: "uploaded" });
  });
  it("ignores completion after the SDK port becomes unavailable", async () => {
    const h = harness(), pending = deferred<{ fileId: string }>();
    h.port.uploadFile.mockImplementation(() => pending.promise);
    const action = h.uploads.action(event());
    await vi.waitFor(() => expect(h.port.uploadFile).toHaveBeenCalledOnce());
    h.disconnect(); pending.resolve({ fileId: "late" });
    await expect(action).resolves.toBeUndefined();
    expect(h.state().value).toBeUndefined();
  });
  it("rejects an unexpected SDK reply instead of treating a grant URL as a durable file", async () => {
    const h = harness(), reply = { fileId: "opaque", readUrl: "https://unused.invalid/private" };
    h.port.uploadFile.mockResolvedValue(reply);
    await h.uploads.action(event());
    expect(h.state()).toMatchObject({ phase: "failed", error: "transport" });
    expect(h.state().value).toBeUndefined();
  });
  it("ignores an old retry after a newer replacement", async () => {
    const h = harness();
    await h.uploads.action(event());
    await h.uploads.action(event("replace", 3));
    await h.uploads.action(event("retry", 2));
    expect(h.port.uploadFile).toHaveBeenCalledTimes(2);
    expect(h.state()).toMatchObject({ generation: 3, phase: "uploaded" });
  });
  it("preserves a completed reference if the replacement picker is dismissed", async () => {
    const h = harness();
    await h.uploads.action(event());
    h.choose.mockResolvedValue(null);
    await h.uploads.action(event("replace", 2));
    expect(h.state()).toMatchObject({ generation: 2, phase: "uploaded", value: { fileId: "test-file" } });
    expect(h.port.uploadFile).toHaveBeenCalledOnce();
  });
});
