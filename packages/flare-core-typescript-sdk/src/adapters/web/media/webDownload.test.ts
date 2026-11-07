import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { MediaApi } from "../../../api/modules/media";
import { sanitizeDownloadFileName, uniqueDownloadName, withExtensionFor, type DirectoryHandleLike } from "./browserDownload";
import { WebMediaApi } from "./WebMediaApi";

const pickedSave = vi.hoisted(() => ({
  result: undefined as { directory: string; fileName: string } | undefined,
  records: new Map<string, { directory: string; fileName: string }>(),
  presence: "present" as "present" | "missing" | "unknown",
}));

vi.mock("./browserDownload", async (importOriginal) => {
  const actual = await importOriginal<typeof import("./browserDownload")>();
  return {
    ...actual,
    saveBlobToPickedDirectory: vi.fn(async () => pickedSave.result),
    recordSavedDownload: vi.fn(async (key: string, record: { directory: string; fileName: string }) => {
      pickedSave.records.set(key, record);
    }),
    savedDownloadRecord: vi.fn(async (key: string) => pickedSave.records.get(key)),
    forgetSavedDownload: vi.fn(async (key: string) => {
      pickedSave.records.delete(key);
    }),
    savedDownloadPresence: vi.fn(async () => pickedSave.presence),
  };
});

class MockCache {
  readonly entries = new Map<string, Response>();
  async match(key: Request | string): Promise<Response | undefined> {
    const hit = this.entries.get(typeof key === "string" ? key : key.url);
    return hit?.clone();
  }
  async put(key: string, response: Response): Promise<void> {
    this.entries.set(key, response);
  }
  async delete(key: string): Promise<boolean> {
    return this.entries.delete(key);
  }
  async keys(): Promise<Request[]> {
    return [...this.entries.keys()].map((url) => new Request(url));
  }
}

const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]);

function innerApi(): MediaApi {
  return {
    getTempDownloadUrl: vi.fn(async ({ fileId }: Record<string, unknown>) => ({
      url: `https://media.example/attach/${String(fileId)}?sig=1`,
    })),
    resolveMediaAccess: vi.fn(async ({ fileId }: Record<string, unknown>) => ({
      source: "remote",
      remote: { url: `https://media.example/view/${String(fileId)}?sig=1` },
    })),
  } as unknown as MediaApi;
}

describe("WebMediaApi downloads", () => {
  let cache: MockCache;
  let anchors: Array<{ href: string; download: string; clicked: boolean }>;
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    pickedSave.result = undefined;
    pickedSave.records.clear();
    pickedSave.presence = "present";
    cache = new MockCache();
    anchors = [];
    vi.stubGlobal("caches", { open: vi.fn(async () => cache), delete: vi.fn(async () => true) });
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response(PNG, {
          status: 200,
          headers: { "content-type": "image/png", "content-length": String(PNG.byteLength) },
        }),
      ),
    );
    vi.stubGlobal("document", {
      createElement: () => {
        const anchor = { href: "", download: "", rel: "", style: {}, clicked: false, click() { this.clicked = true; }, remove() {} };
        anchors.push(anchor);
        return anchor;
      },
      body: { appendChild: () => undefined },
    });
    URL.createObjectURL = vi.fn(() => "blob:saved") as typeof URL.createObjectURL;
    URL.revokeObjectURL = vi.fn() as typeof URL.revokeObjectURL;
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    globalThis.fetch = originalFetch;
  });

  it("saves through the browser, caches the picture, then serves the second save from cache", async () => {
    const inner = innerApi();
    const api = WebMediaApi.fromInner(inner);

    const first = await api.downloadToUserDirectory({ fileId: "f1", fileName: "截图.png" });
    expect(first).toMatchObject({ savedVia: "browser", fileName: "截图.png", sizeBytes: PNG.byteLength, fromCache: false, downloadKey: "f1" });
    expect(anchors).toHaveLength(1);
    expect(anchors[0]).toMatchObject({ href: "blob:saved", download: "截图.png", clicked: true });
    expect(inner.getTempDownloadUrl).toHaveBeenCalledTimes(1);

    // Caching the finished download happens right after; let it land.
    await new Promise((resolve) => setTimeout(resolve, 0));
    const second = await api.downloadToUserDirectory({ fileId: "f1", fileName: "截图.png" });
    const unnamed = await api.downloadToUserDirectory({ fileId: "f1", fileName: "IMG_1" });
    expect(unnamed.fileName).toBe("IMG_1.png");
    expect(second.fromCache).toBe(true);
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
  });

  it("writes into the picked folder when the browser allows it", async () => {
    pickedSave.result = { directory: "Flare 下载", fileName: "报告 (1).pdf" };
    const api = WebMediaApi.fromInner(innerApi());
    const saved = await api.downloadToUserDirectory({ fileId: "f2", fileName: "报告.pdf" });
    expect(saved).toMatchObject({
      savedVia: "directory",
      directory: "Flare 下载",
      fileName: "报告 (1).pdf",
      path: "Flare 下载/报告 (1).pdf",
    });
    expect(anchors).toHaveLength(0);
  });

  it("keeps the message reference when obtaining a recipient's download URL", async () => {
    const inner = innerApi();
    await WebMediaApi.fromInner(inner).downloadToUserDirectory({
      fileId: "shared", messageId: "incoming", conversationId: "chat-1", messageSeq: 9,
    });
    expect(inner.getTempDownloadUrl).toHaveBeenCalledWith(expect.objectContaining({
      fileId: "shared", messageId: "incoming", conversationId: "chat-1", messageSeq: 9,
    }));
  });

  it("remembers a file saved into the picked folder until it is gone", async () => {
    pickedSave.result = { directory: "Flare 下载", fileName: "报告.pdf" };
    const api = WebMediaApi.fromInner(innerApi());
    await api.downloadToUserDirectory({ fileId: "f4", fileName: "报告.pdf" });

    expect(await api.getUserDownloadSavedPath({ downloadKey: "f4" })).toMatchObject({
      path: "Flare 下载/报告.pdf",
      fileName: "报告.pdf",
      verified: true,
    });

    // The browser will not let the page look: the record stands, unverified.
    pickedSave.presence = "unknown";
    expect(await api.getUserDownloadSavedPath({ downloadKey: "f4" })).toMatchObject({ path: "Flare 下载/报告.pdf", verified: false });

    // The user deleted it: the record goes, and the next lookup finds nothing either.
    pickedSave.presence = "missing";
    expect(await api.getUserDownloadSavedPath({ downloadKey: "f4" })).toEqual({ path: null });
    pickedSave.presence = "present";
    expect(await api.getUserDownloadSavedPath({ downloadKey: "f4" })).toEqual({ path: null });
  });

  it("does not track a file the browser saved through its own download flow", async () => {
    pickedSave.records.set("f5", { directory: "Flare 下载", fileName: "old.png" });
    const api = WebMediaApi.fromInner(innerApi());
    await api.downloadToUserDirectory({ fileId: "f5", fileName: "新.png" });
    expect(await api.getUserDownloadSavedPath({ downloadKey: "f5" })).toEqual({ path: null });
  });

  it("falls back to the browser downloading the attachment URL when it cannot be read (CORS)", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => { throw new TypeError("Failed to fetch"); }));
    const api = WebMediaApi.fromInner(innerApi());
    const saved = await api.downloadToUserDirectory({ fileId: "f3", fileName: "a.zip" });
    expect(saved).toMatchObject({ savedVia: "browser", sizeBytes: 0 });
    expect(anchors[0]?.href).toBe("https://media.example/attach/f3?sig=1");
  });

  it("can be cancelled by download key", async () => {
    let release: () => void = () => undefined;
    vi.stubGlobal(
      "fetch",
      vi.fn(
        (_url: string, init: RequestInit) =>
          new Promise<Response>((_, reject) => {
            init.signal?.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
            release = () => reject(new Error("never"));
          }),
      ),
    );
    const api = WebMediaApi.fromInner(innerApi());
    const pending = api.downloadToUserDirectory({ fileId: "f4", fileName: "big.mp4", downloadKey: "k4" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    await expect(api.cancelUserFileDownload({ downloadKey: "k4" })).resolves.toBe(true);
    await expect(pending).rejects.toThrow();
    expect(anchors).toHaveLength(0);
    release();
    await expect(api.cancelUserFileDownload({ downloadKey: "k4" })).resolves.toBe(false);
  });

  it("caches a displayed picture in the background only when asked, once per file", async () => {
    const api = WebMediaApi.fromInner(innerApi());
    await api.resolveMediaAccess({ fileId: "p1" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(globalThis.fetch).not.toHaveBeenCalled();

    await Promise.all([
      api.resolveMediaAccess({ fileId: "p1", autoCache: true }),
      api.resolveMediaAccess({ fileId: "p1", autoCache: true }),
    ]);
    await new Promise((resolve) => setTimeout(resolve, 10));
    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
    expect(await api.resolveDisplayUrl({ fileId: "p1" })).toBe("blob:saved");
  });

  it("reports the browser-managed location and refuses a named folder", async () => {
    const api = WebMediaApi.fromInner(innerApi());
    await expect(api.getUserDownloadDirectory()).resolves.toMatchObject({
      isCustom: false,
      managedByBrowser: true,
    });
    await expect(api.setUserDownloadDirectory({ directory: "/Users/me/Downloads" })).rejects.toThrow();
  });
});

describe("browser download names", () => {
  it("adds an extension from the type when the name has none", () => {
    expect(withExtensionFor("IMG_20260927", "image/png")).toBe("IMG_20260927.png");
    expect(withExtensionFor("报告.pdf", "application/octet-stream")).toBe("报告.pdf");
    expect(withExtensionFor("blob", "application/octet-stream")).toBe("blob");
  });

  it("sanitizes like the native core", () => {
    expect(sanitizeDownloadFileName("../../etc/passwd")).toBe("passwd");
    expect(sanitizeDownloadFileName("a?b:c.txt")).toBe("a_b_c.txt");
    expect(sanitizeDownloadFileName(" .. ")).toBe("download");
  });

  it("numbers duplicates in the picked folder", async () => {
    const existing = new Set(["a.png", "a (1).png"]);
    const dir: DirectoryHandleLike = {
      kind: "directory",
      name: "d",
      getFileHandle: async (name) => {
        if (!existing.has(name)) throw new DOMException("missing", "NotFoundError");
        return { createWritable: async () => ({ write: async () => undefined, close: async () => undefined }) };
      },
    };
    await expect(uniqueDownloadName(dir, "a.png")).resolves.toBe("a (2).png");
    await expect(uniqueDownloadName(dir, "b.png")).resolves.toBe("b.png");
  });
});
