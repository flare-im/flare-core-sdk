import { describe, expect, it, vi } from "vitest";

import { installFlareServiceWorker, type FlareServiceWorkerScope } from "./service-worker";
import { FakeCacheStorage, FakeChannelHub } from "./testing/fakes";
import {
  FLARE_UPDATE_STATE_CACHE,
  INSTALL_FAILURE_KEY,
  WEB_ASSET_MANIFEST_SCHEMA,
  WORKER_SKIP_WAITING,
  sha256Hex,
  shellCacheName,
  workerScriptUrl,
  type WebAsset,
  type WebBundleInstallFailure,
} from "./webBundle";

const ORIGIN = "https://chat.example";
const INDEX = "<!doctype html><title>b2</title>";
const APP = "console.log('b2')";
const LAZY = "console.log('lazy')";

const bytes = (text: string): ArrayBuffer => new TextEncoder().encode(text).buffer as ArrayBuffer;
const hash = (text: string): Promise<string> => sha256Hex(bytes(text));

type Listener = (event: never) => void;

/** A worker global scope serving `files` as its network. */
class FakeScope {
  readonly location: { href: string; origin: string };
  readonly storage = new FakeCacheStorage();
  readonly caches = this.storage.asCacheStorage();
  readonly registration: { active: { scriptURL: string } | null } = { active: null };
  readonly clients = { claim: vi.fn(async () => undefined) };
  readonly skipWaiting = vi.fn(async () => undefined);
  readonly files = new Map<string, string>();
  readonly fetched: string[] = [];
  private readonly listeners = new Map<string, Listener>();

  constructor(scriptUrl: string) {
    this.location = { href: new URL(scriptUrl, ORIGIN).href, origin: ORIGIN };
  }

  async fetch(input: string | Request): Promise<Response> {
    const url = typeof input === "string" ? input : input.url;
    this.fetched.push(url);
    const body = this.files.get(url);
    if (body === undefined) return new Response(null, { status: 404 });
    return new Response(body, { headers: { "content-type": "text/plain" } });
  }

  addEventListener(type: string, listener: Listener): void {
    this.listeners.set(type, listener);
  }

  asScope(): FlareServiceWorkerScope {
    return this as unknown as FlareServiceWorkerScope;
  }

  async lifecycle(type: "install" | "activate"): Promise<void> {
    let work: Promise<unknown> = Promise.resolve();
    (this.listeners.get(type) as (event: unknown) => void)({
      waitUntil: (promise: Promise<unknown>) => {
        work = promise;
      },
    });
    await work;
  }

  message(data: unknown): Promise<unknown> {
    let work: Promise<unknown> = Promise.resolve();
    (this.listeners.get("message") as (event: unknown) => void)({
      data,
      waitUntil: (promise: Promise<unknown>) => {
        work = promise;
      },
    });
    return work;
  }

  /** The worker's answer, or undefined when it let the request go to the network itself. */
  request(url: string, init: { mode?: string; method?: string; headers?: HeadersInit } = {}): Promise<Response> | undefined {
    let answer: Promise<Response> | undefined;
    (this.listeners.get("fetch") as (event: unknown) => void)({
      request: { url, mode: init.mode ?? "cors", method: init.method ?? "GET", headers: new Headers(init.headers) },
      respondWith: (response: Promise<Response>) => {
        answer = response;
      },
    });
    return answer;
  }

  failure(): Promise<WebBundleInstallFailure | undefined> {
    return this.storage.open(FLARE_UPDATE_STATE_CACHE)
      .then((cache) => cache.match(INSTALL_FAILURE_KEY))
      .then((response) => response?.json() as Promise<WebBundleInstallFailure> | undefined);
  }
}

async function asset(url: string, content: string, extra: Partial<WebAsset> = {}): Promise<WebAsset> {
  return { url, sha256: await hash(content), size: content.length, ...extra };
}

async function deployment(buildId = "b2", overrides: { assets?: WebAsset[]; manifestUrls?: string[] } = {}) {
  const assets = overrides.assets ?? [
    await asset("/index.html", INDEX, { precache: true }),
    await asset("/assets/app-1a2b.js", APP, { precache: true }),
    await asset("/assets/lazy-3c4d.js", LAZY),
  ];
  const manifest = JSON.stringify({ schema: WEB_ASSET_MANIFEST_SCHEMA, buildId, assets });
  const manifestUrls = overrides.manifestUrls ?? [`${ORIGIN}/builds/${buildId}/asset-manifest.json`];
  const scope = new FakeScope(workerScriptUrl("/sw.js", { buildId, manifestUrls, manifestSha256: await hash(manifest) }));
  scope.files.set(manifestUrls[manifestUrls.length - 1]!, manifest);
  scope.files.set(`${ORIGIN}/index.html`, INDEX);
  scope.files.set(`${ORIGIN}/assets/app-1a2b.js`, APP);
  scope.files.set(`${ORIGIN}/assets/lazy-3c4d.js`, LAZY);
  return { scope, manifest, manifestUrls };
}

function start(scope: FakeScope, hub = new FakeChannelHub(), bypass?: RegExp[]) {
  installFlareServiceWorker({ scope: scope.asScope(), createChannel: hub.open, ...(bypass ? { bypass } : {}) });
  return hub;
}

describe("Service Worker install", () => {
  it("refuses a script URL that names no build", () => {
    const scope = new FakeScope("/sw.js");

    expect(() => installFlareServiceWorker({ scope: scope.asScope() })).toThrow();
  });

  it("verifies the manifest and precaches the shell under this build", async () => {
    const { scope } = await deployment();
    start(scope);

    await scope.lifecycle("install");

    const cache = await scope.storage.open(shellCacheName("b2"));
    expect(await (await cache.match(`${ORIGIN}/index.html`))?.text()).toBe(INDEX);
    expect(await (await cache.match(`${ORIGIN}/assets/app-1a2b.js`))?.text()).toBe(APP);
    expect(await cache.match(`${ORIGIN}/assets/lazy-3c4d.js`)).toBeUndefined();
  });

  it("keeps the response's content type in the cache", async () => {
    const { scope } = await deployment();
    start(scope);

    await scope.lifecycle("install");

    const cache = await scope.storage.open(shellCacheName("b2"));
    expect((await cache.match(`${ORIGIN}/index.html`))?.headers.get("content-type")).toContain("text/plain");
  });

  it("reports progress by bytes of shell", async () => {
    const { scope } = await deployment();
    const hub = start(scope);

    await scope.lifecycle("install");

    expect(hub.sent).toEqual([
      { type: "installProgress", buildId: "b2", received: INDEX.length, total: INDEX.length + APP.length },
      { type: "installProgress", buildId: "b2", received: INDEX.length + APP.length, total: INDEX.length + APP.length },
    ]);
  });

  it("abandons the install when an asset does not match, and leaves no cache behind", async () => {
    const { scope } = await deployment();
    scope.files.set(`${ORIGIN}/assets/app-1a2b.js`, "console.log('tampered')");
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect(await scope.failure()).toEqual({ buildId: "b2", code: "update.hashMismatch", url: "/assets/app-1a2b.js" });
    expect(await scope.storage.keys()).not.toContain(shellCacheName("b2"));
  });

  it("abandons the install when the manifest does not match the signed hash", async () => {
    const { scope, manifestUrls } = await deployment();
    scope.files.set(manifestUrls[0]!, '{"schema":"flare.web-assets.v1","buildId":"b2","assets":[]}');
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect(await scope.failure()).toMatchObject({ buildId: "b2", code: "update.hashMismatch" });
    expect(scope.fetched).toEqual(manifestUrls);
  });

  it("moves past a bad or dead mirror to the next manifest address", async () => {
    const urls = [`${ORIGIN}/dead.json`, `${ORIGIN}/tampered.json`, `${ORIGIN}/good.json`];
    const { scope } = await deployment("b2", { manifestUrls: urls });
    scope.files.set(urls[1]!, "{}");
    start(scope);

    await scope.lifecycle("install");

    expect(scope.fetched.slice(0, 3)).toEqual(urls);
    expect(await scope.failure()).toBeUndefined();
  });

  it("reports a failed download when no manifest address answers", async () => {
    const { scope, manifestUrls } = await deployment();
    scope.files.delete(manifestUrls[0]!);
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect((await scope.failure())?.code).toBe("update.downloadFailed");
  });

  it("reports a missing asset as a failed download", async () => {
    const { scope } = await deployment();
    scope.files.delete(`${ORIGIN}/index.html`);
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect(await scope.failure()).toEqual({ buildId: "b2", code: "update.downloadFailed", url: "/index.html" });
  });

  it("refuses a manifest of another build", async () => {
    const assets = [await asset("/index.html", INDEX, { precache: true })];
    const manifest = JSON.stringify({ schema: WEB_ASSET_MANIFEST_SCHEMA, buildId: "other", assets });
    const url = `${ORIGIN}/asset-manifest.json`;
    const scope = new FakeScope(workerScriptUrl("/sw.js", {
      buildId: "b2",
      manifestUrls: [url],
      manifestSha256: await hash(manifest),
    }));
    scope.files.set(url, manifest);
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect((await scope.failure())?.code).toBe("update.installFailed");
  });

  it("refuses assets on another origin, which it could not serve", async () => {
    const { scope } = await deployment("b2", {
      assets: [await asset("https://cdn.example/app.js", APP, { precache: true })],
    });
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect((await scope.failure())?.code).toBe("update.installFailed");
  });

  it("reports a full disk as such", async () => {
    const { scope } = await deployment();
    const cache = await scope.storage.open(shellCacheName("b2"));
    cache.put = async () => {
      throw Object.assign(new Error("quota"), { name: "QuotaExceededError" });
    };
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect((await scope.failure())?.code).toBe("update.insufficientSpace");
  });

  it("keeps the live cache when a new script of the same build fails", async () => {
    const { scope } = await deployment();
    scope.registration.active = { scriptURL: scope.location.href };
    const cache = await scope.storage.open(shellCacheName("b2"));
    await cache.put(`${ORIGIN}/index.html`, new Response(INDEX));
    scope.files.delete(`${ORIGIN}/assets/app-1a2b.js`);
    start(scope);

    await expect(scope.lifecycle("install")).rejects.toThrow();

    expect(await scope.storage.keys()).toContain(shellCacheName("b2"));
  });

  it("fetches a file from its per-build source and caches it under the URL the page asks for", async () => {
    const oldIndex = "<!doctype html><title>b1</title>";
    const source = "/builds/b1/index.html";
    const { scope } = await deployment("b1", {
      assets: [await asset("/index.html", oldIndex, { precache: true, source })],
    });
    scope.files.set(`${ORIGIN}${source}`, oldIndex);
    start(scope);

    await scope.lifecycle("install");

    const cache = await scope.storage.open(shellCacheName("b1"));
    expect(await (await cache.match(`${ORIGIN}/index.html`))?.text()).toBe(oldIndex);
    expect(scope.fetched).toContain(`${ORIGIN}${source}`);
    expect(scope.fetched).not.toContain(`${ORIGIN}/index.html`);
  });
});

describe("Service Worker activate", () => {
  it("drops other builds' shells and the failure record, and takes over open pages", async () => {
    const { scope } = await deployment();
    await scope.storage.open(shellCacheName("b1"));
    await scope.storage.open("flare-im-media-v1");
    await scope.storage.open(FLARE_UPDATE_STATE_CACHE);
    start(scope);

    await scope.lifecycle("install");
    await scope.lifecycle("activate");

    expect((await scope.storage.keys()).sort()).toEqual([shellCacheName("b2"), "flare-im-media-v1"].sort());
    expect(scope.clients.claim).toHaveBeenCalledTimes(1);
  });

  it("rolls back through the same steps: the older build ends up the only shell", async () => {
    const { scope } = await deployment("b1");
    await scope.storage.open(shellCacheName("b2"));
    start(scope);

    await scope.lifecycle("install");
    await scope.lifecycle("activate");

    expect(await scope.storage.keys()).toEqual([shellCacheName("b1")]);
  });
});

describe("Service Worker messages", () => {
  it("skips waiting only when told to", async () => {
    const { scope } = await deployment();
    start(scope);

    await scope.message({ type: "something-else" });
    await scope.message(null);
    expect(scope.skipWaiting).not.toHaveBeenCalled();

    await scope.message({ type: WORKER_SKIP_WAITING });
    expect(scope.skipWaiting).toHaveBeenCalledTimes(1);
  });
});

describe("Service Worker fetch", () => {
  async function installed(bypass?: RegExp[]) {
    const { scope } = await deployment();
    start(scope, undefined, bypass);
    await scope.lifecycle("install");
    await scope.lifecycle("activate");
    scope.fetched.length = 0;
    return scope;
  }

  it("answers navigations from the shell, even with the site down", async () => {
    const scope = await installed();
    scope.files.clear();

    const response = await scope.request(`${ORIGIN}/chat/42?tab=files`, { mode: "navigate" });

    expect(await response?.text()).toBe(INDEX);
    expect(scope.fetched).toEqual([]);
  });

  it("does not let a newer index.html on the site reach a page of this build", async () => {
    const scope = await installed();
    scope.files.set(`${ORIGIN}/index.html`, "<!doctype html><title>b3</title>");

    const response = await scope.request(`${ORIGIN}/`, { mode: "navigate" });

    expect(await response?.text()).toBe(INDEX);
  });

  it("serves precached assets from the cache", async () => {
    const scope = await installed();

    const response = await scope.request(`${ORIGIN}/assets/app-1a2b.js`);

    expect(await response?.text()).toBe(APP);
    expect(scope.fetched).toEqual([]);
  });

  it("verifies a lazy asset on first use, then serves it from the cache", async () => {
    const scope = await installed();

    expect(await (await scope.request(`${ORIGIN}/assets/lazy-3c4d.js`))?.text()).toBe(LAZY);
    expect(scope.fetched).toEqual([`${ORIGIN}/assets/lazy-3c4d.js`]);

    scope.files.clear();
    expect(await (await scope.request(`${ORIGIN}/assets/lazy-3c4d.js`))?.text()).toBe(LAZY);
  });

  it("fails a lazy asset that does not match and does not cache it", async () => {
    const scope = await installed();
    scope.files.set(`${ORIGIN}/assets/lazy-3c4d.js`, "console.log('tampered')");

    await expect(scope.request(`${ORIGIN}/assets/lazy-3c4d.js`)).rejects.toThrow();

    const cache = await scope.storage.open(shellCacheName("b2"));
    expect(await cache.match(`${ORIGIN}/assets/lazy-3c4d.js`)).toBeUndefined();
  });

  it("passes through what the manifest does not list", async () => {
    const scope = await installed();
    scope.files.set(`${ORIGIN}/api/me`, "{}");

    expect(await (await scope.request(`${ORIGIN}/api/me`))?.text()).toBe("{}");
  });

  it("stays out of writes, ranges, other origins and bypassed paths", async () => {
    const scope = await installed([/^\/flare-media\//]);

    expect(scope.request(`${ORIGIN}/api/send`, { method: "POST" })).toBeUndefined();
    expect(scope.request(`${ORIGIN}/assets/app-1a2b.js`, { headers: { range: "bytes=0-1" } })).toBeUndefined();
    expect(scope.request("https://cdn.example/x.js")).toBeUndefined();
    expect(scope.request(`${ORIGIN}/flare-media/video.mp4`, { mode: "navigate" })).toBeUndefined();
  });

  it("reads its assets back after a restart", async () => {
    const { scope } = await deployment();
    start(scope);
    await scope.lifecycle("install");

    const restarted = new FakeScope(scope.location.href);
    const shell = await scope.storage.open(shellCacheName("b2"));
    const copy = await restarted.storage.open(shellCacheName("b2"));
    for (const [key, value] of shell.entries) await copy.put(key, value);
    start(restarted);

    const response = await restarted.request(`${ORIGIN}/assets/app-1a2b.js`);

    expect(await response?.text()).toBe(APP);
    expect(restarted.fetched).toEqual([]);
  });

  it("leaves everything to the network before the shell is there", async () => {
    const { scope } = await deployment();
    start(scope);

    const response = await scope.request(`${ORIGIN}/assets/app-1a2b.js`);

    expect(await response?.text()).toBe(APP);
    expect(scope.fetched).toEqual([`${ORIGIN}/assets/app-1a2b.js`]);
  });
});
