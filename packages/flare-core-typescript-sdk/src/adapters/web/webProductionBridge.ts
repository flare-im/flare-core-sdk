import type { ConnectTokenRefresher, NativeBridge, NativeCallDescriptor } from "../../contract";
import {
  wireDecodeResponse,
  wireEncodeRequest,
} from "../../adapter/codec/wireCodec";
import {
  eventTypeForWebChannel,
  nativeEventFromCode,
} from "../../adapter/module/DefaultEventsApi";
import { FlareSdkException } from "../../bridge/flareSdkException";
import type { FlareWasmRuntime } from "../../bridge/wasmNativeBridge";
import {
  createWasmIndexedDbStorageHost,
  type WasmStorageHostCallbacks,
} from "./idbWasmStorageHost";
import {
  createIndexedDbAccessStoreHost,
  type WasmAccessStoreHost,
} from "./idbAccessStoreHost";
import { webAppInfoFromBuild, withWebAppInfo, type WebAppInfo } from "../../lifecycle/appInfo";

/**
 * Loads the WASM core runtime. Injected by the host because asset resolution is
 * bundler-specific (e.g. Vite `import.meta.env.BASE_URL` + public dir layout), which
 * is an app/bundler concern, not reusable SDK infra.
 */
export type WasmRuntimeLoader = () => Promise<{ runtime: FlareWasmRuntime }>;

/**
 * Builds the storage host backing the WASM core's `setStorageHost` callbacks.
 * Defaults to IndexedDB; desktop hosts (Electron) inject a SQLite-backed host
 * (wa-sqlite + OPFS) so packaged PC apps persist to SQLite instead of IndexedDB.
 */
export type WasmStorageHostFactory = () => WasmStorageHostCallbacks | Promise<WasmStorageHostCallbacks>;

/**
 * Builds the host of the core's pre-login global store (access manifest LKG, key state, health
 * book). Defaults to IndexedDB, falling back to memory where the browser offers none.
 */
export type WasmAccessStoreHostFactory = () => WasmAccessStoreHost | Promise<WasmAccessStoreHost>;

export interface WebProductionBridgeOptions {
  /** Host-injected WASM runtime loader. Required before the first real `invoke`. */
  loadRuntime?: WasmRuntimeLoader;
  /** Host-injected storage backend factory. Defaults to IndexedDB. */
  createStorageHost?: WasmStorageHostFactory;
  /** Host of the pre-login global store. Defaults to IndexedDB (memory where unavailable). */
  createAccessStoreHost?: WasmAccessStoreHostFactory;
  /** App identity for CONNECT; defaults to the build-time injected values. */
  appInfo?: WebAppInfo;
}

type EventEmitter = { emit(event: unknown): void };

type WasmEventEnvelope = {
  channel: string;
  payload: unknown;
};

/** The last `connection://status` phase the bridge saw; best-effort control traffic waits for online. */
type BrowserConnectionPhase = string;

function isBestEffortControlOperation(operation: string): boolean {
  return operation === "message.typing";
}

/**
 * 可延后的后台操作：用户此刻并不在等它的结果，可以让位给交互操作。
 *
 * 这些操作在单线程 WASM 上一跑就是几百毫秒。实测打开一个 2 万条消息的会话，
 * 后台窗口约 2.7 秒，逐项完成时刻是：
 *   +608ms  load_older(96 条)
 *   +990ms  mark_read          ← 单项最大
 *   +446ms  load_older(98 条)
 *   +658ms  history_repair 收尾
 * 用户的发送一旦落进这个窗口，就要排在其中某一项后面。
 *
 * mark_read 属于「浏览的副作用」：用户没有在等它返回，未读数晚几百毫秒更新
 * 不影响任何操作，但它排在发送前面就会实打实地拖慢上屏。
 *
 * 判定要保守：只列**确定**用户不在等的。像 view.timeline.open 就不能算 ——
 * 用户正盯着它出结果。宁可漏掉几个，也不要把交互操作误降级。
 */
function isBackgroundBulkOperation(operation: string): boolean {
  return (
    operation === "view.timeline.load_older"
    || operation === "message.list"
    || operation === "conversation.mark_read"
    || operation.startsWith("sync.")
  );
}

/**
 * 链条等待底层 WASM 调用真正结束时，额外给的宽限期。
 *
 * 外层 `withInvokeTimeout` 只负责回复调用方；`invokeChain` 仍要等底层调用
 * 真正 settle，否则下一次调用会在 wasm32 上重入 Tokio 的 block_on。
 * 但这个等待**不能无上界**——见 `awaitRuntimeSettledBounded`。
 */
const RUNTIME_SETTLE_GRACE_MS = 5_000;

export function invokeTimeoutMs(operation: string): number {
  if (operation === "sdk.login") return 120_000;
  if (operation === "sdk.init") return 30_000;
  if (
    operation === "message.send"
    || operation === "message.send_no_oss"
    // build_and_send 内含本地媒体上传，超时必须与 send 同档，
    // 否则大文件会在默认 12s 就被判超时。
    || operation === "message.build_and_send"
    // 发送前的消息构建（message_builder.*，含 dispatch/create_*）是发送路径的一部分。
    // 单槽被巨型会话的历史回填（view.timeline.load_older）/history_repair/慢 settle 占住时，
    // build 作为交互操作虽插到后台等待者之前，但正在运行的后台重活不被抢占，
    // build 得排在其 settle 之后；12s 默认死线会抢在拿到槽之前把它误判超时
    // （线上 "message_builder.dispatch timed out after 12000ms"）。与发送同档，
    // 让 build 能等出运行中的后台重活而不误报。
    || operation.startsWith("message_builder.")
  ) {
    return 30_000;
  }
  if (operation === "sync.conversation_history_backfill") return 30_000;
  if (operation.startsWith("sync.") || operation === "conversation.open_timeline") return 8_000;
  if (operation === "conversation.update_draft") return 5_000;
  if (operation === "message.typing") return 1_500;
  return 12_000;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function mapWasmEventForTesting(channel: string, payload: unknown): unknown {
  const eventType = eventTypeForWebChannel(channel);
  return eventType === undefined ? wireDecodeResponse(payload) : nativeEventFromCode(eventType, payload);
}

export function encodeWasmRequestForTesting(request: unknown): unknown {
  return wireEncodeRequest(request);
}

export function isBestEffortControlOperationForTesting(operation: string): boolean {
  return isBestEffortControlOperation(operation);
}

type WasmRuntimeWithHost = FlareWasmRuntime & {
  setEventCallback?: (cb: ((event: unknown) => void) | null) => void;
  /** Installs the persistence host; the runtime reads its methods by name and throws when one is missing. */
  setStorageHost?: (host: WasmStorageHostCallbacks) => void;
  /** Installs the pre-login global store host before `sdk.init`. */
  setAccessStoreHost?: (host: WasmAccessStoreHost | null) => Promise<void> | void;
};

/** Browser production bridge: real WASM IMClient + WebSocket transport. */
export class WebProductionBridge implements NativeBridge {
  private runtime: WasmRuntimeWithHost | null = null;
  private runtimeBlocked: FlareSdkException | null = null;
  private eventsApi: EventEmitter | null = null;
  private eventsStarted = false;
  private lastPhase: BrowserConnectionPhase = "idle";
  private bestEffortControlInFlight = new Set<string>();
  /**
   * Serialize WASM invoke — Tokio block_on must not re-enter on wasm32.
   *
   * 串行是硬约束，但**顺序**不必是先来后到。等待队列分两条泳道：后台批量读排在
   * 交互操作后面。原来是一条严格 FIFO 的 promise 链，于是打开会话时的历史回填
   * （一次几百条）会挡在用户的第一次发送前面——实测 Enter→上屏 1253ms，
   * 而链子空闲时同样的发送只要 52ms。
   *
   * 只降级明确属于「后台批量读」的操作，其余保持原有 FIFO 语义，改动面最小。
   * 正在执行的调用永远不被打断，只影响还在排队的。
   */
  private invokeRunning = false;
  private invokeWaiters: Array<{ background: boolean; admit: () => void }> = [];
  private readonly loadRuntime?: WasmRuntimeLoader;
  private readonly createStorageHost: WasmStorageHostFactory;
  private readonly createAccessStoreHost: WasmAccessStoreHostFactory;
  private readonly appInfo: WebAppInfo;

  constructor(options: WebProductionBridgeOptions = {}) {
    this.loadRuntime = options.loadRuntime;
    this.createStorageHost = options.createStorageHost ?? createWasmIndexedDbStorageHost;
    this.createAccessStoreHost = options.createAccessStoreHost ?? (() => createIndexedDbAccessStoreHost());
    this.appInfo = options.appInfo ?? webAppInfoFromBuild();
  }

  attachEventEmitter(api: EventEmitter): void {
    this.eventsApi = api;
  }

  private async ensureRuntime(): Promise<WasmRuntimeWithHost> {
    if (this.runtime) {
      return this.runtime;
    }
    if (!this.loadRuntime) {
      throw new FlareSdkException(
        "wasm.loader_missing",
        "WebProductionBridge requires a WASM runtime loader. Pass { loadRuntime } when constructing it.",
      );
    }
    const loaded = await this.loadRuntime();
    const runtime = loaded.runtime as WasmRuntimeWithHost;
    const host = await this.createStorageHost();
    runtime.setStorageHost?.(host);
    if (runtime.setAccessStoreHost) {
      await runtime.setAccessStoreHost(await this.createAccessStoreHost());
    }
    this.runtime = runtime;
    runtime.setEventCallback?.((raw: unknown) => {
      if (this.runtime === runtime) this.handleWasmEvent(raw);
    });
    return runtime;
  }

  private handleWasmEvent(raw: unknown): void {
    if (!this.eventsApi || typeof raw !== "object" || raw === null) {
      return;
    }
    const envelope = raw as WasmEventEnvelope;
    if (!envelope.channel) {
      return;
    }
    const mapped = mapWasmEventForTesting(envelope.channel, envelope.payload);
    if (mapped === undefined) {
      return;
    }
    this.captureConnectionState(mapped);
    this.eventsApi.emit(mapped);
  }

  private async ensureEventPipeline(): Promise<void> {
    if (this.eventsStarted) {
      return;
    }
    await this.ensureRuntime();
    this.eventsStarted = true;
  }

  private captureConnectionState(event: unknown): void {
    const record = asRecord(event);
    if (record.type === "connection" && record.event === "status" && typeof record.phase === "string") {
      this.lastPhase = record.phase;
    }
  }

  private hasUsableConnection(): boolean {
    return this.lastPhase === "online";
  }

  private async invokeRuntimeOperation<T>(operation: string, request?: unknown): Promise<T> {
    if (this.runtimeBlocked) throw this.runtimeBlocked;
    const runtime = await this.ensureRuntime();
    const encodedRequest = request === undefined || typeof request === "string"
      ? request
      : wireEncodeRequest(request);
    const payload =
      encodedRequest === undefined
        ? "{}"
        : typeof encodedRequest === "string"
          ? encodedRequest
          : JSON.stringify(encodedRequest);
    const result = await runtime.invoke(operation, payload);
    return this.decodeOperationResult<T>(operation, result);
  }

  private async withInvokeTimeout<T>(operation: string, task: Promise<T>): Promise<T> {
    const timeoutMs = invokeTimeoutMs(operation);
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([
        task,
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => {
            reject(new FlareSdkException(
              "wasm.invoke_timeout",
              `WASM operation ${operation} timed out after ${timeoutMs}ms`,
              operation,
              { timeoutMs: String(timeoutMs) },
            ));
          }, timeoutMs);
        }),
      ]);
    } finally {
      if (timer) {
        clearTimeout(timer);
      }
    }
  }

  private async invokeBestEffortControl<T>(operation: string, request?: unknown): Promise<T> {
    if (!this.hasUsableConnection() || this.bestEffortControlInFlight.has(operation)) {
      return undefined as T;
    }
    this.bestEffortControlInFlight.add(operation);
    try {
      return await this.invokeRuntimeOperation<T>(operation, request);
    } catch (error) {
      return undefined as T;
    } finally {
      this.bestEffortControlInFlight.delete(operation);
    }
  }

  private decodeOperationResult<T>(operation: string, result: unknown): T {
    const decoded = wireDecodeResponse(result);
    switch (operation) {
      case "sdk.login":
        // Login returns once the session is up; status events refine it from here on.
        this.lastPhase = "online";
        return decoded as T;
      case "connection.get_status": {
        const phase = asRecord(decoded).phase;
        if (typeof phase === "string") this.lastPhase = phase;
        return decoded as T;
      }
      case "sdk.is_connected":
      case "sdk.session_active":
        return (decoded === true) as T;
      case "sdk.logout":
      case "sdk.dispose":
      case "sdk.hard_reset":
      case "connection.disconnect":
        this.lastPhase = "idle";
        return decoded as T;
      default:
        return decoded as T;
    }
  }

  /** Wait for acknowledged cancellation without replacing the user's session.
   * A timeout cannot prove a write did not commit; never replay the operation.
   * Lifecycle futures cannot be dropped while they own the Rust engine. If they
   * do not settle, fail subsequent requests explicitly until they finish.
   */
  private async awaitRuntimeSettledBounded(
    operation: string,
    settled: Promise<void>,
  ): Promise<void> {
    const wait = async (): Promise<boolean> => {
      let timer: ReturnType<typeof setTimeout> | undefined;
      try {
        return await Promise.race([
          settled.then(() => true),
          new Promise<boolean>((resolve) => {
            timer = setTimeout(() => resolve(false), RUNTIME_SETTLE_GRACE_MS);
          }),
        ]);
      } finally { if (timer) clearTimeout(timer); }
    };
    if (await wait()) return;
    const runtime = this.runtime;
    runtime?.cancelPendingInvocations?.();
    if (await wait()) return;
    const failure = new FlareSdkException(
      "wasm.recovery_pending",
      `WASM operation ${operation} has not acknowledged cancellation; session retained`,
      operation,
    );
    this.runtimeBlocked = failure;
    console.error(failure.message);
    void settled.then(() => {
      if (this.runtime === runtime && this.runtimeBlocked === failure) {
        this.runtimeBlocked = null;
      }
    });
  }

  async invoke<T>(descriptor: NativeCallDescriptor, request?: unknown): Promise<T> {
    const operation = descriptor.operation;
    if (isBestEffortControlOperation(operation)) {
      return this.invokeBestEffortControl<T>(operation, request);
    }
    let runtimeInvokeSettled: Promise<void> = Promise.resolve();
    const run = async (): Promise<T> => {
      try {
        if (this.runtimeBlocked) throw this.runtimeBlocked;
        const runtime = await this.ensureRuntime();
        if (operation === "sdk.create") {
          return { handle: 1 } as T;
        }
        if (operation === "event.subscribe") {
          await this.ensureEventPipeline();
          return { id: 1 } as T;
        }
        if (operation === "event.unsubscribe" || operation === "event.unsubscribe_all") {
          return undefined as T;
        }
        if (operation === "sdk.dispose" || operation === "sdk.hard_reset") {
          await runtime.dispose?.();
          runtime.setEventCallback?.(null);
          this.eventsStarted = false;
          this.runtime = null;
          this.lastPhase = "idle";
          return undefined as T;
        }
        if (operation === "sdk.login") {
          this.lastPhase = "connecting";
        }
        if (operation === "sdk.complete_connect_token_refresh") {
          // The page's refresher is called directly by the runtime; there is no request to answer.
          throw new FlareSdkException(
            "capabilityUnavailable",
            "the web runtime calls the connect token refresher directly",
            operation,
          );
        }
        const runtimeRequest = operation === "sdk.init" ? withWebAppInfo(request, this.appInfo) : request;

        const runtimeInvoke = this.invokeRuntimeOperation<T>(operation, runtimeRequest);
        runtimeInvokeSettled = runtimeInvoke.then(
          () => undefined,
          () => undefined,
        );
        return await this.withInvokeTimeout(operation, runtimeInvoke);
      } catch (error) {
        if (operation === "sdk.login") {
          this.lastPhase = "idle";
        }
        const structured = FlareSdkException.fromBindingError(error, operation);
        if (structured) {
          throw structured;
        }
        throw new FlareSdkException(
          "wasm.invoke_failed",
          error instanceof Error ? error.message : `${error}`,
          operation,
          { transport: "wasm-production" },
        );
      }
    };

    const admitted = this.acquireInvokeSlot(isBackgroundBulkOperation(operation));
    const next = admitted.then(run, run);
    // 调用方拿到的是 run 的结果，不等 settle；但队列槽位要等 settle 之后才释放，
    // 否则下一个调用会在 WASM 还没真正结束时进来（block_on 不可重入）。
    const releaseAfterSettled = async (): Promise<void> => {
      try {
        await this.awaitRuntimeSettledBounded(operation, runtimeInvokeSettled);
      } finally {
        this.releaseInvokeSlot();
      }
    };
    void next.then(releaseAfterSettled, releaseAfterSettled);
    return next;
  }

  /**
   * The page's connect token refresher: after the gateway rejects a connection on authentication
   * the core calls it once and waits at most 20 seconds for the new token (null when none).
   * Runs in the invoke slot like every other runtime call.
   */
  async setConnectTokenRefresher(refresher: ConnectTokenRefresher | null): Promise<void> {
    await this.acquireInvokeSlot(false);
    try {
      if (this.runtimeBlocked) throw this.runtimeBlocked;
      const runtime = await this.ensureRuntime();
      if (!runtime.setConnectTokenRefresher) {
        throw new FlareSdkException(
          "capabilityUnavailable",
          "this wasm runtime has no connect token refresher hook",
          "sdk.set_connect_token_refresher",
        );
      }
      await runtime.setConnectTokenRefresher(refresher ?? undefined);
    } finally {
      this.releaseInvokeSlot();
    }
  }

  /** 取得串行执行权。后台批量读让位给交互操作，同优先级内保持先来后到。 */
  private acquireInvokeSlot(background: boolean): Promise<void> {
    return new Promise<void>((resolve) => {
      const waiter = { background, admit: resolve };
      if (background) {
        this.invokeWaiters.push(waiter);
      } else {
        // 插到所有后台等待者之前，但排在已有的交互等待者之后（保持 FIFO）
        const at = this.invokeWaiters.findIndex((w) => w.background);
        if (at < 0) this.invokeWaiters.push(waiter);
        else this.invokeWaiters.splice(at, 0, waiter);
      }
      this.pumpInvokeQueue();
    });
  }

  private releaseInvokeSlot(): void {
    this.invokeRunning = false;
    this.pumpInvokeQueue();
  }

  private pumpInvokeQueue(): void {
    if (this.invokeRunning) return;
    const next = this.invokeWaiters.shift();
    if (!next) return;
    this.invokeRunning = true;
    next.admit();
  }
}
