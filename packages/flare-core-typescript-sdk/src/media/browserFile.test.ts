import { afterEach, describe, expect, it, vi } from "vitest";
import { browserFileMessageContent, MAX_BROWSER_FILE_BYTES, releaseBrowserFileMessageContent } from "./index";

afterEach(() => vi.restoreAllMocks());

describe("browser file message source", () => {
  it("builds and releases a 10 GiB source using metadata only", () => {
    const url = "blob:https://chat.example/large-file";
    const create = vi.spyOn(URL, "createObjectURL").mockReturnValue(url);
    const revoke = vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => {});
    const arrayBuffer = vi.fn();
    const file = { name: "large.bin", type: "", size: MAX_BROWSER_FILE_BYTES, arrayBuffer } as unknown as File;

    const content = browserFileMessageContent(file, "  原始文件  ");
    expect(content).toEqual({
      contentType: "file", fileId: url, url, fileName: "large.bin", fileSize: MAX_BROWSER_FILE_BYTES,
      mimeType: "application/octet-stream", description: "原始文件",
    });
    expect(create).toHaveBeenCalledWith(file);
    expect(arrayBuffer).not.toHaveBeenCalled();
    releaseBrowserFileMessageContent(content);
    releaseBrowserFileMessageContent(content);
    expect(revoke).toHaveBeenCalledExactlyOnceWith(url);
  });

  it("rejects an attachment above 10 GiB before creating a source", () => {
    const create = vi.spyOn(URL, "createObjectURL");
    expect(() => browserFileMessageContent({ size: MAX_BROWSER_FILE_BYTES + 1 } as File)).toThrow(RangeError);
    expect(create).not.toHaveBeenCalled();
  });
});
