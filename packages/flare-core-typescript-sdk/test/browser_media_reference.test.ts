import { describe, expect, it, vi } from "vitest";
import { browserMediaFor } from "../src/media";

describe("browser message media authorization", () => {
  it("resolves a recipient's message reference for previews and attachment URLs", async () => {
    const invoke = vi.fn(async (op: string, request: Record<string, unknown>) => {
      if (op === "message.get") return { conversationId: "chat-1", conversationSeq: 17 };
      if (request.conversationId !== "chat-1" || request.messageSeq !== 17) throw new Error("FORBIDDEN");
      return op === "media.resolve_access"
        ? { source: "remote", remote: { url: "https://im.example/image" } }
        : { url: "https://im.example/download" };
    });
    const media = browserMediaFor(invoke);
    await expect(media.resolveMediaAccess({ fileId: "photo", messageId: "incoming-1" })).resolves.toMatchObject({
      remote: { url: "https://im.example/image" },
    });
    await expect(media.getTempDownloadUrl({ fileId: "attachment", messageId: "incoming-1" })).resolves.toMatchObject({
      url: "https://im.example/download",
    });
    expect(invoke).toHaveBeenCalledWith("media.get_url", expect.objectContaining({ conversationId: "chat-1", messageSeq: 17 }));
  });

  it("preserves explicit references and lets uncommitted own media use owner authorization", async () => {
    const invoke = vi.fn(async (op: string) => op === "message.get"
      ? { conversationId: "chat-1", conversationSeq: 0 }
      : { url: "https://im.example/own" });
    const media = browserMediaFor(invoke);
    await media.getTempDownloadUrl({ fileId: "own", messageId: "local-1" });
    expect(invoke).toHaveBeenLastCalledWith("media.get_url", { fileId: "own", messageId: "local-1" });
    invoke.mockClear();
    await media.getTempDownloadUrl({ fileId: "shared", conversationId: "chat-2", messageSeq: 8 });
    expect(invoke).toHaveBeenCalledTimes(1);
    expect(invoke).toHaveBeenCalledWith("media.get_url", { fileId: "shared", conversationId: "chat-2", messageSeq: 8 });
  });
});
