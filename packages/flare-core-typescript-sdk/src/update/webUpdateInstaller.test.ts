import { afterEach, describe, expect, it, vi } from "vitest";

import { AppState } from "../model/app_state";
import type { UpdateActivateWebBundlePlan } from "./model";
import {
  FakeActivityTarget,
  FakeCacheStorage,
  FakeChannelHub,
  FakeContainer,
  FakeStorage,
  FakeWorker,
  recordingContext,
  until,
} from "./testing/fakes";
import {
  FLARE_UPDATE_STATE_CACHE,
  INSTALL_FAILURE_KEY,
  WORKER_SKIP_WAITING,
  sha256Hex,
  webBundleTargetOf,
  workerScriptUrl,
} from "./webBundle";
import { createWebUpdateInstaller, registerFlareServiceWorker, type WebUpdateSession } from "./webUpdateInstaller";

const plan = (overrides: Partial<UpdateActivateWebBundlePlan> = {}): UpdateActivateWebBundlePlan => ({
  kind: "activateWebBundle",
  buildId: "b2",
  assetManifestUrls: ["https://mirror-a.example/b2.json", "https://mirror-b.example/b2.json"],
  assetManifestSha256: "feed",
  mandatory: false,
  blockUi: false,
  ...overrides,
});

function tab(hub = new FakeChannelHub(), overrides: { buildId?: string; inputEmpty?: boolean; storage?: FakeStorage } = {}) {
  const container = new FakeContainer();
  const caches = new FakeCacheStorage();
  const activity = new FakeActivityTarget();
  const storage = overrides.storage ?? new FakeStorage();
  const calls: string[] = [];
  const reload = vi.fn(() => void calls.push("reload"));
  const session: WebUpdateSession = {
    setAppState: async (request) => {
      calls.push(`setAppState:${request.appState}`);
    },
    disconnect: async () => {
      calls.push("disconnect");
    },
  };
  const page = { inputEmpty: overrides.inputEmpty ?? true };
  const installer = createWebUpdateInstaller({
    buildId: overrides.buildId ?? "b1",
    session,
    isInputEmpty: () => page.inputEmpty,
    container,
    caches: caches.asCacheStorage(),
    storage,
    activityTarget: activity,
    createChannel: hub.open,
    reload,
  });
  return { container, caches, activity, storage, calls, reload, page, installer, hub };
}

/** The script URL the installer registers for `target`. */
const scriptUrlOf = (target: UpdateActivateWebBundlePlan): string => workerScriptUrl("/sw.js", {
  buildId: target.buildId,
  manifestUrls: target.assetManifestUrls,
  manifestSha256: target.assetManifestSha256,
});

/** The worker of the pending install passes its checks; skipWaiting then hands over control. */
function acceptInstall(container: FakeContainer): FakeWorker {
  const worker = container.finishInstall();
  worker.onMessage = (message) => {
    if ((message as { type?: string }).type === WORKER_SKIP_WAITING) container.fireControllerChange();
  };
  return worker;
}

afterEach(() => {
  vi.useRealTimers();
});

describe("web install flow", () => {
  it("registers the target's URL, waits for the person, then stops, activates and broadcasts", async () => {
    const { container, calls, reload, hub, installer } = tab();
    const { context, asked, answer } = recordingContext();

    const running = installer.execute(plan(), context);
    await until(() => container.registered.length === 1);

    const { url, options } = container.registered[0]!;
    expect(options).toEqual({ scope: "/", updateViaCache: "none" });
    expect(url.startsWith("/sw.js?")).toBe(true);
    expect(webBundleTargetOf(url)).toEqual({
      buildId: "b2",
      manifestUrls: ["https://mirror-a.example/b2.json", "https://mirror-b.example/b2.json"],
      manifestSha256: "feed",
    });

    const worker = acceptInstall(container);
    await until(asked);
    expect(worker.messages).toEqual([]);
    expect(calls).toEqual([]);

    answer(true);
    const result = await running;

    expect(calls).toEqual([`setAppState:${AppState.Background}`, "disconnect"]);
    expect(worker.messages).toEqual([{ type: WORKER_SKIP_WAITING }]);
    expect(hub.sent).toContainEqual({ type: "reload", buildId: "b2" });
    expect(result.outcome).toBe("completed");

    expect(reload).not.toHaveBeenCalled();
    await result.finish?.();
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it("gives the same URL for a rollback: an older build is just another target", async () => {
    const { container, installer } = tab(undefined, { buildId: "b9" });
    const { context, asked, answer } = recordingContext();

    const running = installer.execute(plan({ buildId: "b3" }), context);
    await until(() => container.registered.length === 1);
    expect(webBundleTargetOf(container.registered[0]!.url)?.buildId).toBe("b3");

    acceptInstall(container);
    await until(asked);
    answer(true);

    expect((await running).outcome).toBe("completed");
  });

  it("abandons the update and reports the worker's code when verification fails", async () => {
    const { container, caches, calls, reload, hub, installer } = tab();
    const { context, asked } = recordingContext();
    const state = await caches.open(FLARE_UPDATE_STATE_CACHE);

    const running = installer.execute(plan(), context);
    await until(() => container.registered.length === 1);
    await state.put(INSTALL_FAILURE_KEY, new Response(JSON.stringify({
      buildId: "b2",
      code: "update.hashMismatch",
      url: "/assets/app.js",
    })));
    container.failInstall();
    const result = await running;

    expect(result).toEqual({ outcome: "failed", code: "update.hashMismatch" });
    expect(asked()).toBe(false);
    expect(calls).toEqual([]);
    expect(hub.sent).toEqual([]);
    expect(reload).not.toHaveBeenCalled();
    expect(await state.match(INSTALL_FAILURE_KEY)).toBeUndefined();
  });

  it("falls back to installFailed when the worker left no record", async () => {
    const { container, installer } = tab();
    const { context } = recordingContext();

    const running = installer.execute(plan(), context);
    await until(() => container.registered.length === 1);
    container.failInstall();

    expect(await running).toEqual({ outcome: "failed", code: "update.installFailed" });
  });

  it("ignores a failure record of another build", async () => {
    const { container, caches, installer } = tab();
    const { context } = recordingContext();
    const state = await caches.open(FLARE_UPDATE_STATE_CACHE);
    await state.put(INSTALL_FAILURE_KEY, new Response(JSON.stringify({ buildId: "b7", code: "update.hashMismatch" })));

    const running = installer.execute(plan(), context);
    await until(() => container.registered.length === 1);
    container.failInstall();

    expect(await running).toEqual({ outcome: "failed", code: "update.installFailed" });
  });

  it("reports a script that cannot be fetched as a failed download", async () => {
    const { container, installer } = tab();
    const { context } = recordingContext();
    container.failRegister = new TypeError("offline");

    expect(await installer.execute(plan(), context)).toEqual({ outcome: "failed", code: "update.downloadFailed" });
  });

  it("keeps a verified waiting worker when the person puts the update off, and reuses it", async () => {
    const { container, calls, installer } = tab();
    const first = recordingContext();

    const running = installer.execute(plan(), first.context);
    await until(() => container.registered.length === 1);
    const worker = acceptInstall(container);
    await until(first.asked);
    first.answer(false);

    expect(await running).toEqual({ outcome: "cancelled" });
    expect(calls).toEqual([]);
    expect(worker.messages).toEqual([]);
    expect(container.registration.waiting).toBe(worker);

    const second = recordingContext();
    const again = installer.execute(plan(), second.context);
    await until(second.asked);
    expect(container.registration.installing).toBeNull();
    second.answer(true);

    expect((await again).outcome).toBe("completed");
    expect(worker.messages).toEqual([{ type: WORKER_SKIP_WAITING }]);
  });

  it("only reloads when the target is already the active worker", async () => {
    const { container, installer } = tab();
    const worker = new FakeWorker(scriptUrlOf(plan()));
    worker.state = "activated";
    container.registration.active = worker;
    const { context, asked, answer } = recordingContext();

    const running = installer.execute(plan(), context);
    await until(asked);
    answer(true);

    expect((await running).outcome).toBe("completed");
    expect(worker.messages).toEqual([]);
  });

  it("forwards the worker's progress for this build while it installs", async () => {
    const hub = new FakeChannelHub();
    const { container, installer } = tab(hub);
    const worker = hub.open();
    const { context, progress, asked, answer } = recordingContext();

    const running = installer.execute(plan(), context);
    await until(() => container.registered.length === 1);
    worker.postMessage({ type: "installProgress", buildId: "b2", received: 5, total: 10 });
    worker.postMessage({ type: "installProgress", buildId: "other", received: 9, total: 10 });
    await until(() => progress.length === 1);

    acceptInstall(container);
    await until(asked);
    expect(progress).toEqual([{ received: 5, total: 10 }, null]);

    answer(false);
    await running;
  });

  it("refuses a plan it cannot carry out", async () => {
    const { container, installer } = tab();
    const { context } = recordingContext();

    const result = await installer.execute(
      { kind: "desktopUpdater", version: "2.4.0", target: "darwin-aarch64", sha256: "aa" },
      context,
    );

    expect(result).toEqual({ outcome: "failed", code: "update.installFailed" });
    expect(container.registered).toEqual([]);
  });

  it("does not wait forever on a session that will not stop", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const hub = new FakeChannelHub();
    const container = new FakeContainer();
    const installer = createWebUpdateInstaller({
      buildId: "b1",
      session: { setAppState: () => new Promise(() => undefined), disconnect: async () => undefined },
      isInputEmpty: () => true,
      container,
      caches: new FakeCacheStorage().asCacheStorage(),
      storage: new FakeStorage(),
      activityTarget: new FakeActivityTarget(),
      createChannel: hub.open,
      reload: vi.fn(),
    });
    const { context } = recordingContext();

    const running = installer.execute(plan({ mandatory: true, blockUi: true }), context);
    await until(() => container.registered.length === 1);
    const worker = acceptInstall(container);
    await vi.advanceTimersByTimeAsync(3_000);
    await until(() => worker.messages.length === 1);

    expect((await running).outcome).toBe("completed");
  });
});

describe("forced web updates", () => {
  const forced = plan({ mandatory: true });

  it("goes ahead at once under blockUi, without asking", async () => {
    const { container, installer } = tab();
    const { context, asked } = recordingContext();

    const running = installer.execute(plan({ mandatory: true, blockUi: true }), context);
    await until(() => container.registered.length === 1);
    acceptInstall(container);

    expect((await running).outcome).toBe("completed");
    expect(asked()).toBe(false);
  });

  it("goes ahead after 30 idle seconds with an empty composer", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { container, installer, activity } = tab();
    const { context, asked } = recordingContext();

    const running = installer.execute(forced, context);
    await until(() => container.registered.length === 1);
    acceptInstall(container);
    await until(asked);

    await vi.advanceTimersByTimeAsync(29_000);
    activity.fire("keydown");
    await vi.advanceTimersByTimeAsync(29_000);
    expect(container.registration.waiting?.messages).toEqual([]);

    await vi.advanceTimersByTimeAsync(1_000);
    await until(() => (container.registration.waiting?.messages.length ?? 0) === 1);

    expect((await running).outcome).toBe("completed");
    expect(activity.count()).toBe(0);
  });

  it("holds back while the composer has text, however idle the page is", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { container, installer, page } = tab(undefined, { inputEmpty: false });
    const { context, asked } = recordingContext();

    const running = installer.execute(forced, context);
    await until(() => container.registered.length === 1);
    acceptInstall(container);
    await until(asked);

    await vi.advanceTimersByTimeAsync(120_000);
    expect(container.registration.waiting?.messages).toEqual([]);

    page.inputEmpty = true;
    await vi.advanceTimersByTimeAsync(1_000);

    expect((await running).outcome).toBe("completed");
  });

  it("lets the person confirm before the page is idle", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { container, installer, activity } = tab();
    const { context, asked, answer } = recordingContext();

    const running = installer.execute(forced, context);
    await until(() => container.registered.length === 1);
    acceptInstall(container);
    await until(asked);
    answer(true);

    await until(() => activity.count() === 0);
    await until(() => (container.registration.waiting?.messages.length ?? 0) === 1);

    expect((await running).outcome).toBe("completed");
  });
});

describe("tabs together", () => {
  it("other tabs stop and reload when one activates a build", async () => {
    const hub = new FakeChannelHub();
    const first = tab(hub);
    const second = tab(hub);
    const { context } = recordingContext();

    const running = first.installer.execute(plan({ mandatory: true, blockUi: true }), context);
    await until(() => first.container.registered.length === 1);
    acceptInstall(first.container);
    await running;

    await until(() => second.reload.mock.calls.length === 1);
    expect(second.calls).toEqual([`setAppState:${AppState.Background}`, "disconnect", "reload"]);
    expect(first.reload).not.toHaveBeenCalled();
  });

  it("a tab already on the build stays as it is", async () => {
    const hub = new FakeChannelHub();
    const current = tab(hub, { buildId: "b2" });
    const announcer = hub.open();

    announcer.postMessage({ type: "reload", buildId: "b2" });
    await new Promise((resolve) => setImmediate(resolve));

    expect(current.reload).not.toHaveBeenCalled();
  });

  it("a tab with text in its composer follows once it is idle and empty", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const hub = new FakeChannelHub();
    const typing = tab(hub, { inputEmpty: false });
    const announcer = hub.open();

    announcer.postMessage({ type: "reload", buildId: "b2" });
    await vi.advanceTimersByTimeAsync(60_000);
    expect(typing.reload).not.toHaveBeenCalled();

    typing.page.inputEmpty = true;
    await vi.advanceTimersByTimeAsync(1_000);
    await until(() => typing.reload.mock.calls.length === 1);
  });

  it("a repeated announcement reloads once", async () => {
    const hub = new FakeChannelHub();
    const other = tab(hub);
    const announcer = hub.open();

    announcer.postMessage({ type: "reload", buildId: "b2" });
    announcer.postMessage({ type: "reload", buildId: "b2" });
    await until(() => other.reload.mock.calls.length > 0);
    await new Promise((resolve) => setImmediate(resolve));

    expect(other.reload).toHaveBeenCalledTimes(1);
  });

  it("dispose stops listening", async () => {
    const hub = new FakeChannelHub();
    const other = tab(hub);
    const announcer = hub.open();

    other.installer.dispose?.();
    announcer.postMessage({ type: "reload", buildId: "b2" });
    await new Promise((resolve) => setImmediate(resolve));

    expect(other.reload).not.toHaveBeenCalled();
  });
});

describe("without a Service Worker", () => {
  it("is a plain reload after the person confirms", async () => {
    const hub = new FakeChannelHub();
    const reload = vi.fn();
    const installer = createWebUpdateInstaller({
      buildId: "b1",
      session: { setAppState: async () => undefined, disconnect: async () => undefined },
      isInputEmpty: () => true,
      container: null,
      caches: null,
      storage: new FakeStorage(),
      activityTarget: null,
      createChannel: hub.open,
      reload,
    });
    const { context, asked, answer } = recordingContext();

    const running = installer.execute(plan(), context);
    await until(asked);
    answer(true);
    const result = await running;
    await result.finish?.();

    expect(result.outcome).toBe("completed");
    expect(reload).toHaveBeenCalledTimes(1);
  });
});

describe("reload guard", () => {
  it("fails instead of reloading again when the last reload did not reach the build", async () => {
    const storage = new FakeStorage();
    const before = tab(undefined, { storage });
    const firstContext = recordingContext();
    const first = before.installer.execute(plan({ blockUi: true, mandatory: true }), firstContext.context);
    await until(() => before.container.registered.length === 1);
    acceptInstall(before.container);
    await first;

    const after = tab(undefined, { storage });
    after.container.registration.active = new FakeWorker(scriptUrlOf(plan({ blockUi: true, mandatory: true })));
    const secondContext = recordingContext();

    const result = await after.installer.execute(plan({ blockUi: true, mandatory: true }), secondContext.context);

    expect(result).toEqual({ outcome: "failed", code: "update.installFailed" });
    expect(after.calls).toEqual([]);
  });

  it("forgets the target once the page runs that build", () => {
    const storage = new FakeStorage();
    storage.setItem("flare-update:reload-target", "b2");

    tab(undefined, { buildId: "b2", storage });

    expect(storage.items.size).toBe(0);
  });
});

describe("registerFlareServiceWorker", () => {
  const manifest = new TextEncoder().encode('{"schema":"flare.web-assets.v1","buildId":"b1","assets":[]}');
  const body = () => manifest.buffer.slice(0) as ArrayBuffer;
  const afterFirstPaint = async () => undefined;

  it("registers the running build with its manifest's hash, once the first screen is up", async () => {
    const container = new FakeContainer();
    const order: string[] = [];

    await registerFlareServiceWorker({
      buildId: "b1",
      container,
      afterFirstPaint: async () => {
        order.push("paint");
      },
      fetch: async (url) => {
        order.push(`fetch:${url}`);
        return new Response(body());
      },
    });

    expect(order).toEqual(["paint", "fetch:/asset-manifest.json"]);
    expect(webBundleTargetOf(container.registered[0]!.url)).toEqual({
      buildId: "b1",
      manifestUrls: ["/asset-manifest.json"],
      manifestSha256: await sha256Hex(body()),
    });
    expect(container.registered[0]!.options).toEqual({ scope: "/", updateViaCache: "none" });
  });

  it("leaves an existing registration alone: it may be a newer build", async () => {
    const container = new FakeContainer();
    container.existing = true;

    await registerFlareServiceWorker({ buildId: "b1", container, afterFirstPaint, fetch: async () => new Response(body()) });

    expect(container.registered).toEqual([]);
  });

  it("reports a failure without throwing", async () => {
    const container = new FakeContainer();
    const onError = vi.fn();

    await registerFlareServiceWorker({
      buildId: "b1",
      container,
      afterFirstPaint,
      fetch: async () => new Response(null, { status: 404 }),
      onError,
    });

    expect(onError).toHaveBeenCalledTimes(1);
    expect(container.registered).toEqual([]);
  });

  it("does nothing where the browser has no Service Worker", async () => {
    await expect(registerFlareServiceWorker({ buildId: "b1", container: null })).resolves.toBeUndefined();
  });
});
