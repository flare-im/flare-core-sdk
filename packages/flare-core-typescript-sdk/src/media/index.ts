import type { MediaApi } from "../api/modules/media";
import type { MessageBuilderApi } from "../api/modules/message_builder";
import type { MediaUploadResponse } from "../api/types";
import type { Message } from "../model";
import { WebMediaApi } from "../adapters/web/media/WebMediaApi";

export type MediaUploadOptions = Record<string, unknown> | null;

export interface MediaUploadFileLike {
  readonly name?: string;
  readonly type?: string;
  readonly size: number;
  arrayBuffer(): Promise<ArrayBuffer>;
}

export type MediaUploadInput =
  | {
      source: "file";
      file: MediaUploadFileLike;
      kind: string;
      fileName?: string;
      mimeType?: string;
      options?: MediaUploadOptions;
    }
  | {
      source: "path";
      path: string;
      kind: string;
      fileName?: string;
      mimeType?: string;
      options?: MediaUploadOptions;
    }
  | {
      source: "bytes";
      bytes: ArrayBuffer | ArrayBufferView | readonly number[];
      kind: string;
      fileName: string;
      mimeType: string;
      options?: MediaUploadOptions;
    };

export type MediaUploadApi = Pick<MediaApi, "uploadBytes" | "uploadFile">;

function requireNonEmpty(value: string | undefined, field: string): string {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) {
    throw new Error(`${field} is required`);
  }
  return trimmed;
}

function bytesToJsonArray(bytes: ArrayBuffer | ArrayBufferView | readonly number[]): number[] {
  if (Array.isArray(bytes)) {
    return bytes.map((byte) => byte & 0xff);
  }
  if (ArrayBuffer.isView(bytes)) {
    return Array.from(new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength));
  }
  return Array.from(new Uint8Array(bytes));
}

function mimeTypeOrDefault(value: string | undefined): string {
  return String(value ?? "").trim() || "application/octet-stream";
}

export async function uploadMediaInput(
  media: MediaUploadApi,
  input: MediaUploadInput,
): Promise<MediaUploadResponse> {
  const kind = requireNonEmpty(input.kind, "kind");
  if (input.source === "path") {
    return await media.uploadFile({
      path: requireNonEmpty(input.path, "path"),
      kind,
      fileName: input.fileName,
      mimeType: input.mimeType,
      options: input.options ?? null,
    });
  }

  if (input.source === "file") {
    if (!input.file.size) {
      throw new Error("media file is empty");
    }
    const fileName = requireNonEmpty(input.fileName ?? input.file.name, "fileName");
    const mimeType = mimeTypeOrDefault(input.mimeType ?? input.file.type);
    return await media.uploadBytes({
      bytes: bytesToJsonArray(await input.file.arrayBuffer()),
      fileName,
      mimeType,
      kind,
      options: input.options ?? null,
    });
  }

  const fileName = requireNonEmpty(input.fileName, "fileName");
  const mimeType = mimeTypeOrDefault(input.mimeType);
  const bytes = bytesToJsonArray(input.bytes);
  if (bytes.length === 0) {
    throw new Error("media bytes are empty");
  }
  return await media.uploadBytes({
    bytes,
    fileName,
    mimeType,
    kind,
    options: input.options ?? null,
  });
}

/** The media message a local file goes out as. */
export type LocalMediaKind = "image" | "video" | "audio" | "file";

/** By MIME type: pictures, videos and sound as themselves, anything else as a file. */
export function mediaKindForMime(mimeType: string | undefined): LocalMediaKind {
  const type = String(mimeType ?? "").trim().toLowerCase();
  if (type.startsWith("image/")) return "image";
  if (type.startsWith("video/")) return "video";
  if (type.startsWith("audio/")) return "audio";
  return "file";
}

/**
 * A local file as a source the core sends from:
 * `data:<mime>;name=<encoded name>;size=<bytes>;base64,<bytes>`.
 *
 * Put it where a media message takes its uploaded id (`imageId`, `videoId`, `audioId`, `fileId`, an album's
 * `imageId`s) and `message.send` does the rest: the message is in the timeline at once with the file's name and size,
 * `localState.uploadProgress` rises while the core uploads, and the same message goes out when the upload is done — or
 * turns failed, and resendable, when it is not. Native hosts need no encoding: a file path works the same way.
 */
export async function localMediaSource(file: MediaUploadFileLike): Promise<string> {
  const mimeType = mimeTypeOrDefault(file.type);
  const name = encodeURIComponent(String(file.name ?? ""));
  return `data:${mimeType};name=${name};size=${file.size};base64,${await base64Of(file)}`;
}

async function base64Of(file: MediaUploadFileLike): Promise<string> {
  // The browser encodes natively; building the string in script is the fallback for runtimes without FileReader.
  if (typeof FileReader !== "undefined" && typeof Blob !== "undefined" && file instanceof Blob) {
    const blob: Blob = file;
    const dataUrl = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result ?? ""));
      reader.onerror = () => reject(reader.error ?? new Error("could not read the file"));
      reader.readAsDataURL(blob);
    });
    return dataUrl.slice(dataUrl.indexOf(",") + 1);
  }
  const bytes = new Uint8Array(await file.arrayBuffer());
  let binary = "";
  for (let start = 0; start < bytes.length; start += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(start, start + 0x8000));
  }
  return btoa(binary);
}

export type LocalMediaMessageBuilder = Pick<
  MessageBuilderApi,
  "buildImage" | "buildVideo" | "buildAudio" | "buildFile" | "buildImageGroup"
>;

/** A media message built straight from a local file (see {@link localMediaSource}); send it with `message.send`. */
export async function buildLocalMediaMessage(
  builder: LocalMediaMessageBuilder,
  conversationId: string,
  file: MediaUploadFileLike,
  kind: LocalMediaKind = mediaKindForMime(file.type),
): Promise<Message> {
  const source = await localMediaSource(file);
  switch (kind) {
    case "image":
      return await builder.buildImage({ conversationId, imageId: source });
    case "video":
      return await builder.buildVideo({ conversationId, videoId: source });
    case "audio":
      return await builder.buildAudio({ conversationId, audioId: source });
    default:
      return await builder.buildFile({ conversationId, fileId: source });
  }
}

/** An album built straight from local pictures, in the order they are shown; sent like {@link buildLocalMediaMessage}. */
export async function buildLocalImageGroupMessage(
  builder: LocalMediaMessageBuilder,
  conversationId: string,
  files: readonly MediaUploadFileLike[],
): Promise<Message> {
  const sources = await Promise.all(files.map((file) => localMediaSource(file)));
  return await builder.buildImageGroup({
    conversationId,
    payload: { images: sources.map((imageId) => ({ imageId })) },
  });
}

export { WebMediaApi, type WebDownloadProgress } from "../adapters/web/media/WebMediaApi";
export { supportsDownloadDirectoryPicker } from "../adapters/web/media/browserDownload";

/** The core op call a web app already has (a social SDK bridge, a worker): `op` like `media.resolve_access`. */
export type CoreMediaInvoke = (op: string, params: Record<string, unknown>) => Promise<unknown>;

/**
 * Browser "save to device" and display caching for a web app that reaches the core through its own
 * bridge: saves go to the folder the user picked (File System Access API) or the browser's download
 * flow, and pictures shown with `resolveDisplayUrl({ fileId, autoCache: true })` are kept in Cache
 * Storage. A timeline's `messageId` is resolved through the core's local message view so recipients
 * supply the same authorization reference for previews and downloads as native clients.
 */
export function browserMediaFor(invoke: CoreMediaInvoke): WebMediaApi {
  async function withMessageReference(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    if (request.conversationId !== undefined || request.messageSeq !== undefined || !request.messageId) return request;
    const message = await invoke("message.get", { messageId: request.messageId }) as Partial<Message> | null;
    const conversationId = message?.conversationId;
    const messageSeq = message?.conversationSeq;
    if (typeof conversationId !== "string" || !conversationId || typeof messageSeq !== "number" || !Number.isSafeInteger(messageSeq) || messageSeq <= 0) return request;
    return { ...request, conversationId, messageSeq };
  }
  const inner = {
    // get_url accepts message authorization; temp_download_url only authorizes the uploader.
    getTempDownloadUrl: async (request: Record<string, unknown>) => invoke("media.get_url", await withMessageReference(request)),
    resolveMediaAccess: async (request: Record<string, unknown>) => invoke("media.resolve_access", await withMessageReference(request)),
  };
  return WebMediaApi.fromInner(inner as unknown as MediaApi);
}
