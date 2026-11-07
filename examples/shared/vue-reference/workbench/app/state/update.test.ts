import { beforeEach, describe, expect, it, vi } from "vitest";
import type { UpdateStatus } from "@flare-im/sdk/model";
import type { FlareUpdateInstaller } from "@flare-im/sdk/update";
import { applyFlareResourceOverlay } from "@flare-im/vue-ui/i18n";
import { createUpdateState } from "./update";

vi.mock("@flare-im/vue-ui/i18n", () => ({ applyFlareResourceOverlay: vi.fn() }));

const applyOverlay = vi.mocked(applyFlareResourceOverlay);

beforeEach(() => {
  applyOverlay.mockReset();
});

const pack = { id: "app-strings", kind: "strings", packVersion: 3, contentJson: "{}" };

const status =(overrides: Partial<UpdateStatus> = {}): UpdateStatus => ({
  state: "available",
  current: { version: "1.0.0", build: 1, channel: "stable", distribution: "web" },
  release: {
    releaseId: "rel_1",
    version: "2.0.0",
    build: 2,
    notes: [],
    mandatory: false,
    recommended: false,
    kind: "webBundle",
  },
  prompt: "sheet",
  blockUi: false,
  readOnly: false,
  ...overrides,
});

function fakeClient(initial: UpdateStatus) {
  let current = initial;
  const listeners: Array<(status: UpdateStatus) => void> = [];
  const answer = async () => current;
  const update = {
    getState: vi.fn(answer),
    setLocale: vi.fn(answer),
    check: vi.fn(answer),
    download: vi.fn(answer),
    install: vi.fn(async () => ({ kind: "activateWebBundle" })),
    reportInstall: vi.fn(answer),
    defer: vi.fn(answer),
    skip: vi.fn(answer),
    markPrompted: vi.fn(answer),
    getResources: vi.fn(async (): Promise<unknown> => ({ packs: [pack] })),
  };
  const events = {
    onUpdateState: vi.fn((listener: (status: UpdateStatus) => void) => {
      listeners.push(listener);
      return { unsubscribe: () => undefined };
    }),
    onLoginSucceeded: vi.fn(() => ({ unsubscribe: () => undefined })),
  };
  return {
    client: { update, events } as never,
    update,
    set: (next: UpdateStatus) => { current = next; },
    emit: (next: UpdateStatus) => { for (const listener of listeners) listener(next); },
  };
}

const installer: FlareUpdateInstaller = { execute: async () => ({ outcome: "completed" }) };

describe("the update state", () => {
  it("reads the state at start and follows update://state", async () => {
    const fake = fakeClient(status());
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });

    await state.start();
    expect(state.promptView.value?.form).toBe("sheet");

    fake.emit(status({ prompt: "badge" }));
    expect(state.promptView.value).toBeNull();
    expect(state.badge.value).toBe(true);
  });

  it("has no update center on a host with no installer", async () => {
    const fake = fakeClient(status());
    const state = createUpdateState({ client: fake.client });

    await state.start();

    expect(state.available).toBe(false);
    expect(fake.update.getState).not.toHaveBeenCalled();
  });

  it("starts by itself after a refused sign-in, and reads the refusal", async () => {
    const fake = fakeClient(status({ state: "required", readOnly: true, prompt: "modal", release: undefined }));
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });

    state.refresh();

    await vi.waitFor(() => expect(state.readOnly.value).toBe(true));
  });

  it("can start again after the SDK was not ready", async () => {
    const fake = fakeClient(status());
    fake.update.getState.mockRejectedValueOnce(new Error("call init first"));
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });

    await state.start();
    expect(state.status.value).toBeNull();

    await state.start();
    expect(state.status.value?.state).toBe("available");
  });

  it("hands the app's language over, also one it heard before it started", async () => {
    const fake = fakeClient(status());
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });

    state.setLocale("zh-CN");
    expect(fake.update.setLocale).not.toHaveBeenCalled();

    await state.start();
    await vi.waitFor(() => expect(fake.update.setLocale).toHaveBeenCalledWith({ locale: "zh-CN" }));

    state.setLocale("en-US");
    await vi.waitFor(() => expect(fake.update.setLocale).toHaveBeenLastCalledWith({ locale: "en-US" }));
  });

  it("tells the installer whether the composer holds text", async () => {
    const fake = fakeClient(status());
    let isInputEmpty: () => boolean = () => false;
    const state = createUpdateState({
      client: fake.client,
      createInstaller: (empty) => {
        isInputEmpty = empty;
        return installer;
      },
      onError: () => undefined,
    });
    await state.start();

    expect(isInputEmpty()).toBe(true);
    state.composerHasText.value = true;
    expect(isInputEmpty()).toBe(false);
  });

  it("offers the fallback only with an address and a way to open it", async () => {
    const error = { code: "update.installFailed", retryable: true, fallbackUrl: "https://example.com/get" };
    const fake = fakeClient(status({ error }));
    const openUrl = vi.fn();
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, openUrl, onError: () => undefined });
    await state.start();

    state.openFallback();
    expect(openUrl).toHaveBeenCalledWith("https://example.com/get");

    const unopenable = createUpdateState({ client: fakeClient(status({ error })).client, createInstaller: () => installer, onError: () => undefined });
    await unopenable.start();
    expect(unopenable.fallbackUrl.value).toBeUndefined();
  });

  it("hands this run's packs to the kit and keeps them for the host", async () => {
    const fake = fakeClient(status());
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });

    await state.start();
    await vi.waitFor(() => expect(applyOverlay).toHaveBeenCalledWith([pack]));

    expect(state.resourcePacks.value).toEqual([pack]);
  });

  it("does not hold the start up for the packs", async () => {
    const fake = fakeClient(status());
    fake.update.getResources.mockImplementationOnce(() => new Promise(() => undefined));
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });

    await state.start();

    expect(state.status.value?.state).toBe("available");
    expect(applyOverlay).not.toHaveBeenCalled();
  });

  it("reads the packs once, however often sign-out restarts it", async () => {
    const fake = fakeClient(status());
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });
    await state.start();
    await vi.waitFor(() => expect(applyOverlay).toHaveBeenCalledTimes(1));

    state.restart();
    await state.start();

    expect(fake.update.getState).toHaveBeenCalledTimes(2);
    expect(fake.update.getResources).toHaveBeenCalledTimes(1);
    expect(applyOverlay).toHaveBeenCalledTimes(1);
  });

  it("goes on with the built-in look when the packs cannot be read", async () => {
    const fake = fakeClient(status());
    const failure = new Error("not initialized");
    fake.update.getResources.mockRejectedValueOnce(failure);
    const onError = vi.fn();
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError });

    await state.start();

    await vi.waitFor(() => expect(onError).toHaveBeenCalledWith(failure));
    expect(state.status.value?.state).toBe("available");
    expect(state.resourcePacks.value).toEqual([]);
    expect(applyOverlay).not.toHaveBeenCalled();
  });

  it("leaves the kit alone when this run has no packs", async () => {
    const fake = fakeClient(status());
    fake.update.getResources.mockResolvedValueOnce({ packs: [] });
    const state = createUpdateState({ client: fake.client, createInstaller: () => installer, onError: () => undefined });

    await state.start();
    await vi.waitFor(() => expect(fake.update.getResources).toHaveBeenCalledTimes(1));

    expect(applyOverlay).not.toHaveBeenCalled();
  });

  it("reads no packs on a host with no update center", async () => {
    const fake = fakeClient(status());
    const state = createUpdateState({ client: fake.client });

    await state.start();

    expect(fake.update.getResources).not.toHaveBeenCalled();
  });
});
