import { afterEach, describe, expect, it, vi } from "vitest";

import type { AppStateSource } from "../lifecycle/platformLifecycle";
import { AppState } from "../model/app_state";
import type { UpdateInstallPlan, UpdateReleaseSummary, UpdateStatus } from "../model";
import { until } from "./testing/fakes";
import type { FlareUpdateApi } from "./updateApi";
import { FlareUpdateController, isStoreDistribution } from "./updateController";
import type { FlareUpdateInstaller, UpdateInstallContext, UpdateInstallResult } from "./updateInstaller";

const release = (overrides: Partial<UpdateReleaseSummary> = {}): UpdateReleaseSummary => ({
  releaseId: "rel_1",
  version: "2.4.0",
  build: 20400,
  notes: ["Faster sync"],
  sizeBytes: 1000,
  mandatory: false,
  recommended: false,
  kind: "package",
  ...overrides,
});

const status = (overrides: Partial<UpdateStatus> = {}): UpdateStatus => ({
  state: "available",
  current: { version: "2.3.2", build: 20302, channel: "stable", distribution: "direct" },
  release: release(),
  prompt: "sheet",
  blockUi: false,
  readOnly: false,
  lastCheckedAt: 1,
  ...overrides,
});

const packagePlan: UpdateInstallPlan = {
  kind: "installPackage",
  path: "/cache/2.4.0.apk",
  sha256: "aa",
  signingCertSha256: "bb",
  build: 20400,
  sizeBytes: 1000,
};

const webPlan: UpdateInstallPlan = {
  kind: "activateWebBundle",
  buildId: "b2",
  assetManifestUrls: ["https://cdn.example/b2.json"],
  assetManifestSha256: "cc",
  mandatory: false,
  blockUi: false,
};

/** Answers `state` from every status operation and records the calls in order. */
class FakeApi implements FlareUpdateApi {
  readonly calls: Array<[string, unknown?]> = [];
  state: UpdateStatus;
  plan: UpdateInstallPlan = packagePlan;
  downloadAnswer: () => Promise<unknown> = async () => status({ state: "readyToInstall" });
  resourcesAnswer: () => Promise<unknown> = async () => ({ packs: [] });
  reportFailure: Error | null = null;

  constructor(initial: UpdateStatus) {
    this.state = initial;
  }

  names(): string[] {
    return this.calls.map(([name]) => name);
  }

  count(name: string): number {
    return this.names().filter((called) => called === name).length;
  }

  getState = async (request?: unknown): Promise<unknown> => {
    this.calls.push(["getState", request]);
    return this.state;
  };

  setLocale = async (request: unknown): Promise<unknown> => {
    this.calls.push(["setLocale", request]);
    return this.state;
  };

  check = async (request: unknown): Promise<unknown> => {
    this.calls.push(["check", request]);
    return this.state;
  };

  download = async (request: unknown): Promise<unknown> => {
    this.calls.push(["download", request]);
    return this.downloadAnswer();
  };

  install = async (): Promise<unknown> => {
    this.calls.push(["install"]);
    return this.plan;
  };

  reportInstall = async (request: unknown): Promise<unknown> => {
    this.calls.push(["reportInstall", request]);
    if (this.reportFailure) throw this.reportFailure;
    return this.state;
  };

  defer = async (): Promise<unknown> => {
    this.calls.push(["defer"]);
    return this.state;
  };

  skip = async (request: unknown): Promise<unknown> => {
    this.calls.push(["skip", request]);
    return this.state;
  };

  markPrompted = async (request: unknown): Promise<unknown> => {
    this.calls.push(["markPrompted", request]);
    return this.state;
  };

  getResources = async (request: unknown): Promise<unknown> => {
    this.calls.push(["getResources", request]);
    return this.resourcesAnswer();
  };
}

function harness(initial: UpdateStatus, execute?: FlareUpdateInstaller["execute"]) {
  const api = new FakeApi(initial);
  const stateListeners = new Set<(payload: unknown) => void>();
  const loginListeners = new Set<(event: unknown) => void>();
  const appStateListeners = new Set<(state: AppState) => void>();
  const appState: AppStateSource = {
    current: () => AppState.Foreground,
    subscribe(listener) {
      appStateListeners.add(listener);
      return () => appStateListeners.delete(listener);
    },
  };
  const installer = {
    execute: vi.fn(execute ?? (async (): Promise<UpdateInstallResult> => ({ outcome: "completed" }))),
    dispose: vi.fn(),
  };
  const controller = new FlareUpdateController({
    api,
    installer,
    appState,
    subscribe(listener) {
      stateListeners.add(listener);
      return { unsubscribe: () => stateListeners.delete(listener) };
    },
    loginSucceeded(listener) {
      loginListeners.add(listener);
      return () => loginListeners.delete(listener);
    },
  });
  return {
    api,
    installer,
    controller,
    stateListeners,
    loginListeners,
    appStateListeners,
    emit(payload: UpdateStatus) {
      for (const listener of [...stateListeners]) listener(payload);
    },
    login() {
      for (const listener of [...loginListeners]) listener({});
    },
    comeForward() {
      for (const listener of [...appStateListeners]) listener(AppState.Foreground);
    },
  };
}

const settled = (): Promise<void> => new Promise((resolve) => {
  setImmediate(resolve);
});

afterEach(() => {
  vi.useRealTimers();
});

describe("FlareUpdateController state", () => {
  it("subscribes before the first read and keeps an event that overtook it", async () => {
    const { api, controller, emit, stateListeners } = harness(status({ state: "available" }));
    const read: { answer?: (value: unknown) => void } = {};
    api.getState = () => new Promise((resolve) => {
      read.answer = resolve;
    });

    const started = controller.start();
    await until(() => read.answer !== undefined);
    expect(stateListeners.size).toBe(1);
    emit(status({ state: "downloading" }));
    read.answer?.(status({ state: "available" }));
    await started;

    expect(controller.status?.state).toBe("downloading");
    controller.dispose();
  });

  it("is null before the first read and takes the core's form with null fields", async () => {
    const { api, controller } = harness(status());
    expect(controller.status).toBeNull();
    api.state = { ...status({ state: "upToDate" }), release: null, progress: null, error: null } as unknown as UpdateStatus;

    await controller.start();

    expect(controller.status).toMatchObject({ state: "upToDate", release: undefined, progress: undefined, error: undefined });
  });

  it("reads the state at start, at login and when the app comes forward", async () => {
    const { api, controller, login, comeForward } = harness(status());

    await controller.start();
    expect(api.count("getState")).toBe(1);
    login();
    await until(() => api.count("getState") === 2);
    comeForward();
    await until(() => api.count("getState") === 3);
    expect(api.calls).toEqual([["getState", {}], ["getState", {}], ["getState", { foreground: true }]]);
  });

  it("hands the app's language to the core and shows what it answers", async () => {
    const { api, controller } = harness(status());
    await controller.start();

    api.state = status({ release: release({ notes: ["更快的同步"] }) });
    await controller.setLocale("zh-CN");

    expect(api.calls).toContainEqual(["setLocale", { locale: "zh-CN" }]);
    expect(controller.status?.release?.notes).toEqual(["更快的同步"]);
  });

  it("takes every answer as the latest state, with no event to back it", async () => {
    const { api, controller } = harness(status({ state: "idle", release: undefined }));
    await controller.start();

    api.state = status({ state: "available" });
    await controller.check();
    expect(controller.status?.state).toBe("available");
    expect(api.calls).toContainEqual(["check", { manual: true }]);

    api.state = status({ state: "available", prompt: "none" });
    await controller.markPrompted("sheet");
    expect(controller.status?.prompt).toBe("none");
  });

  it("polls a transient state after 500 ms without events and stops at any other state", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { api, controller } = harness(status({ state: "checking" }));
    await controller.start();
    expect(api.count("getState")).toBe(1);

    await vi.advanceTimersByTimeAsync(499);
    expect(api.count("getState")).toBe(1);
    await vi.advanceTimersByTimeAsync(1);
    expect(api.count("getState")).toBe(2);

    await vi.advanceTimersByTimeAsync(500);
    expect(api.count("getState")).toBe(3);

    api.state = status({ state: "upToDate", release: undefined });
    await vi.advanceTimersByTimeAsync(500);
    expect(api.count("getState")).toBe(4);
    await vi.advanceTimersByTimeAsync(5_000);
    expect(api.count("getState")).toBe(4);
  });

  it("does not poll while events keep arriving", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { api, controller, emit } = harness(status({ state: "downloading" }));
    await controller.start();

    for (let tick = 0; tick < 5; tick += 1) {
      await vi.advanceTimersByTimeAsync(300);
      emit(status({ state: "downloading", progress: { received: tick, total: 10 } }));
    }
    expect(api.count("getState")).toBe(1);

    await vi.advanceTimersByTimeAsync(500);
    expect(api.count("getState")).toBe(2);
    controller.dispose();
  });
});

describe("FlareUpdateController.check", () => {
  const nothing = (state: string): UpdateStatus => status({ state, release: undefined, prompt: "none" });

  it("takes the checking answer for a round under way and ends with its result", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { api, controller } = harness(nothing("idle"));
    await controller.start();
    api.state = nothing("checking");

    let result: UpdateStatus | undefined;
    const done = controller.check().then((value) => {
      result = value;
    });
    await vi.advanceTimersByTimeAsync(500);
    expect(api.count("getState")).toBe(2);
    expect(result).toBeUndefined();

    api.state = status({ state: "available" });
    await vi.advanceTimersByTimeAsync(500);
    await done;

    expect(result?.state).toBe("available");
    await vi.advanceTimersByTimeAsync(5_000);
    expect(api.count("getState")).toBe(3);
  });

  it("ends on the event that brings the result, before any poll", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { api, controller, emit } = harness(nothing("idle"));
    await controller.start();
    api.state = nothing("checking");

    const done = controller.check();
    await vi.advanceTimersByTimeAsync(100);
    emit(nothing("upToDate"));

    await expect(done).resolves.toMatchObject({ state: "upToDate" });
    expect(api.count("getState")).toBe(1);
  });

  it("keeps a failed round's error, which arrives with the state after checking", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { api, controller } = harness(nothing("idle"));
    await controller.start();
    api.state = nothing("checking");

    const done = controller.check();
    await vi.advanceTimersByTimeAsync(0);
    api.state = { ...nothing("idle"), error: { code: "update.manifestUnavailable", retryable: true } };
    await vi.advanceTimersByTimeAsync(500);

    await expect(done).resolves.toMatchObject({ error: { code: "update.manifestUnavailable" } });
  });

  it("does not hang on a round the controller stops waiting for", async () => {
    const { api, controller } = harness(nothing("idle"));
    await controller.start();
    api.state = nothing("checking");

    const done = controller.check();
    await until(() => api.count("check") === 1);
    await settled();
    controller.dispose();

    await expect(done).resolves.toMatchObject({ state: "checking" });
  });
});

describe("FlareUpdateController.update", () => {
  it("looks for the release when the server refused before any manifest named one", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const refused = status({ state: "required", prompt: "modal", release: undefined, readOnly: true });
    const { api, controller, installer } = harness(refused);
    await controller.start();
    api.state = status({ state: "checking", prompt: "none", release: undefined, readOnly: true });

    let result: UpdateStatus | undefined;
    const done = controller.update().then((value) => {
      result = value;
    });
    await vi.advanceTimersByTimeAsync(500);
    expect(api.calls).toContainEqual(["check", { manual: true }]);
    expect(result).toBeUndefined();

    api.state = status({ state: "required", prompt: "modal", release: release({ kind: "desktop", mandatory: true }) });
    await vi.advanceTimersByTimeAsync(500);
    await done;

    expect(result).toMatchObject({ state: "required", release: { version: "2.4.0" } });
    expect(api.count("install")).toBe(0);
    expect(installer.execute).not.toHaveBeenCalled();
  });

  it("downloads, installs, carries out the plan and reports, in that order", async () => {
    const { api, controller, installer } = harness(status());

    await controller.update();

    expect(api.names()).toEqual(["getState", "download", "install", "reportInstall"]);
    expect(api.calls[1]).toEqual(["download", { allowMetered: false }]);
    expect(installer.execute.mock.calls[0]?.[0]).toEqual(packagePlan);
    expect(api.calls[3]).toEqual(["reportInstall", { outcome: "completed" }]);
  });

  it("does not download what needs no download", async () => {
    const { api, controller } = harness(status({ release: release({ kind: "desktop" }) }));

    await controller.update();

    expect(api.count("download")).toBe(0);
    expect(api.count("install")).toBe(1);
  });

  it("shows the installing state while the plan runs, though update.install answers no status", async () => {
    const states: Array<string | undefined> = [];
    const { controller } = harness(status({ release: release({ kind: "desktop" }) }), async () => {
      states.push(controller.status?.state);
      return { outcome: "completed" };
    });

    await controller.update();

    expect(states).toEqual(["installing"]);
  });

  it("leaves the installer alone when the core offers nothing to install", async () => {
    for (const initial of [
      status({ state: "upToDate", release: undefined }),
      status({ state: "checking" }),
      status({ state: "idle" }),
    ]) {
      const { api, controller, installer } = harness(initial);
      await controller.update();
      expect(api.count("install")).toBe(0);
      expect(installer.execute).not.toHaveBeenCalled();
      controller.dispose();
    }
  });

  it("allows the metered download on the update after the core asked for it", async () => {
    const { api, controller, installer } = harness(status());
    api.downloadAnswer = async () => {
      throw Object.assign(new Error("metered"), { code: "update.meteredConfirmationRequired" });
    };

    await controller.update();

    expect(controller.status?.error?.code).toBe("update.meteredConfirmationRequired");
    expect(installer.execute).not.toHaveBeenCalled();

    api.downloadAnswer = async () => status({ state: "readyToInstall" });
    await controller.update();

    expect(api.calls.filter(([name]) => name === "download").map(([, request]) => request)).toEqual([
      { allowMetered: false },
      { allowMetered: true },
    ]);
    expect(installer.execute).toHaveBeenCalledTimes(1);
  });

  it("reads the metered refusal from a returned status just the same", async () => {
    const refused = status({
      error: { code: "update.meteredConfirmationRequired", retryable: true },
    });
    const { api, controller } = harness(refused);
    api.downloadAnswer = async () => status({ state: "readyToInstall" });

    await controller.update();

    expect(api.calls).toContainEqual(["download", { allowMetered: true }]);
  });

  it("waits out a download that answers early, also with no event coming", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { api, controller, installer } = harness(status());
    await controller.start();
    api.downloadAnswer = async () => status({ state: "downloading" });
    api.state = status({ state: "downloading" });

    const done = controller.update();
    await vi.advanceTimersByTimeAsync(500);
    expect(api.count("download")).toBe(1);
    expect(installer.execute).not.toHaveBeenCalled();

    api.state = status({ state: "readyToInstall" });
    await vi.advanceTimersByTimeAsync(500);
    await done;

    expect(installer.execute).toHaveBeenCalledTimes(1);
  });

  it("reports a failed install with its code", async () => {
    const { api, controller } = harness(
      status({ state: "readyToInstall" }),
      async () => ({ outcome: "failed", code: "update.hashMismatch" }),
    );
    await controller.start();
    api.state = status({
      state: "failed",
      error: { code: "update.hashMismatch", retryable: true, fallbackUrl: "https://acme.example/download" },
    });

    await controller.update();

    expect(api.calls).toContainEqual(["reportInstall", { outcome: "failed", code: "update.hashMismatch" }]);
    expect(controller.status?.state).toBe("failed");
    expect(controller.errorRetryable).toBe(true);
  });

  it("reports an installer that throws as failed", async () => {
    const { api, controller } = harness(status({ state: "readyToInstall" }), async () => {
      throw new Error("boom");
    });

    await controller.update();

    expect(api.calls).toContainEqual(["reportInstall", { outcome: "failed", code: "update.installFailed" }]);
  });

  it("runs finish after the report, and even when the report is lost", async () => {
    const order: string[] = [];
    const { api, controller } = harness(status({ state: "readyToInstall" }), async () => ({
      outcome: "completed",
      finish: () => void order.push("finish"),
    }));
    const report = api.reportInstall;
    api.reportInstall = async (request) => {
      order.push("report");
      return report(request);
    };

    await controller.update();
    expect(order).toEqual(["report", "finish"]);

    order.length = 0;
    api.reportFailure = new Error("gone");
    await controller.update();
    expect(order).toEqual(["report", "finish"]);
  });

  it("shares one run between concurrent calls", async () => {
    const { controller, installer } = harness(status({ state: "readyToInstall" }));

    await Promise.all([controller.update(), controller.update()]);

    expect(installer.execute).toHaveBeenCalledTimes(1);
  });

  it("puts a thrown install refusal into the status instead of rejecting", async () => {
    const { api, controller, installer } = harness(status({ state: "readyToInstall" }));
    api.install = async () => {
      throw Object.assign(new Error("no artifact"), { reason: "update.noArtifact" });
    };

    await expect(controller.update()).resolves.toMatchObject({ error: { code: "update.noArtifact" } });

    expect(installer.execute).not.toHaveBeenCalled();
  });

  it("reads the state after a refusal: the way out is in it, not in the refusal", async () => {
    const { api, controller } = harness(status({ state: "available" }));
    api.install = async () => {
      api.state = status({
        state: "available",
        error: { code: "update.noArtifact", retryable: false, fallbackUrl: "https://acme.example/download" },
      });
      throw new Error("update.noArtifact");
    };

    await expect(controller.update()).resolves.toMatchObject({
      error: { code: "update.noArtifact", retryable: false, fallbackUrl: "https://acme.example/download" },
    });
  });

  it("keeps the refusal when the state cannot be read after it", async () => {
    const { api, controller } = harness(status({ state: "available" }));
    await controller.start();
    api.install = async () => {
      api.getState = async () => {
        throw new Error("gone");
      };
      throw new Error("update.noArtifact");
    };

    await expect(controller.update()).resolves.toMatchObject({ error: { code: "update.noArtifact" } });
  });
});

describe("FlareUpdateController confirmation", () => {
  function confirming() {
    const finish = vi.fn();
    let result: boolean | undefined;
    const initial = status({ state: "available", release: release({ kind: "webBundle" }) });
    const parts = harness(initial, async (_plan, context: UpdateInstallContext) => {
      result = await context.waitForConfirmation();
      return result ? { outcome: "completed", finish } : { outcome: "cancelled" };
    });
    parts.api.plan = webPlan;
    return { ...parts, finish, result: () => result };
  }

  it("shows readyToInstall while the installer waits, and update() is the confirmation", async () => {
    const { controller, finish, api } = confirming();

    const running = controller.update();
    await until(() => controller.status?.state === "readyToInstall");
    expect(api.count("reportInstall")).toBe(0);

    await controller.update();
    await running;

    expect(api.calls).toContainEqual(["reportInstall", { outcome: "completed" }]);
    expect(finish).toHaveBeenCalledTimes(1);
  });

  it("later() ends the wait as cancelled, then defers", async () => {
    const { controller, api, finish, result } = confirming();

    const running = controller.update();
    await until(() => controller.status?.state === "readyToInstall");
    await controller.later();
    await running;

    expect(result()).toBe(false);
    expect(finish).not.toHaveBeenCalled();
    expect(api.names().slice(-2)).toEqual(["reportInstall", "defer"]);
    expect(api.calls).toContainEqual(["reportInstall", { outcome: "cancelled" }]);
  });

  it("dispose() ends the wait", async () => {
    const { controller, result, installer } = confirming();

    const running = controller.update();
    await until(() => controller.status?.state === "readyToInstall");
    controller.dispose();
    await running;

    expect(result()).toBe(false);
    expect(installer.dispose).toHaveBeenCalledTimes(1);
  });

  it("shows installer progress and clears it afterwards", async () => {
    const seen: Array<number | undefined> = [];
    const { controller, api } = harness(status({ release: release({ kind: "desktop" }) }), async (_plan, context) => {
      context.setProgress({ received: 5, total: 10 });
      seen.push(controller.status?.progress?.received);
      return { outcome: "completed" };
    });
    await controller.start();
    api.state = status({ state: "upToDate", release: undefined });

    await controller.update();

    expect(seen).toEqual([5]);
    expect(controller.status?.progress).toBeUndefined();
  });
});

describe("FlareUpdateController put-off restart", () => {
  function installed() {
    const restart = vi.fn(async () => undefined);
    const desktop = release({ kind: "desktop" });
    const parts = harness(status({ release: desktop }), async (_plan, context) => {
      const confirmed = await context.waitForConfirmation();
      return confirmed ? { outcome: "completed", finish: restart } : { outcome: "completed", restart };
    });
    return { ...parts, restart, desktop };
  }

  async function putOff({ api, controller, desktop }: ReturnType<typeof installed>): Promise<void> {
    const running = controller.update();
    await until(() => controller.status?.state === "readyToInstall");
    api.state = status({ state: "installing", prompt: "badge", release: desktop });
    await controller.later();
    await running;
  }

  it("stays ready to restart whatever the core says, and update() then restarts", async () => {
    const parts = installed();
    const { api, controller, installer, restart } = parts;

    await putOff(parts);

    expect(api.names().slice(-2)).toEqual(["reportInstall", "defer"]);
    expect(controller.status).toMatchObject({ state: "readyToInstall", prompt: "badge" });
    expect(restart).not.toHaveBeenCalled();

    await controller.update();

    expect(restart).toHaveBeenCalledTimes(1);
    expect(api.count("install")).toBe(1);
    expect(installer.execute).toHaveBeenCalledTimes(1);
  });

  it("shows the same state to a prompt the core opens again", async () => {
    const parts = installed();
    const { api, controller, desktop, emit } = parts;

    await putOff(parts);
    api.state = status({ state: "installing", prompt: "sheet", release: desktop });
    emit(api.state);

    expect(controller.promptView).toMatchObject({ form: "sheet", state: "readyToInstall" });
  });

  it("offers the restart again when it fails", async () => {
    const parts = installed();
    const { controller, restart } = parts;
    await putOff(parts);
    restart.mockRejectedValueOnce(new Error("relaunch"));

    await controller.update();
    expect(controller.status).toMatchObject({ state: "readyToInstall", error: { code: "update.installFailed" } });

    await controller.update();
    expect(restart).toHaveBeenCalledTimes(2);
  });
});

describe("FlareUpdateController forced web updates", () => {
  const required = (releaseId: string): UpdateStatus => status({
    state: "required",
    prompt: "modal",
    release: release({ kind: "webBundle", mandatory: true, releaseId }),
  });

  it("starts by itself, once per release, without looping on a failure", async () => {
    const { api, controller, installer, emit } = harness(required("rel_1"), async () => ({
      outcome: "failed",
      code: "update.hashMismatch",
    }));
    api.plan = { ...webPlan, kind: "activateWebBundle", mandatory: true } as UpdateInstallPlan;

    await controller.start();
    await until(() => api.count("reportInstall") === 1);
    await settled();

    emit(required("rel_1"));
    await settled();
    expect(installer.execute).toHaveBeenCalledTimes(1);

    api.state = required("rel_2");
    emit(required("rel_2"));
    await until(() => api.count("reportInstall") === 2);
    expect(installer.execute).toHaveBeenCalledTimes(2);
  });

  it("takes up a forced release that arrived during a run, once that run ends", async () => {
    const gate: { open?: () => void } = {};
    const { api, controller, installer, emit } = harness(required("rel_1"), async () => {
      if (installer.execute.mock.calls.length === 1) {
        await new Promise<void>((resolve) => {
          gate.open = resolve;
        });
      }
      return { outcome: "failed", code: "update.hashMismatch" };
    });
    api.plan = webPlan;
    await controller.start();
    await until(() => gate.open !== undefined);

    api.state = required("rel_2");
    emit(required("rel_2"));
    expect(installer.execute).toHaveBeenCalledTimes(1);

    gate.open?.();
    await until(() => installer.execute.mock.calls.length === 2);
  });

  it("leaves other forced updates to the person", async () => {
    const { controller, installer } = harness(status({
      state: "required",
      release: release({ kind: "desktop", mandatory: true }),
    }));

    await controller.start();
    await settled();

    expect(installer.execute).not.toHaveBeenCalled();
  });
});

describe("FlareUpdateController.later", () => {
  it("defers during a download too, and the run then stops short of the installer", async () => {
    const { api, controller, installer, emit } = harness(status());
    api.downloadAnswer = async () => status({ state: "downloading" });

    const running = controller.update();
    await until(() => controller.status?.state === "downloading");
    api.state = status({ state: "downloading", prompt: "none" });
    await controller.later();

    expect(api.count("defer")).toBe(1);
    expect(controller.status?.prompt).toBe("none");

    emit(status({ state: "readyToInstall" }));
    await running;

    expect(controller.status?.state).toBe("readyToInstall");
    expect(installer.execute).not.toHaveBeenCalled();

    await controller.update();
    expect(installer.execute).toHaveBeenCalledTimes(1);
    controller.dispose();
  });

  it("lets update() take a download back from the background", async () => {
    const { api, controller, installer, emit } = harness(status());
    api.downloadAnswer = async () => status({ state: "downloading" });

    const running = controller.update();
    await until(() => controller.status?.state === "downloading");
    api.state = status({ state: "downloading" });
    await controller.later();
    void controller.update();

    emit(status({ state: "readyToInstall" }));
    await running;

    expect(installer.execute).toHaveBeenCalledTimes(1);
    controller.dispose();
  });

  it("defers in every other phase", async () => {
    const { api, controller } = harness(status({ state: "available" }));

    await controller.later();

    expect(api.count("defer")).toBe(1);
  });

  it("leaves a forced update to the core, and its install keeps waiting", async () => {
    let answered = false;
    const forced = status({
      state: "required",
      release: release({ kind: "desktop", mandatory: true }),
    });
    const { api, controller } = harness(forced, async (_plan, context) => {
      await context.waitForConfirmation();
      answered = true;
      return { outcome: "completed" };
    });

    const running = controller.update();
    await until(() => controller.status?.state === "readyToInstall");
    api.state = status({
      ...forced,
      error: { code: "update.notSkippable", retryable: false },
    });
    await controller.later();

    expect(api.count("defer")).toBe(1);
    expect(answered).toBe(false);

    await controller.update();
    await running;
    expect(answered).toBe(true);
  });
});

describe("FlareUpdateController prompts", () => {
  it("skips the version on offer", async () => {
    const { api, controller } = harness(status());

    await controller.skip();

    expect(api.calls).toContainEqual(["skip", { build: 20400 }]);
  });

  it("marks the prompt the core asked for, and only a prompt that opens", async () => {
    const { api, controller } = harness(status({ prompt: "modal" }));
    await controller.markPrompted();
    expect(api.calls).toContainEqual(["markPrompted", { build: 20400, form: "modal" }]);

    const quiet = harness(status({ prompt: "badge" }));
    await quiet.controller.markPrompted();
    expect(quiet.api.count("markPrompted")).toBe(0);
  });

  it("marks a forced prompt no manifest named a release for, about no build", async () => {
    const { api, controller } = harness(status({ state: "required", prompt: "modal", release: undefined, readOnly: true }));

    await controller.markPrompted();

    expect(api.calls).toContainEqual(["markPrompted", { form: "modal" }]);
  });

  it("continueReadOnly() is update.defer: the core hides the prompt and turns read-only", async () => {
    const forced = status({
      state: "required",
      prompt: "modal",
      release: release({ kind: "desktop", mandatory: true }),
    });
    const { api, controller } = harness(forced);
    await controller.start();
    expect(controller.canContinueReadOnly).toBe(true);

    api.state = status({ ...forced, prompt: "none", readOnly: true });
    await controller.continueReadOnly();

    expect(api.count("defer")).toBe(1);
    expect(controller.status).toMatchObject({ prompt: "none", readOnly: true });
  });

  it("offers the read-only way out when the server refused before any manifest named a release", async () => {
    const refused = status({ state: "required", prompt: "modal", release: undefined, readOnly: true });
    const { api, controller } = harness(refused);
    await controller.start();
    expect(controller.canContinueReadOnly).toBe(true);

    await controller.continueReadOnly();

    expect(api.count("defer")).toBe(1);
  });

  it("offers no read-only way out of a blocking or optional update", async () => {
    const blocking = harness(status({
      state: "required",
      blockUi: true,
      prompt: "fullscreen",
      release: release({ mandatory: true }),
    }));
    await blocking.controller.start();
    await blocking.controller.continueReadOnly();
    expect(blocking.controller.canContinueReadOnly).toBe(false);
    expect(blocking.api.count("defer")).toBe(0);

    const optional = harness(status());
    await optional.controller.start();
    expect(optional.controller.canContinueReadOnly).toBe(false);
  });

  it("describes the open prompt under the Kit's prop names, and no prompt while none is open", async () => {
    const { controller } = harness(status({
      state: "failed",
      prompt: "modal",
      error: { code: "update.installFailed", retryable: true, fallbackUrl: "https://example.com/get" },
    }));
    await controller.start();

    expect(controller.promptView).toEqual({
      form: "modal",
      version: "2.4.0",
      notes: ["Faster sync"],
      sizeBytes: 1000,
      mandatory: false,
      state: "failed",
      progress: undefined,
      errorCode: "update.installFailed",
      retryable: true,
      fallbackTarget: "website",
      canContinueReadOnly: false,
    });

    const quiet = harness(status({ prompt: "badge" }));
    await quiet.controller.start();
    expect(quiet.controller.promptView).toBeNull();
  });

  it("gives the prompt the core's reason for blocking this build", async () => {
    const { controller } = harness(status({
      state: "required",
      prompt: "modal",
      release: release({ mandatory: true }),
      blockReason: "This build leaks session tokens.",
    }));
    await controller.start();

    expect(controller.promptView?.reason).toBe("This build leaks session tokens.");
  });

  it("treats a refusal with no release yet as forced in the prompt", async () => {
    const { controller } = harness(status({ state: "required", prompt: "modal", release: undefined, readOnly: true }));
    await controller.start();

    expect(controller.promptView).toMatchObject({ version: "", notes: [], mandatory: true, canContinueReadOnly: true });
  });

  it("points the failure prompt to the website only where no store serves the app", async () => {
    const target = async (distribution: string) => {
      const { controller } = harness(status({
        current: { version: "1", build: 1, channel: "stable", distribution },
      }));
      await controller.start();
      return controller.fallbackTarget;
    };

    expect(await target("direct")).toBe("website");
    expect(await target("web")).toBe("website");
    expect(await target("tauri")).toBe("website");
    expect(await target("play")).toBe("store");
    expect(await target("appstore")).toBe("store");
  });

  it("calls a build a store's only when it names a store", () => {
    for (const distribution of ["appstore", "msstore", " play "]) expect(isStoreDistribution(distribution), distribution).toBe(true);
    for (const distribution of ["tauri", "direct", "web", " ", "", null, undefined]) {
      expect(isStoreDistribution(distribution), String(distribution)).toBe(false);
    }
  });

  it("notifies subscribers until they leave, and survives one that throws", async () => {
    const onError = vi.fn();
    const api = new FakeApi(status());
    const controller = new FlareUpdateController({
      api,
      installer: { execute: async () => ({ outcome: "completed" }) },
      appState: null,
      subscribe: () => () => undefined,
      onError,
    });
    const seen: string[] = [];
    controller.subscribe(() => {
      throw new Error("listener");
    });
    const leave = controller.subscribe((value) => seen.push(value.state));

    await controller.start();
    expect(seen).toEqual(["available"]);
    expect(onError).toHaveBeenCalledTimes(1);

    leave();
    await controller.refresh();
    expect(seen).toEqual(["available"]);
  });
});

describe("FlareUpdateController.loadResources", () => {
  const strings = { id: "app-strings", kind: "strings", packVersion: 3, contentJson: "{\"schema\":\"flare.resource.v1\"}" };
  const help = { id: "help", kind: "help", packVersion: 1, contentJson: "{}" };

  it("answers the core's packs in its order, with their content still text", async () => {
    const { api, controller } = harness(status());
    api.resourcesAnswer = async () => ({ packs: [strings, help] });

    await expect(controller.loadResources()).resolves.toEqual([strings, help]);
    expect(api.calls).toEqual([["getResources", {}]]);
  });

  it("needs no start, which a read of the state would be", async () => {
    const { api, controller } = harness(status());

    await controller.loadResources();

    expect(api.count("getState")).toBe(0);
  });

  it("answers none when the core has no packs field", async () => {
    const { api, controller } = harness(status());
    api.resourcesAnswer = async () => ({});

    await expect(controller.loadResources()).resolves.toEqual([]);
  });

  it("tells onError about a failed read and answers none", async () => {
    const api = new FakeApi(status());
    const failure = new Error("not initialized");
    api.resourcesAnswer = async () => {
      throw failure;
    };
    const onError = vi.fn();
    const controller = new FlareUpdateController({
      api,
      installer: { execute: async () => ({ outcome: "completed" }) },
      appState: null,
      subscribe: () => () => undefined,
      onError,
    });

    await expect(controller.loadResources()).resolves.toEqual([]);
    expect(onError).toHaveBeenCalledWith(failure);
  });

  it("leaves the status alone, a failed read included", async () => {
    const { api, controller } = harness(status());
    await controller.start();
    api.resourcesAnswer = async () => {
      throw new Error("not initialized");
    };

    await controller.loadResources();

    expect(controller.status?.state).toBe("available");
    expect(controller.status?.error).toBeUndefined();
  });
});

describe("FlareUpdateController.dispose", () => {
  it("removes every subscription, stops polling and tells the installer", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] });
    const { api, controller, installer, stateListeners, loginListeners, appStateListeners } = harness(
      status({ state: "checking" }),
    );
    await controller.start();

    controller.dispose();
    await vi.advanceTimersByTimeAsync(5_000);

    expect(stateListeners.size + loginListeners.size + appStateListeners.size).toBe(0);
    expect(api.count("getState")).toBe(1);
    expect(installer.dispose).toHaveBeenCalledTimes(1);
  });
});
