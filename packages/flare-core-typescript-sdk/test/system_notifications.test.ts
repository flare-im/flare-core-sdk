import fs from "node:fs";
import path from "node:path";

import { describe, expect, it, vi } from "vitest";

import {
  FLARE_NOTIFICATION_CLICK,
  browserNotificationPresenter,
  handleFlareNotificationClick,
  startSystemNotifications,
  type BrowserNotificationOptions,
  type BrowserNotificationRegistration,
  type BrowserServiceWorkerContainer,
  type FlareNotificationClickMessage,
  type FlareNotificationClickScope,
  type FlareNotificationWindowClient,
  type NotificationEventSource,
  type NotificationPresenter,
  type NotificationTarget,
} from "../src/notifications";
import type { NotificationClearEvent } from "../src/model/notification_clear_event";
import type { NotificationPresentation } from "../src/model/notification_presentation";

function presentation(overrides: Partial<NotificationPresentation> = {}): NotificationPresentation {
  return {
    collapseId: "c:1",
    threadId: "c:1",
    conversationId: "conv-1",
    messageId: "m-9",
    seq: 42,
    title: "Ann",
    body: "hi",
    count: 1,
    sound: true,
    channel: "messages",
    surface: "system",
    ...overrides,
  } as NotificationPresentation;
}

/** An event source like `client.events`: listeners kept until their subscription is undone. */
class Source implements NotificationEventSource {
  readonly presents = new Set<(presentation: NotificationPresentation) => void>();
  readonly clears = new Set<(event: NotificationClearEvent) => void>();

  onNotificationPresent(listener: (presentation: NotificationPresentation) => void) {
    this.presents.add(listener);
    return { unsubscribe: () => void this.presents.delete(listener) };
  }

  onNotificationClear(listener: (event: NotificationClearEvent) => void) {
    this.clears.add(listener);
    return { unsubscribe: () => void this.clears.delete(listener) };
  }

  present(value: NotificationPresentation) {
    for (const listener of this.presents) listener(value);
  }

  clear(value: NotificationClearEvent) {
    for (const listener of this.clears) listener(value);
  }
}

/** A presenter that records what it was asked to do. */
class Recorder implements NotificationPresenter {
  readonly calls: string[] = [];
  readonly activations = new Map<string, () => void>();

  permission() {
    return "granted" as const;
  }

  async requestPermission() {
    this.calls.push("request");
    return "granted" as const;
  }

  show(notification: NotificationPresentation, activate: () => void) {
    this.calls.push(`show:${notification.collapseId}:${notification.sound}`);
    this.activations.set(notification.collapseId, activate);
  }

  close(collapseIds: readonly string[]) {
    this.calls.push(`close:${collapseIds.join(",")}`);
  }

  closeAll() {
    this.calls.push("closeAll");
  }

  focus() {
    this.calls.push("focus");
  }
}

/** A presenter that also hears clicks on its own, as the browser one does through a Service Worker. */
class ClickRecorder extends Recorder {
  readonly clicks = new Set<(target: NotificationTarget) => void>();

  onActivate(listener: (target: NotificationTarget) => void) {
    this.clicks.add(listener);
    return () => void this.clicks.delete(listener);
  }

  click(target: NotificationTarget) {
    for (const listener of this.clicks) listener(target);
  }
}

describe("startSystemNotifications", () => {
  it("shows system presentations, leaves in-app ones to the banner and takes them down on clear", () => {
    const source = new Source();
    const presenter = new Recorder();
    startSystemNotifications(source, { presenter });

    source.present(presentation());
    source.present(presentation({ collapseId: "c:2", surface: "inApp" }));
    source.present(presentation({ collapseId: "c:3", title: "", body: "" }));
    source.clear({ collapseIds: ["c:1"], all: false } as NotificationClearEvent);
    source.clear({ collapseIds: [], all: true } as NotificationClearEvent);

    expect(presenter.calls).toEqual(["show:c:1:true", "close:c:1", "closeAll"]);
  });

  it("brings the window forward and opens the conversation on a click", async () => {
    const source = new Source();
    const presenter = new Recorder();
    const opened: unknown[] = [];
    startSystemNotifications(source, { presenter, onOpen: (target) => opened.push(target) });

    source.present(presentation());
    source.present(presentation({ collapseId: "d:digest", conversationId: "", messageId: "", seq: 0 }));
    presenter.activations.get("c:1")!();
    presenter.activations.get("d:digest")!();
    await vi.waitFor(() => expect(opened).toHaveLength(1));
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(presenter.calls.filter((call) => call === "focus")).toHaveLength(2);
    expect(opened).toEqual([{ conversationId: "conv-1", messageId: "m-9" }]);
  });

  it("opens the conversation of a click the presenter hears on its own, until stopped", async () => {
    const source = new Source();
    const presenter = new ClickRecorder();
    const opened: unknown[] = [];
    const notifications = startSystemNotifications(source, { presenter, onOpen: (target) => opened.push(target) });

    presenter.click({ conversationId: "conv-7", messageId: "m-1" });
    await vi.waitFor(() => expect(opened).toHaveLength(1));
    notifications.stop();

    expect(presenter.clicks.size).toBe(0);
    expect(presenter.calls).toContain("focus");
    expect(opened).toEqual([{ conversationId: "conv-7", messageId: "m-1" }]);
  });

  it("stops listening and takes down what it showed", () => {
    const source = new Source();
    const presenter = new Recorder();
    const notifications = startSystemNotifications(source, { presenter });

    notifications.stop();
    notifications.stop();
    source.present(presentation());

    expect(source.presents.size).toBe(0);
    expect(source.clears.size).toBe(0);
    expect(presenter.calls).toEqual(["closeAll"]);
  });

  it("takes sources whose registrations resolve later, also when stopped before they do", async () => {
    let releaseSource!: () => void;
    const gate = new Promise<void>((resolve) => {
      releaseSource = resolve;
    });
    const removed: string[] = [];
    const source: NotificationEventSource = {
      onNotificationPresent: async () => {
        await gate;
        return () => removed.push("present");
      },
      onNotificationClear: async () => {
        await gate;
        return () => removed.push("clear");
      },
    };
    const notifications = startSystemNotifications(source, { presenter: new Recorder() });

    notifications.stop();
    releaseSource();
    await vi.waitFor(() => expect(removed.sort()).toEqual(["clear", "present"]));
  });

  it("reports presenter failures instead of throwing them", async () => {
    const source = new Source();
    const errors: unknown[] = [];
    const presenter = new Recorder();
    presenter.show = () => {
      throw new Error("no notification service");
    };
    presenter.closeAll = async () => {
      throw new Error("gone");
    };
    const notifications = startSystemNotifications(source, { presenter, onError: (error) => errors.push(error) });

    source.present(presentation());
    source.clear({ collapseIds: [], all: true } as NotificationClearEvent);
    await vi.waitFor(() => expect(errors).toHaveLength(2));
    expect(await notifications.permission()).toBe("granted");
    expect(await notifications.requestPermission()).toBe("granted");
  });
});

describe("browserNotificationPresenter", () => {
  function fakeNotificationApi(permission: string) {
    const created: Array<{ title: string; options: BrowserNotificationOptions; closed: boolean; instance: any }> = [];
    class FakeNotification {
      static permission = permission;
      static requestPermission = vi.fn(async () => {
        FakeNotification.permission = "granted";
        return "granted";
      });
      onclick: ((event: any) => void) | null = null;
      onclose: ((event: any) => void) | null = null;
      private readonly record: (typeof created)[number];

      constructor(title: string, options: BrowserNotificationOptions = {}) {
        this.record = { title, options, closed: false, instance: this };
        created.push(this.record);
      }

      close() {
        this.record.closed = true;
        this.onclose?.({});
      }
    }
    return { api: FakeNotification, created };
  }

  it("tags by collapse id, renotifies only with a sound and closes by collapse id", () => {
    const { api, created } = fakeNotificationApi("granted");
    const presenter = browserNotificationPresenter({ notification: api, window: null, icon: "/icon.png" });

    presenter.show(presentation(), () => undefined);
    presenter.show(presentation({ sound: false, body: "two new" }), () => undefined);
    presenter.show(presentation({ collapseId: "c:2", conversationId: "conv-2" }), () => undefined);

    expect(created.map(({ title, options }) => [title, options.tag, options.renotify, options.silent])).toEqual([
      ["Ann", "c:1", true, false],
      ["Ann", "c:1", false, true],
      ["Ann", "c:2", true, false],
    ]);
    expect(created[0]!.options.icon).toBe("/icon.png");
    expect(created[1]!.options.body).toBe("two new");

    presenter.close(["c:1"]);
    expect(created.map(({ closed }) => closed)).toEqual([false, true, false]);
    presenter.closeAll();
    expect(created[2]!.closed).toBe(true);
  });

  it("closes the clicked notification, activates and focuses the window", async () => {
    const { api, created } = fakeNotificationApi("granted");
    const focus = vi.fn();
    const presenter = browserNotificationPresenter({ notification: api, window: { focus } });
    const activate = vi.fn();

    presenter.show(presentation(), activate);
    created[0]!.instance.onclick({});
    await presenter.focus?.();

    expect(created[0]!.closed).toBe(true);
    expect(activate).toHaveBeenCalledOnce();
    expect(focus).toHaveBeenCalledOnce();
  });

  it("shows nothing without the permission and asks only while undecided", async () => {
    const { api, created } = fakeNotificationApi("default");
    const presenter = browserNotificationPresenter({ notification: api, window: null });

    expect(presenter.permission()).toBe("prompt");
    presenter.show(presentation(), () => undefined);
    expect(created).toHaveLength(0);
    expect(await presenter.requestPermission()).toBe("granted");
    expect(await presenter.requestPermission()).toBe("granted");
    expect(api.requestPermission).toHaveBeenCalledOnce();

    const none = browserNotificationPresenter({ notification: null, window: null });
    expect(none.permission()).toBe("unsupported");
    expect(await none.requestPermission()).toBe("unsupported");
  });

  /** A Service Worker controlling the page: its registration's notifications and the messages it posts. */
  function fakeWorker() {
    const shown: Array<{ title: string; options: BrowserNotificationOptions; closed: boolean }> = [];
    const registration: BrowserNotificationRegistration = {
      async showNotification(title, options = {}) {
        // A notification with the same tag replaces the shown one.
        for (const entry of shown) if (options.tag && entry.options.tag === options.tag) entry.closed = true;
        shown.push({ title, options, closed: false });
      },
      async getNotifications(filter = {}) {
        return shown
          .filter((entry) => !entry.closed && (filter.tag === undefined || entry.options.tag === filter.tag))
          .map((entry) => ({ close: () => void (entry.closed = true) }));
      },
    };
    const listeners: Array<(event: { data: unknown }) => void> = [];
    const container: BrowserServiceWorkerContainer = {
      controller: {},
      ready: Promise.resolve(registration),
      addEventListener: (_type, listener) => void listeners.push(listener),
    };
    const post = (data: unknown) => listeners.forEach((listener) => listener({ data }));
    return { shown, container, post };
  }

  it("shows through the worker while one controls the page and closes by tag", async () => {
    const { api, created } = fakeNotificationApi("granted");
    const worker = fakeWorker();
    const presenter = browserNotificationPresenter({
      notification: api,
      serviceWorker: worker.container,
      window: null,
      icon: "/icon.png",
    });

    await presenter.show(presentation(), () => undefined);
    await presenter.show(presentation({ sound: false, body: "two new" }), () => undefined);
    await presenter.show(presentation({ collapseId: "c:2", conversationId: "conv-2" }), () => undefined);

    expect(created).toHaveLength(0);
    expect(worker.shown.map(({ title, options }) => [title, options.tag, options.renotify, options.silent])).toEqual([
      ["Ann", "c:1", true, false],
      ["Ann", "c:1", false, true],
      ["Ann", "c:2", true, false],
    ]);
    expect(worker.shown[0]!.options.data).toEqual({ conversationId: "conv-1", messageId: "m-9" });
    expect(worker.shown[0]!.options.icon).toBe("/icon.png");

    await presenter.close(["c:1"]);
    expect(worker.shown.map(({ closed }) => closed)).toEqual([true, true, false]);
    await presenter.closeAll();
    expect(worker.shown[2]!.closed).toBe(true);
  });

  it("keeps to the constructor while no worker controls the page", async () => {
    const { api, created } = fakeNotificationApi("granted");
    const worker = fakeWorker();
    const uncontrolled: BrowserServiceWorkerContainer = { ...worker.container, controller: null };

    await browserNotificationPresenter({ notification: api, serviceWorker: uncontrolled, window: null })
      .show(presentation(), () => undefined);
    const constructorOnly = { notification: api, serviceWorker: worker.container, registration: null, window: null };
    await browserNotificationPresenter(constructorOnly).show(presentation(), () => undefined);

    expect(created).toHaveLength(2);
    expect(worker.shown).toHaveLength(0);
  });

  it("runs a worker's click as its notification's activate, or hands it to the listeners", async () => {
    const { api } = fakeNotificationApi("granted");
    const worker = fakeWorker();
    const presenter = browserNotificationPresenter({
      notification: api,
      serviceWorker: worker.container,
      window: null,
    });
    const activate = vi.fn();
    const heard: NotificationTarget[] = [];
    const stop = presenter.onActivate!((target) => heard.push(target));

    await presenter.show(presentation(), activate);
    worker.post({ type: FLARE_NOTIFICATION_CLICK, collapseId: "c:1", conversationId: "conv-1", messageId: "m-9" });
    // One an earlier page showed.
    worker.post({ type: FLARE_NOTIFICATION_CLICK, collapseId: "c:7", conversationId: "conv-7" });
    worker.post({ type: "flare-update:skip-waiting" });
    stop();
    worker.post({ type: FLARE_NOTIFICATION_CLICK, collapseId: "c:8", conversationId: "conv-8" });

    expect(activate).toHaveBeenCalledOnce();
    expect(heard).toEqual([{ conversationId: "conv-7" }]);
  });
});

describe("handleFlareNotificationClick", () => {
  class WindowClient implements FlareNotificationWindowClient {
    readonly messages: FlareNotificationClickMessage[] = [];
    focused = 0;

    constructor(readonly url: string) {}

    async focus() {
      this.focused += 1;
    }

    postMessage(message: FlareNotificationClickMessage) {
      this.messages.push(message);
    }
  }

  function workerScope(windows: WindowClient[]) {
    const opened: string[] = [];
    const scope: FlareNotificationClickScope = {
      registration: { scope: "https://chat.example/app/" },
      clients: {
        matchAll: async () => windows,
        openWindow: async (url) => {
          opened.push(url);
          return null;
        },
      },
    };
    return { scope, opened };
  }

  function clickEvent(tag: string, data: unknown) {
    const work: Promise<unknown>[] = [];
    const notification = { tag, data, close: vi.fn() };
    return { event: { notification, waitUntil: (done: Promise<unknown>) => void work.push(done) }, notification, work };
  }

  it("closes the notification, posts the click to the app's window and brings it to the front", async () => {
    const other = new WindowClient("https://chat.example/admin/");
    const app = new WindowClient("https://chat.example/app/#/chat");
    const { scope, opened } = workerScope([other, app]);
    const { event, notification, work } = clickEvent("c:1", { conversationId: "conv-1", messageId: "m-9" });

    expect(handleFlareNotificationClick(event, { scope })).toBe(true);
    await Promise.all(work);

    expect(notification.close).toHaveBeenCalledOnce();
    expect(app.messages).toEqual([
      { type: FLARE_NOTIFICATION_CLICK, collapseId: "c:1", conversationId: "conv-1", messageId: "m-9" },
    ]);
    expect(app.focused).toBe(1);
    expect(other.messages).toEqual([]);
    expect(opened).toEqual([]);
  });

  it("opens the app when none of its windows is open", async () => {
    const { scope, opened } = workerScope([]);
    const { event, work } = clickEvent("d:digest", { conversationId: "", messageId: "" });

    expect(handleFlareNotificationClick(event, { scope })).toBe(true);
    await Promise.all(work);

    expect(opened).toEqual(["https://chat.example/app/"]);
  });

  it("leaves the worker's other notifications to the worker", () => {
    const { scope } = workerScope([]);
    const { event, notification, work } = clickEvent("promo", { campaign: 3 });

    expect(handleFlareNotificationClick(event, { scope })).toBe(false);
    expect(handleFlareNotificationClick(new Event("notificationclick"), { scope })).toBe(false);
    expect(notification.close).not.toHaveBeenCalled();
    expect(work).toHaveLength(0);
  });
});

describe("@flare-im/sdk/notifications subpath", () => {
  it("is exported from the package and imports only its own files and models", () => {
    const root = process.cwd();
    const manifest = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8")) as {
      exports: Record<string, unknown>;
    };
    expect(manifest.exports["./notifications"]).toBe("./src/notifications/index.ts");

    const directory = path.join(root, "src/notifications");
    for (const file of fs.readdirSync(directory).filter((name) => name.endsWith(".ts"))) {
      // Code only: the usage example in a doc comment (`from "@flare-im/sdk/notifications"`) is not an import.
      const source = fs
        .readFileSync(path.join(directory, file), "utf8")
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .replace(/^\s*\/\/.*$/gm, "");
      for (const match of source.matchAll(/from\s+["']([^"']+)["']/g)) {
        const specifier = match[1]!;
        expect(specifier.startsWith("./") || specifier.startsWith("../model/"), `${file}: ${specifier}`).toBe(true);
      }
    }
  });
});
