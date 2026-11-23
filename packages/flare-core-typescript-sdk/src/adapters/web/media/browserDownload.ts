/**
 * Browser "save to device": the user's chosen folder (File System Access API, where the browser
 * has it) or the browser's own download flow.
 *
 * A folder the user picked is remembered as a directory handle in IndexedDB. Writing to it needs
 * the user's permission again in a later session; when the browser does not grant it, the file
 * goes through the browser's download flow instead and the result says so (`savedVia`).
 */

const DB_NAME = 'flare-im-media';
const STORE = 'settings';
const DIRECTORY_KEY = 'downloadDirectory';

/** Minimal File System Access API surface (not in every TS DOM lib yet). */
interface WritableFileStream {
  write(data: Blob): Promise<void>;
  close(): Promise<void>;
  abort?(): Promise<void>;
}
interface FileHandleLike {
  createWritable(): Promise<WritableFileStream>;
}
export interface DirectoryHandleLike {
  readonly kind: 'directory';
  readonly name: string;
  getFileHandle(name: string, options?: { create?: boolean }): Promise<FileHandleLike>;
  queryPermission?(descriptor: { mode: 'read' | 'readwrite' }): Promise<PermissionState>;
  requestPermission?(descriptor: { mode: 'read' | 'readwrite' }): Promise<PermissionState>;
}
type ShowDirectoryPicker = (options?: {
  id?: string;
  mode?: 'read' | 'readwrite';
  startIn?: string;
}) => Promise<DirectoryHandleLike>;

function directoryPicker(): ShowDirectoryPicker | undefined {
  const picker = (globalThis as { showDirectoryPicker?: ShowDirectoryPicker }).showDirectoryPicker;
  return typeof picker === 'function' ? picker : undefined;
}

/** Whether this browser lets the user pick a download folder. */
export function supportsDownloadDirectoryPicker(): boolean {
  return directoryPicker() !== undefined && typeof indexedDB !== 'undefined';
}

function openSettingsDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE)) {
        request.result.createObjectStore(STORE);
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error('indexedDB open failed'));
  });
}

async function settingsTx<T>(
  mode: IDBTransactionMode,
  run: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T> {
  const db = await openSettingsDb();
  try {
    return await new Promise<T>((resolve, reject) => {
      const tx = db.transaction(STORE, mode);
      const request = run(tx.objectStore(STORE));
      tx.oncomplete = () => resolve(request.result);
      tx.onerror = () => reject(tx.error ?? new Error('indexedDB transaction failed'));
      tx.onabort = () => reject(tx.error ?? new Error('indexedDB transaction aborted'));
    });
  } finally {
    db.close();
  }
}

/** The folder the user picked earlier, if any. */
export async function storedDownloadDirectory(): Promise<DirectoryHandleLike | undefined> {
  if (typeof indexedDB === 'undefined') return undefined;
  try {
    const handle = await settingsTx('readonly', (store) => store.get(DIRECTORY_KEY));
    return handle && (handle as DirectoryHandleLike).kind === 'directory'
      ? (handle as DirectoryHandleLike)
      : undefined;
  } catch {
    return undefined;
  }
}

/** Asks the user for a folder. Must run inside a user gesture (a click). */
export async function pickDownloadDirectory(): Promise<DirectoryHandleLike> {
  const picker = directoryPicker();
  if (!picker) {
    throw new Error('this browser cannot pick a download folder');
  }
  const handle = await picker({ id: 'flare-downloads', mode: 'readwrite', startIn: 'downloads' });
  await settingsTx('readwrite', (store) => store.put(handle, DIRECTORY_KEY));
  return handle;
}

/** A file saved into the picked folder, remembered by its download key. */
export interface SavedDownloadRecord {
  directory: string;
  fileName: string;
}

const savedDownloadKey = (downloadKey: string) => `download:${downloadKey}`;

/** Remembers that [downloadKey] was saved as [record] in the picked folder. */
export async function recordSavedDownload(downloadKey: string, record: SavedDownloadRecord): Promise<void> {
  if (typeof indexedDB === 'undefined' || !downloadKey) return;
  await settingsTx('readwrite', (store) => store.put({ ...record }, savedDownloadKey(downloadKey)));
}

export async function savedDownloadRecord(downloadKey: string): Promise<SavedDownloadRecord | undefined> {
  if (typeof indexedDB === 'undefined' || !downloadKey) return undefined;
  try {
    const value = (await settingsTx('readonly', (store) => store.get(savedDownloadKey(downloadKey)))) as
      | Partial<SavedDownloadRecord>
      | undefined;
    return value && typeof value.fileName === 'string' && value.fileName
      ? { directory: String(value.directory ?? ''), fileName: value.fileName }
      : undefined;
  } catch {
    return undefined;
  }
}

export async function forgetSavedDownload(downloadKey: string): Promise<void> {
  if (typeof indexedDB === 'undefined' || !downloadKey) return;
  await settingsTx('readwrite', (store) => store.delete(savedDownloadKey(downloadKey))).catch(() => undefined);
}

/**
 * Whether [record] is still in the picked folder: `present`, `missing`, or `unknown` when the browser will not let
 * this page look (no folder, another folder picked since, or no read permission — [interactive] asks for it, which
 * needs a user gesture).
 */
export async function savedDownloadPresence(
  record: SavedDownloadRecord,
  interactive: boolean,
): Promise<'present' | 'missing' | 'unknown'> {
  const dir = await storedDownloadDirectory();
  if (!dir || dir.name !== record.directory) return 'unknown';
  try {
    const descriptor = { mode: 'read' as const };
    let state = await dir.queryPermission?.(descriptor);
    if (state !== 'granted' && interactive) state = await dir.requestPermission?.(descriptor);
    if (state !== 'granted') return 'unknown';
  } catch {
    return 'unknown';
  }
  return (await fileExists(dir, record.fileName)) ? 'present' : 'missing';
}

export async function forgetDownloadDirectory(): Promise<void> {
  if (typeof indexedDB === 'undefined') return;
  await settingsTx('readwrite', (store) => store.delete(DIRECTORY_KEY));
}

/** Write access to [handle]: granted already, or asked for (needs a user gesture), else none. */
async function ensureWritable(handle: DirectoryHandleLike): Promise<boolean> {
  try {
    const descriptor = { mode: 'readwrite' as const };
    if ((await handle.queryPermission?.(descriptor)) === 'granted') return true;
    return (await handle.requestPermission?.(descriptor)) === 'granted';
  } catch {
    return false;
  }
}

function splitName(fileName: string): [string, string] {
  const dot = fileName.lastIndexOf('.');
  return dot > 0 ? [fileName.slice(0, dot), fileName.slice(dot)] : [fileName, ''];
}

async function fileExists(dir: DirectoryHandleLike, name: string): Promise<boolean> {
  try {
    await dir.getFileHandle(name);
    return true;
  } catch {
    return false;
  }
}

/** `name.ext`, else `name (1).ext`, `name (2).ext`, … — the same naming the native core uses. */
export async function uniqueDownloadName(dir: DirectoryHandleLike, fileName: string): Promise<string> {
  if (!(await fileExists(dir, fileName))) return fileName;
  const [stem, ext] = splitName(fileName);
  for (let i = 1; i < 10_000; i += 1) {
    const candidate = `${stem} (${i})${ext}`;
    if (!(await fileExists(dir, candidate))) return candidate;
  }
  return `${stem}_${Date.now()}${ext}`;
}

const EXTENSION_FOR_MIME: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/gif": "gif",
  "image/webp": "webp",
  "image/heic": "heic",
  "image/bmp": "bmp",
  "image/svg+xml": "svg",
  "video/mp4": "mp4",
  "video/quicktime": "mov",
  "video/webm": "webm",
  "audio/mpeg": "mp3",
  "audio/mp4": "m4a",
  "audio/aac": "aac",
  "audio/ogg": "ogg",
  "audio/wav": "wav",
  "application/pdf": "pdf",
  "application/zip": "zip",
  "text/plain": "txt",
};

/**
 * [fileName] with an extension from [mimeType] when it has none — pictures and videos usually
 * carry no file name, and a saved file without an extension does not open. Same rule as the core.
 */
export function withExtensionFor(fileName: string, mimeType: string): string {
  if (/\.[A-Za-z0-9]{1,8}$/.test(fileName)) return fileName;
  const ext = EXTENSION_FOR_MIME[mimeType.split(";")[0]?.trim().toLowerCase() ?? ""];
  return ext ? `${fileName}.${ext}` : fileName;
}

/** Characters no file system accepts, and path separators, become `_`. */
export function sanitizeDownloadFileName(raw: string): string {
  const base = raw.trim().split(/[\\/]/).filter(Boolean).pop() ?? '';
  const cleaned = Array.from(base)
    .map((ch) => (ch.charCodeAt(0) < 0x20 || '?%*:|"<>'.includes(ch) ? '_' : ch))
    .join('')
    .slice(0, 200)
    .replace(/^[ .]+|[ .]+$/g, '');
  return cleaned || 'download';
}

export interface SavedToFolder {
  directory: string;
  fileName: string;
}

/** Writes [blob] into the picked folder; `undefined` when there is no folder or no permission. */
export async function saveBlobToPickedDirectory(
  blob: Blob,
  fileName: string,
): Promise<SavedToFolder | undefined> {
  const dir = await storedDownloadDirectory();
  if (!dir || !(await ensureWritable(dir))) return undefined;
  const name = await uniqueDownloadName(dir, sanitizeDownloadFileName(fileName));
  const file = await dir.getFileHandle(name, { create: true });
  const writable = await file.createWritable();
  try {
    await writable.write(blob);
    await writable.close();
  } catch (error) {
    await writable.abort?.().catch(() => undefined);
    throw error;
  }
  return { directory: dir.name, fileName: name };
}

/** Hands [blob] (or a URL) to the browser's download flow under [fileName]. */
export function saveThroughBrowser(source: Blob | string, fileName: string): void {
  if (typeof document === 'undefined') {
    throw new Error('no document to start a browser download');
  }
  const href = typeof source === 'string' ? source : URL.createObjectURL(source);
  const anchor = document.createElement('a');
  anchor.href = href;
  anchor.download = sanitizeDownloadFileName(fileName);
  anchor.rel = 'noopener';
  anchor.style.display = 'none';
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  if (typeof source !== 'string') {
    // The browser reads the blob asynchronously after the click.
    setTimeout(() => URL.revokeObjectURL(href), 60_000);
  }
}

/** Fetches [url] as a blob, reporting progress and honouring [signal]. */
export async function fetchBlob(
  url: string,
  signal: AbortSignal,
  onProgress?: (downloaded: number, total: number | undefined) => void,
): Promise<Blob> {
  const response = await fetch(url, { mode: 'cors', credentials: 'omit', signal });
  if (!response.ok) {
    throw new Error(`download failed: HTTP ${response.status}`);
  }
  const lengthHeader = Number(response.headers.get('content-length'));
  const total = Number.isFinite(lengthHeader) && lengthHeader > 0 ? lengthHeader : undefined;
  const type = response.headers.get('content-type') ?? '';
  const limit = 128 * 1024 ** 2;
  if (total !== undefined && total > limit) {
    await response.body?.cancel().catch(() => undefined);
    throw new RangeError('attachment exceeds the browser buffer limit');
  }
  if (!response.body) {
    const blob = await response.blob();
    onProgress?.(blob.size, total ?? blob.size);
    return blob;
  }
  const reader = response.body.getReader();
  const chunks: BlobPart[] = [];
  let downloaded = 0;
  try {
    onProgress?.(0, total);
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      downloaded += value.byteLength;
      if (downloaded > limit) throw new RangeError('attachment exceeds the browser buffer limit');
      chunks.push(value);
      onProgress?.(downloaded, total);
    }
    return new Blob(chunks, { type });
  } catch (error) {
    await reader.cancel().catch(() => undefined);
    throw error;
  } finally {
    reader.releaseLock();
  }
}
