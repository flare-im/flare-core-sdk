import type { UpdateProgress } from "../../model";
import type { UpdateInstallContext } from "../updateInstaller";
import type { UpdateChannel, UpdateChannelMessage } from "../webBundle";
import type { WebUpdateContainer, WebUpdateRegistration, WebUpdateWorker } from "../webUpdateInstaller";

type CacheKey = string | URL | Request;

function keyOf(request: CacheKey): string {
  if (typeof request === "string") return request;
  return request instanceof URL ? request.href : request.url;
}

export class FakeCache {
  readonly entries = new Map<string, Response>();

  async match(request: CacheKey): Promise<Response | undefined> {
    return this.entries.get(keyOf(request))?.clone();
  }

  async put(request: CacheKey, response: Response): Promise<void> {
    this.entries.set(keyOf(request), response.clone());
  }

  async delete(request: CacheKey): Promise<boolean> {
    return this.entries.delete(keyOf(request));
  }
}

export class FakeCacheStorage {
  readonly stores = new Map<string, FakeCache>();

  async open(name: string): Promise<FakeCache> {
    const cache = this.stores.get(name) ?? new FakeCache();
    this.stores.set(name, cache);
    return cache;
  }

  async delete(name: string): Promise<boolean> {
    return this.stores.delete(name);
  }

  async keys(): Promise<string[]> {
    return [...this.stores.keys()];
  }

  asCacheStorage(): CacheStorage {
    return this as unknown as CacheStorage;
  }
}

class FakeChannel implements UpdateChannel {
  private readonly listeners = new Set<(event: { data: unknown }) => void>();

  constructor(private readonly hub: FakeChannelHub) {}

  postMessage(message: UpdateChannelMessage): void {
    this.hub.broadcast(this, message);
  }

  addEventListener(_type: "message", listener: (event: { data: unknown }) => void): void {
    this.listeners.add(listener);
  }

  removeEventListener(_type: "message", listener: (event: { data: unknown }) => void): void {
    this.listeners.delete(listener);
  }

  close(): void {
    this.hub.leave(this);
  }

  deliver(message: UpdateChannelMessage): void {
    for (const listener of [...this.listeners]) listener({ data: message });
  }
}

/** One `BroadcastChannel` name: like the real one, it delivers later and never to the sender. */
export class FakeChannelHub {
  private readonly channels = new Set<FakeChannel>();
  readonly sent: UpdateChannelMessage[] = [];

  readonly open = (): UpdateChannel => {
    const channel = new FakeChannel(this);
    this.channels.add(channel);
    return channel;
  };

  broadcast(from: FakeChannel, message: UpdateChannelMessage): void {
    this.sent.push(message);
    queueMicrotask(() => {
      for (const channel of [...this.channels]) {
        if (channel !== from) channel.deliver(message);
      }
    });
  }

  leave(channel: FakeChannel): void {
    this.channels.delete(channel);
  }
}

export class FakeWorker implements WebUpdateWorker {
  state = "installing";
  readonly messages: unknown[] = [];
  onMessage: ((message: unknown) => void) | null = null;
  private readonly listeners = new Set<() => void>();

  constructor(readonly scriptURL: string) {}

  postMessage(message: unknown): void {
    this.messages.push(message);
    this.onMessage?.(message);
  }

  addEventListener(_type: "statechange", listener: () => void): void {
    this.listeners.add(listener);
  }

  removeEventListener(_type: "statechange", listener: () => void): void {
    this.listeners.delete(listener);
  }

  setState(state: string): void {
    this.state = state;
    for (const listener of [...this.listeners]) listener();
  }
}

export class FakeRegistration implements WebUpdateRegistration {
  installing: FakeWorker | null = null;
  waiting: FakeWorker | null = null;
  active: FakeWorker | null = null;
}

/**
 * Registering a new URL starts an installing worker, which the test then moves on by hand.
 * Registering the newest worker's own URL changes nothing, as in a browser.
 */
export class FakeContainer implements WebUpdateContainer {
  readonly registration = new FakeRegistration();
  readonly registered: Array<{ url: string; options: { scope: string; updateViaCache: "none" } }> = [];
  existing = false;
  failRegister: Error | null = null;
  private readonly listeners = new Set<() => void>();

  async getRegistration(): Promise<WebUpdateRegistration | undefined> {
    return this.existing ? this.registration : undefined;
  }

  async register(url: string, options: { scope: string; updateViaCache: "none" }): Promise<WebUpdateRegistration> {
    this.registered.push({ url, options });
    if (this.failRegister) throw this.failRegister;
    const { installing, waiting, active } = this.registration;
    const newest = installing ?? waiting ?? active;
    if (newest?.scriptURL !== url) this.registration.installing = new FakeWorker(url);
    return this.registration;
  }

  addEventListener(_type: "controllerchange", listener: () => void): void {
    this.listeners.add(listener);
  }

  removeEventListener(_type: "controllerchange", listener: () => void): void {
    this.listeners.delete(listener);
  }

  fireControllerChange(): void {
    for (const listener of [...this.listeners]) listener();
  }

  /** The installing worker passed its checks and now waits. */
  finishInstall(): FakeWorker {
    const worker = this.registration.installing;
    if (!worker) throw new Error("no worker is installing");
    this.registration.installing = null;
    this.registration.waiting = worker;
    worker.setState("installed");
    return worker;
  }

  /** The installing worker gave up. */
  failInstall(): void {
    const worker = this.registration.installing;
    if (!worker) throw new Error("no worker is installing");
    this.registration.installing = null;
    worker.setState("redundant");
  }
}

/** An activity source the test fires by hand. */
export class FakeActivityTarget {
  private readonly listeners = new Map<string, Set<() => void>>();

  addEventListener(type: string, listener: () => void): void {
    const bucket = this.listeners.get(type) ?? new Set();
    bucket.add(listener);
    this.listeners.set(type, bucket);
  }

  removeEventListener(type: string, listener: () => void): void {
    this.listeners.get(type)?.delete(listener);
  }

  fire(type: string): void {
    for (const listener of [...(this.listeners.get(type) ?? [])]) listener();
  }

  count(): number {
    let total = 0;
    for (const bucket of this.listeners.values()) total += bucket.size;
    return total;
  }
}

export class FakeStorage {
  readonly items = new Map<string, string>();

  getItem(key: string): string | null {
    return this.items.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.items.set(key, value);
  }

  removeItem(key: string): void {
    this.items.delete(key);
  }
}

export interface RecordingContext {
  context: UpdateInstallContext;
  progress: Array<UpdateProgress | null>;
  asked(): boolean;
  answer(confirmed: boolean): void;
}

/** An install context that records progress and lets the test answer the confirmation. */
export function recordingContext(): RecordingContext {
  const progress: Array<UpdateProgress | null> = [];
  const pending: Array<(confirmed: boolean) => void> = [];
  return {
    progress,
    asked: () => pending.length > 0,
    answer: (confirmed) => {
      for (const resolve of pending.splice(0)) resolve(confirmed);
    },
    context: {
      waitForConfirmation: () => new Promise((resolve) => pending.push(resolve)),
      setProgress: (value) => void progress.push(value),
    },
  };
}

/** Turns the event loop until `condition` holds. `setImmediate` stays real under the fake timers used here. */
export async function until(condition: () => boolean): Promise<void> {
  for (let turn = 0; turn < 500 && !condition(); turn += 1) {
    await new Promise((resolve) => setImmediate(resolve));
  }
  if (!condition()) throw new Error("the condition never held");
}
