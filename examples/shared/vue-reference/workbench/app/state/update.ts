/**
 * The update center as this app's Vue state: `FlareUpdateController` on `client.update`. What to show, when and in which
 * form is the core's and the controller's; here it only becomes refs and callbacks that cannot reject.
 *
 * Where to connect is the build's, so the sign-in page initializes the SDK and starts the controller; a saved session
 * starts it on its way in. Starting also hands this run's resource packs to the kit.
 */
import { computed, inject, provide, ref, shallowRef, type InjectionKey } from "vue";
import type { FlareImClient } from "@flare-im/sdk/api";
import type { UpdateResourcePack, UpdateStatus } from "@flare-im/sdk/model";
import {
  FlareUpdateController,
  type FlareUpdateInstaller,
  type UpdatePromptForm,
  type UpdatePromptView,
} from "@flare-im/sdk/update";
import { applyFlareResourceOverlay } from "@flare-im/vue-ui/i18n";
import { productionAppHost } from "../infrastructure/sdk/createProductionAppClient";

export interface UpdateStateHost {
  client: Pick<FlareImClient, "update" | "events">;
  /** The platform's installer; without one there is no update center. */
  createInstaller?: (isInputEmpty: () => boolean) => FlareUpdateInstaller;
  /** Opens the failure prompt's other way out. */
  openUrl?: (url: string) => void | Promise<void>;
  onError?: (error: unknown) => void;
}

/** A manual check that failed is said on the page that asked; these are the kit's words for it. */
const CHECK_FAILURES: Readonly<Record<string, string>> = {
  "update.manifestUnavailable": "updatePrompt.failManifestUnavailable",
  "update.manifestRejected": "updatePrompt.failManifestRejected",
};

export function createUpdateState({ client, createInstaller, openUrl, onError = (error) => console.warn("[update]", error) }: UpdateStateHost) {
  const status = shallowRef<UpdateStatus | null>(null);
  const promptView = shallowRef<UpdatePromptView | null>(null);
  const resourcePacks = shallowRef<readonly UpdateResourcePack[]>([]);
  const composerHasText = ref(false);
  const readOnly = computed(() => status.value?.readOnly === true);
  const badge = computed(() => status.value?.prompt === "badge");
  const fallbackUrl = computed(() => (openUrl ? status.value?.error?.fallbackUrl : undefined));
  const checkFailure = computed(() => CHECK_FAILURES[status.value?.error?.code ?? ""] ?? null);

  let controller: FlareUpdateController | null = null;
  let starting: Promise<void> | null = null;
  /** The app's language, kept for a controller that is not running yet. */
  let locale: string | null = null;
  /** The core's packs hold for the whole run, so `restart()` has nothing to read again. */
  let resourcesRead = false;

  function show(from: FlareUpdateController): void {
    status.value = from.status;
    promptView.value = from.promptView;
  }

  function applyLocale(): void {
    const current = locale;
    if (current !== null) run((running) => running.setLocale(current));
  }

  /** The built-in look renders first and the kit swaps the overlay in when it arrives. What it took is for the log. */
  async function applyResources(from: FlareUpdateController): Promise<void> {
    if (resourcesRead) return;
    resourcesRead = true;
    const packs = await from.loadResources();
    if (packs.length === 0) return;
    resourcePacks.value = packs;
    console.info("[update] resource overlay", applyFlareResourceOverlay(packs));
  }

  async function begin(installer: FlareUpdateInstaller): Promise<void> {
    const next = new FlareUpdateController({
      api: client.update,
      subscribe: (listener) => client.events.onUpdateState(listener),
      loginSucceeded: (listener) => client.events.onLoginSucceeded(listener),
      installer,
      onError,
    });
    next.subscribe(() => show(next));
    try {
      await next.start();
    } catch (error) {
      next.dispose();
      throw error;
    }
    controller = next;
    show(next);
    applyLocale();
    void applyResources(next);
  }

  /** Repeat calls share the first; one that failed can be made again. */
  function start(): Promise<void> {
    if (!createInstaller) return Promise.resolve();
    starting ??= begin(createInstaller(() => !composerHasText.value)).catch((error: unknown) => {
      starting = null;
      onError(error);
    });
    return starting;
  }

  function run(action: (running: FlareUpdateController) => Promise<unknown>): void {
    if (controller) action(controller).catch(onError);
  }

  return {
    /** False on a host with no installer. */
    available: Boolean(createInstaller),
    status,
    /** The open prompt under the kit's prop names; null while none is open. */
    promptView,
    /** Local conversations stay readable, the composer does not send. */
    readOnly,
    /** A version is on offer without a prompt: a dot on the way to the About page. */
    badge,
    /** The failure prompt's other way out; absent on the web, where the kit then draws no such button. */
    fallbackUrl,
    /** The kit's key for why the check the person asked for failed. */
    checkFailure,
    /** This run's packs. The kit has taken its kinds; it draws no help page, so a `help` pack's `contentJson` is the host's. */
    resourcePacks,
    /** Whether the chat composer holds text: a forced web update only reloads a page with none. */
    composerHasText,
    start,
    /** Sign-out drops every event subscription, the controller's too: a running one listens again. */
    restart: () => {
      if (!controller) return;
      controller.dispose();
      controller = null;
      starting = null;
      void start();
    },
    /** Reads the state again: a refused sign-in leaves no session for `update://state` to arrive on. */
    refresh: () => {
      void start().then(() => run((running) => running.refresh()));
    },
    check: () => run((running) => running.check()),
    update: () => run((running) => running.update()),
    later: () => run((running) => running.later()),
    skip: () => run((running) => running.skip()),
    continueReadOnly: () => run((running) => running.continueReadOnly()),
    /** Call when the prompt really opened: the frequency rules count on it. */
    markPrompted: (form: UpdatePromptForm) => run((running) => running.markPrompted(form)),
    /** The app's language, at start and whenever it changes; a call before `start()` is kept for it. */
    setLocale: (next: string) => {
      locale = next;
      applyLocale();
    },
    openFallback: () => {
      const url = fallbackUrl.value;
      if (url && openUrl) Promise.resolve(openUrl(url)).catch(onError);
    },
  };
}

export type FlareUpdates = ReturnType<typeof createUpdateState>;

const flareUpdatesKey: InjectionKey<FlareUpdates> = Symbol("flare-updates");

/** The app's update center, for `useFlareUpdates` below it. Starts with `start()`, once the SDK is initialized. */
export function provideFlareUpdates(client: FlareImClient): FlareUpdates {
  const { createUpdateInstaller, openUrl } = productionAppHost();
  const updates = createUpdateState({
    client,
    createInstaller: createUpdateInstaller && ((isInputEmpty) => createUpdateInstaller(client, isInputEmpty)),
    openUrl,
  });
  provide(flareUpdatesKey, updates);
  return updates;
}

export function useFlareUpdates(): FlareUpdates {
  const updates = inject(flareUpdatesKey);
  if (!updates) throw new Error("The update center is missing. Mount provideFlareUpdates() in App.vue.");
  return updates;
}
