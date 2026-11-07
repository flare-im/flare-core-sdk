import { describe, expect, it, vi } from "vitest";

import type { UpdateDesktopUpdaterPlan } from "./model";
import { createTauriUpdateInstaller, type TauriUpdateDownloadEvent, type TauriUpdateHandle } from "./tauriUpdateInstaller";
import { recordingContext, until } from "./testing/fakes";
import { FlareUpdateController } from "./updateController";

const plan: UpdateDesktopUpdaterPlan = {
  kind: "desktopUpdater",
  version: "2.4.0",
  target: "darwin-aarch64",
  sha256: "aa",
};

function handle(version = "2.4.0", events: TauriUpdateDownloadEvent[] = []) {
  const update = {
    version,
    downloadAndInstall: vi.fn(async (onEvent?: (event: TauriUpdateDownloadEvent) => void) => {
      for (const event of events) onEvent?.(event);
    }),
    close: vi.fn(async () => undefined),
  };
  return update satisfies TauriUpdateHandle;
}

describe("createTauriUpdateInstaller", () => {
  it("asks the updater and installs the planned version", async () => {
    const update = handle();
    const check = vi.fn(async () => update);
    const installer = createTauriUpdateInstaller({ check });

    const result = await installer.execute(plan, recordingContext().context);

    expect(result).toEqual({ outcome: "completed" });
    expect(check).toHaveBeenCalledTimes(1);
    expect(update.downloadAndInstall).toHaveBeenCalledTimes(1);
    expect(update.close).toHaveBeenCalledTimes(1);
  });

  it("refuses whatever else the updater endpoint offers", async () => {
    const newer = handle("2.5.0");
    const installer = createTauriUpdateInstaller({ check: async () => newer });

    const result = await installer.execute(plan, recordingContext().context);

    expect(result).toEqual({ outcome: "failed", code: "update.noArtifact" });
    expect(newer.downloadAndInstall).not.toHaveBeenCalled();
    expect(newer.close).toHaveBeenCalledTimes(1);
  });

  it("fails when the updater has nothing", async () => {
    const installer = createTauriUpdateInstaller({ check: async () => null });

    expect(await installer.execute(plan, recordingContext().context))
      .toEqual({ outcome: "failed", code: "update.noArtifact" });
  });

  it("reports an unreachable updater as a failed download", async () => {
    const onError = vi.fn();
    const installer = createTauriUpdateInstaller({
      check: async () => {
        throw new Error("offline");
      },
      onError,
    });

    expect(await installer.execute(plan, recordingContext().context))
      .toEqual({ outcome: "failed", code: "update.downloadFailed" });
    expect(onError).toHaveBeenCalledTimes(1);
  });

  it("reports a failed install, the updater's own signature check included", async () => {
    const update = handle();
    update.downloadAndInstall.mockRejectedValueOnce(new Error("signature"));
    const installer = createTauriUpdateInstaller({ check: async () => update });
    const { context, progress } = recordingContext();

    expect(await installer.execute(plan, context)).toEqual({ outcome: "failed", code: "update.installFailed" });
    expect(update.close).toHaveBeenCalledTimes(1);
    expect(progress).toEqual([null]);
  });

  it("does not let a failing close change the outcome", async () => {
    const update = handle();
    update.close.mockRejectedValueOnce(new Error("close"));
    const onError = vi.fn();
    const installer = createTauriUpdateInstaller({ check: async () => update, onError });

    expect((await installer.execute(plan, recordingContext().context)).outcome).toBe("completed");
    expect(onError).toHaveBeenCalledTimes(1);
  });

  it("turns the updater's events into progress, at most every 200 ms", async () => {
    vi.useFakeTimers({ toFake: ["Date"], now: 1_000 });
    const update = handle("2.4.0", [
      { event: "Started", data: { contentLength: 100 } },
      { event: "Progress", data: { chunkLength: 10 } },
      { event: "Progress", data: { chunkLength: 10 } },
      { event: "Finished" },
    ]);
    const installer = createTauriUpdateInstaller({ check: async () => update });
    const { context, progress } = recordingContext();

    await installer.execute(plan, context);
    vi.useRealTimers();

    expect(progress).toEqual([{ received: 0, total: 100 }, { received: 10, total: 100 }, null]);
  });

  it("relaunches only after the person confirms, and only after the report", async () => {
    const relaunch = vi.fn(async () => undefined);
    const installer = createTauriUpdateInstaller({ check: async () => handle(), relaunch });
    const { context, asked, answer } = recordingContext();

    const running = installer.execute(plan, context);
    await until(asked);
    expect(relaunch).not.toHaveBeenCalled();
    answer(true);
    const result = await running;

    expect(result.outcome).toBe("completed");
    expect(relaunch).not.toHaveBeenCalled();
    await result.finish?.();
    expect(relaunch).toHaveBeenCalledTimes(1);
  });

  it("leaves the restart for later when the person puts it off", async () => {
    const relaunch = vi.fn(async () => undefined);
    const installer = createTauriUpdateInstaller({ check: async () => handle(), relaunch });
    const { context, asked, answer } = recordingContext();

    const running = installer.execute(plan, context);
    await until(asked);
    answer(false);
    const result = await running;

    expect(result.outcome).toBe("completed");
    expect(result.finish).toBeUndefined();
    expect(relaunch).not.toHaveBeenCalled();
    await result.restart?.();
    expect(relaunch).toHaveBeenCalledTimes(1);
  });

  it("opens the store page of a store build, without touching the updater", async () => {
    const check = vi.fn(async () => handle());
    const openUrl = vi.fn(async () => undefined);
    const installer = createTauriUpdateInstaller({ check, openUrl });

    const result = await installer.execute(
      { kind: "openStore", store: "macappstore", url: "macappstore://apps.apple.com/app/id1" },
      recordingContext().context,
    );

    expect(result).toEqual({ outcome: "completed" });
    expect(openUrl).toHaveBeenCalledWith("macappstore://apps.apple.com/app/id1");
    expect(check).not.toHaveBeenCalled();
  });

  it("fails a store plan it cannot open", async () => {
    const onError = vi.fn();
    const failing = createTauriUpdateInstaller({
      check: async () => null,
      openUrl: async () => {
        throw new Error("no handler");
      },
      onError,
    });
    const withStore = { kind: "openStore", store: "msstore", url: "ms-windows-store://pdp/?ProductId=1" };

    expect(await failing.execute(withStore, recordingContext().context))
      .toEqual({ outcome: "failed", code: "update.installFailed" });
    expect(onError).toHaveBeenCalledTimes(1);

    const noOpener = createTauriUpdateInstaller({ check: async () => null });
    expect(await noOpener.execute(withStore, recordingContext().context))
      .toEqual({ outcome: "failed", code: "update.installFailed" });

    const noPage = createTauriUpdateInstaller({ check: async () => null, openUrl: vi.fn() });
    expect(await noPage.execute({ kind: "openStore", store: "msstore" }, recordingContext().context))
      .toEqual({ outcome: "failed", code: "update.installFailed" });
  });

  it("refuses a plan of another kind without touching the updater", async () => {
    const check = vi.fn(async () => handle());
    const installer = createTauriUpdateInstaller({ check });

    const result = await installer.execute(
      {
        kind: "activateWebBundle",
        buildId: "b2",
        assetManifestUrls: [],
        assetManifestSha256: "aa",
        mandatory: false,
        blockUi: false,
      },
      recordingContext().context,
    );

    expect(result).toEqual({ outcome: "failed", code: "update.installFailed" });
    expect(check).not.toHaveBeenCalled();
  });
});

describe("the updater under the controller", () => {
  const status = (state: string, release: unknown) => ({
    state,
    current: { version: "2.3.2", build: 20302, channel: "stable", distribution: "tauri" },
    release,
    prompt: "modal",
    blockUi: false,
    readOnly: false,
    lastCheckedAt: 1,
  });
  const release = {
    releaseId: "rel_1",
    version: "2.4.0",
    build: 20400,
    notes: [],
    sizeBytes: 1000,
    mandatory: false,
    recommended: false,
    kind: "desktop",
  };

  function controllerFor(answer: unknown, relaunch?: () => Promise<void>) {
    const check = vi.fn(async () => handle());
    const controller = new FlareUpdateController({
      api: {
        getState: async () => answer,
        setLocale: async () => answer,
        check: async () => answer,
        download: async () => answer,
        install: async () => plan,
        reportInstall: async () => answer,
        defer: async () => answer,
        skip: async () => answer,
        markPrompted: async () => answer,
        getResources: async () => ({ packs: [] }),
      },
      installer: createTauriUpdateInstaller({ check, relaunch }),
      appState: null,
      subscribe: () => () => undefined,
    });
    return { check, controller };
  }

  it("calls the updater when the core says available or required", async () => {
    for (const state of ["available", "required"]) {
      const { check, controller } = controllerFor(status(state, release));
      await controller.update();
      expect(check).toHaveBeenCalledTimes(1);
      controller.dispose();
    }
  });

  it("keeps the restart put off after the download, for the next update()", async () => {
    const relaunch = vi.fn(async () => undefined);
    const { check, controller } = controllerFor(status("available", release), relaunch);

    const running = controller.update();
    await until(() => controller.status?.state === "readyToInstall");
    await controller.later();
    await running;

    expect(controller.status?.state).toBe("readyToInstall");
    expect(relaunch).not.toHaveBeenCalled();

    await controller.update();

    expect(relaunch).toHaveBeenCalledTimes(1);
    expect(check).toHaveBeenCalledTimes(1);
    controller.dispose();
  });

  it("never calls the updater when the core says otherwise", async () => {
    for (const answer of [status("upToDate", null), status("checking", release), status("idle", null)]) {
      const { check, controller } = controllerFor(answer);
      await controller.update();
      expect(check).not.toHaveBeenCalled();
      controller.dispose();
    }
  });
});
