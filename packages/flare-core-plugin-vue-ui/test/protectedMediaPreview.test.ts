import { describe, expect, it, vi } from "vitest";
import { protectedMediaPreview } from "../src/protectedMediaPreview";

const source = "http://127.0.0.1:56200/private/realname/owner-materials/a/b?grant=synthetic";
function options() {
  const request = vi.fn<typeof fetch>(async () => new Response(new Uint8Array([1, 2]), { headers: { "content-type": "image/png" } }));
  return { signal: new AbortController().signal, origin: "http://127.0.0.1:1435", fetch: request,
    createUrl: vi.fn(() => "blob:private"), revokeUrl: vi.fn() };
}
describe("local protected previews", () => {
  it("reads only in memory without credentials, referrers, redirects or caching; releases once", async () => {
    const config = options();
    const preview = await protectedMediaPreview(source, config);
    expect(config.fetch).toHaveBeenCalledWith(source, expect.objectContaining({ cache: "no-store", credentials: "omit", redirect: "error", referrerPolicy: "no-referrer", signal: config.signal }));
    expect(preview.url).toBe("blob:private");
    preview.release(); preview.release();
    expect(config.revokeUrl).toHaveBeenCalledExactlyOnceWith("blob:private");
  });
  it("leaves an already supported secure source to the kit", async () => {
    const config = options();
    expect((await protectedMediaPreview("https://example.test/image?grant=synthetic", config)).url).toContain("https://example.test/");
    expect(config.fetch).not.toHaveBeenCalled();
  });
  it.each(["https://example.test", "http://example.test"])("refuses loopback HTTP reads from a remote app %s", async origin => {
    const config = { ...options(), origin };
    await expect(protectedMediaPreview(source, config)).rejects.toThrow();
    expect(config.fetch).not.toHaveBeenCalled();
  });
  it.each(["http://outside.test/material", "http://user:pass@127.0.0.1/material", "javascript:alert(1)"])("refuses unsupported addresses before reading %s", async address => {
    const config = options();
    await expect(protectedMediaPreview(address, config)).rejects.toThrow();
    expect(config.fetch).not.toHaveBeenCalled();
  });
  it.each([
    new Response("failed", { status: 503 }),
    new Response("<script>bad</script>", { headers: { "content-type": "text/html" } }),
    new Response(new Uint8Array(5 * 1024 * 1024 + 1), { headers: { "content-type": "image/png" } }),
  ])("rejects failed responses, active content and oversized streams", async response => {
    const config = options(); config.fetch.mockResolvedValue(response);
    await expect(protectedMediaPreview(source, config)).rejects.toThrow();
    expect(config.createUrl).not.toHaveBeenCalled();
  });
});
