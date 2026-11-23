import { flarePluginProtectedMediaSource } from "@flare-im/vue-ui";

/** Keep local private material addresses out of the DOM; the kit accepts an in-memory blob. */
export async function protectedMediaPreview(
  source: string,
  options: {
    origin?: string;
    signal: AbortSignal;
    fetch?: typeof fetch;
    createUrl?: (blob: Blob) => string;
    revokeUrl?: (url: string) => void;
  },
): Promise<{ url: string; release(): void }> {
  if (flarePluginProtectedMediaSource(source)) return { url: source, release() {} };
  const parsed = new URL(source);
  const loopback = (host: string) => ["localhost", "127.0.0.1", "[::1]"].includes(host);
  const origin = options.origin ? new URL(options.origin) : null;
  if (parsed.protocol !== "http:" || !origin || !loopback(origin.hostname) || !loopback(parsed.hostname)
      || parsed.username || parsed.password) throw new Error("PRIVATE_MEDIA_ADDRESS_UNAVAILABLE");
  const response = await (options.fetch ?? fetch)(source, {
    signal: options.signal, cache: "no-store", credentials: "omit", redirect: "error", referrerPolicy: "no-referrer",
  });
  const contentType = response.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase();
  const maxBytes = 5 * 1024 * 1024;
  if (!response.ok || !contentType || !["image/jpeg", "image/png", "image/webp", "application/pdf"].includes(contentType)
      || Number(response.headers.get("content-length")) > maxBytes || !response.body) {
    await response.body?.cancel();
    throw new Error("PRIVATE_MEDIA_READ_UNAVAILABLE");
  }
  const reader = response.body.getReader();
  const chunks: ArrayBuffer[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) throw new Error("PRIVATE_MEDIA_TOO_LARGE");
      const chunk = new ArrayBuffer(value.byteLength);
      new Uint8Array(chunk).set(value);
      chunks.push(chunk);
    }
  } catch (cause) {
    await reader.cancel();
    throw cause;
  } finally {
    reader.releaseLock();
  }
  if (!size) throw new Error("PRIVATE_MEDIA_EMPTY");
  const url = (options.createUrl ?? URL.createObjectURL)(new Blob(chunks, { type: contentType }));
  let released = false;
  return { url, release() {
    if (!released) (options.revokeUrl ?? URL.revokeObjectURL)(url);
    released = true;
  } };
}
