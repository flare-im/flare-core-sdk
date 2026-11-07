/**
 * Host for the core's pre-login global store on the web: the access manifest it last trusted
 * (LKG), the signing key state, and the access point health book. The wasm runtime takes it with
 * `setAccessStoreHost` and adapts it to its `AccessStore` port; every key it hands over already
 * carries the `flare-access/` namespace, so the host stores keys as given.
 *
 * Kept in its own IndexedDB database, apart from the per-user IM data: it is needed before login
 * and must survive a sign-out.
 */

/** One write of an atomic commit. */
export type AccessStoreHostOp =
  | { op: "put"; key: string; value: Uint8Array }
  | { op: "delete"; key: string };

/** The surface `runtime.setAccessStoreHost(host)` reads by name. */
export interface WasmAccessStoreHost {
  get(key: string): Promise<Uint8Array | null>;
  /** Applies every op in one transaction: all or none. */
  commit(ops: AccessStoreHostOp[]): Promise<void>;
  /** Every entry whose key starts with `prefix`, in key order. */
  scan(prefix: string): Promise<Array<[string, Uint8Array]>>;
}

export interface IndexedDbAccessStoreOptions {
  /** IndexedDB factory; defaults to the page's `indexedDB`. Null forces the in-memory store. */
  indexedDB?: IDBFactory | null;
  /** Database name; default `flare-access`. */
  dbName?: string;
  /** Diagnostics sink for the fallback to memory; defaults to `console.warn`. */
  onDiagnostic?: (message: string, error?: unknown) => void;
}

const DEFAULT_DB_NAME = "flare-access";
const DB_VERSION = 1;
const STORE = "entries";
/** Above every BMP code unit: `[prefix, prefix + PREFIX_END)` is exactly the keys under `prefix`. */
const PREFIX_END = "￿";

function copyBytes(value: unknown): Uint8Array | null {
  if (value instanceof Uint8Array) return new Uint8Array(value);
  if (value instanceof ArrayBuffer) return new Uint8Array(value.slice(0));
  if (ArrayBuffer.isView(value)) {
    return new Uint8Array(value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength));
  }
  return null;
}

/** Process-lifetime store: what the core uses when the browser offers no IndexedDB. */
export function createMemoryAccessStoreHost(): WasmAccessStoreHost {
  const entries = new Map<string, Uint8Array>();
  return {
    async get(key) {
      const value = entries.get(key);
      return value ? new Uint8Array(value) : null;
    },
    async commit(ops) {
      for (const op of ops) {
        if (op.op === "put") entries.set(op.key, new Uint8Array(op.value));
        else entries.delete(op.key);
      }
    },
    async scan(prefix) {
      return [...entries.keys()]
        .filter((key) => key.startsWith(prefix))
        .sort()
        .map((key) => [key, new Uint8Array(entries.get(key)!)] as [string, Uint8Array]);
    },
  };
}

function requestResult<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function openDatabase(factory: IDBFactory, name: string): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    let request: IDBOpenDBRequest;
    try {
      request = factory.open(name, DB_VERSION);
    } catch (error) {
      reject(error);
      return;
    }
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE)) {
        request.result.createObjectStore(STORE);
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error(`IndexedDB ${name} is blocked by another tab`));
  });
}

function indexedDbHost(db: IDBDatabase): WasmAccessStoreHost {
  return {
    async get(key) {
      const value = await requestResult(db.transaction(STORE, "readonly").objectStore(STORE).get(key));
      return value === undefined ? null : copyBytes(value);
    },
    commit(ops) {
      if (ops.length === 0) return Promise.resolve();
      return new Promise<void>((resolve, reject) => {
        const tx = db.transaction(STORE, "readwrite");
        const store = tx.objectStore(STORE);
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
        tx.onabort = () => reject(tx.error ?? new Error("access store commit aborted"));
        try {
          for (const op of ops) {
            if (op.op === "put") store.put(new Uint8Array(op.value), op.key);
            else store.delete(op.key);
          }
        } catch (error) {
          tx.abort();
          reject(error);
        }
      });
    },
    scan(prefix) {
      return new Promise((resolve, reject) => {
        const out: Array<[string, Uint8Array]> = [];
        const range = IDBKeyRange.bound(prefix, prefix + PREFIX_END);
        const request = db.transaction(STORE, "readonly").objectStore(STORE).openCursor(range);
        request.onerror = () => reject(request.error);
        request.onsuccess = () => {
          const cursor = request.result;
          if (!cursor) {
            resolve(out);
            return;
          }
          const bytes = copyBytes(cursor.value);
          if (bytes && typeof cursor.key === "string") out.push([cursor.key, bytes]);
          cursor.continue();
        };
      });
    },
  };
}

/**
 * The IndexedDB host, or the in-memory one when IndexedDB is missing or refuses to open (some
 * private modes). The fallback only costs the warm start of the next launch, so it never fails
 * initialization; it reports once through `onDiagnostic`.
 */
export async function createIndexedDbAccessStoreHost(
  options: IndexedDbAccessStoreOptions = {},
): Promise<WasmAccessStoreHost> {
  const diagnostic = options.onDiagnostic
    ?? ((message: string, error?: unknown) => console.warn(`[flare-core] ${message}`, error ?? ""));
  const factory = options.indexedDB === undefined
    ? (globalThis as { indexedDB?: IDBFactory }).indexedDB ?? null
    : options.indexedDB;
  if (!factory) {
    diagnostic("IndexedDB is unavailable; the access store stays in memory for this session");
    return createMemoryAccessStoreHost();
  }
  try {
    return indexedDbHost(await openDatabase(factory, options.dbName ?? DEFAULT_DB_NAME));
  } catch (error) {
    diagnostic("IndexedDB refused the access store; it stays in memory for this session", error);
    return createMemoryAccessStoreHost();
  }
}
