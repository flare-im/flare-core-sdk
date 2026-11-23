<script setup lang="ts">
defineOptions({ inheritAttrs: false });
/**
 * A plugin page (a wallet, a ledger) hosted on the core SDK: the kit's FlarePluginPage over `pluginPage`. The 我 entries
 * of plugins and the page targets of card actions open here.
 *
 * The page document, its source, paging, rows and actions are declared by the plugin and resolved by Core; this only
 * holds the filters and the page stack and forwards requests: the first page and a refresh (`refresh` with the shown
 * view), a next page (`page` with the cursor and the shown view, Core merges them), a filter (the first page with the
 * new values), a page action (`invokePageAction` with the view's `data` and the row's `row`, no message). A page target
 * an action opens is pushed with its own plugin; back pops it, and on the root page emits `back`. The kit asks for every
 * re-read (`refresh` with its reason, including after a clean action); a page uncovered by a pop shows its last view and
 * is re-read quietly, and a result page's done returns to the nearest overview or records page below it, re-read the
 * same way, or closes the pages without one (docs/plugin-experience.md R4, §12.1).
 * A page tab replaces the shown page with its sibling (rules.pageTabs), adding no back step. A page action's navigation
 * that names `run` runs that action of the pushed page once, as if tapped, after its first load (an operation without a
 * form, confirm or disabled reason); never on a refresh, a return or a tab.
 *
 * Host capabilities go through the engine (`invokeCapability`): a document input's key captures and uploads into it
 * (`documentCapture` with `into`), a location input's key writes one fix into it (`locationOnce` with `into`), a native
 * action writing into an input fills it the same way, and a payment order an operation returns is confirmed by the
 * host's confirmation (`paymentConfirmation`). The prompts themselves are the host's (`CorePluginCapabilityHost`).
 * Protected media read one item at a time through its declared (owner-scoped) action; the address lives only in
 * memory and is dropped with the page.
 */
import { computed, inject, onBeforeUnmount, ref, shallowRef, toRaw, watch, type Component } from "vue";
import {
  FlarePluginPage,
  FlareImagePreview,
  useFlareI18n,
  type FlarePluginFormError,
  type FlarePluginFileAction,
  type FlarePluginFileState,
  type FlarePluginPageAppearance,
  type FlarePluginPageKind,
  type FlarePluginPageRef,
  type FlarePluginPageActionPayload,
  type FlarePluginPageViewModel,
  type FlarePluginResolveUser,
  type FlarePluginMember,
  type FlarePluginQrRefresh,
  type FlarePluginProtectedMediaRead,
  type FlarePluginProtectedMediaState,
  flareDocumentFileName,
  flarePluginDoneTarget,
  flarePluginPageKind,
  flarePluginProtectedMediaUrl,
} from "@flare-im/vue-ui";
import {
  pluginManifestLocale,
  type NativePluginBridge,
  type PluginActionOutcome,
  type PluginCapabilityPageContext,
  type PluginPagePresentation,
  type PluginPlatform,
  type PluginUiPort,
  type PluginUiSession,
} from "@flare-im/sdk/plugin-ui";
import { pluginUiDirectoryKey, pluginUiHostKey, pluginUiNativeKey, type CorePluginErrorText, type CorePluginHost } from "./context";
import { useCorePluginUpgrade } from "./upgrade";
import { corePluginPageSession, pluginPagePostedCard, type CorePluginPageEntry, type CorePluginPagePromptPolicy } from "./pluginPage";
import CorePluginBundle from "./CorePluginBundle.vue";
import type { PluginPostedCard } from "./composerMenu";
import { PluginFileUploads, choosePluginFile, pluginFileSessionData } from "./pluginFileUploads";
import { takeCapturedPhoto, watchCapturedPhoto } from "./capturedPhotos";
import { protectedMediaPreview } from "./protectedMediaPreview";

const props = withDefaults(defineProps<{
  /** The page the stack starts from. */
  root: CorePluginPageEntry;
  visible?: boolean;
  encodePluginCode?: (pluginId: string, token: string) => Promise<string>;
  pageAppearance?: (page: FlarePluginPageRef) => FlarePluginPageAppearance;
  /** Trusted host UI composition; data and commands still use the resolved page session. */
  pageContent?: (page: FlarePluginPageRef, view: FlarePluginPageViewModel) => {component: Component; actionIds: readonly string[]} | undefined;
  /** Presentation-only mapping; commands remain owned by the original session. */
  mapPageView?: (page: FlarePluginPageRef, view: PluginPagePresentation) => PluginPagePresentation;
  /** Trusted host policy only: continue a user action into its guarded consent prompt. */
  promptOnNavigate?: CorePluginPagePromptPolicy;
  /** The core SDK's plugin port (the social SDK's `plugins`); nothing loads while it is null. */
  port: PluginUiPort | null;
  platform: PluginPlatform;
  /** Names and avatars of the people a page shows. */
  resolveUser?: FlarePluginResolveUser;
  /** The viewer's user id (the me tag in entries). */
  viewerId?: string;
  /** Choices already authorized by the host's member query, never a global people directory. */
  members?: FlarePluginMember[];
  membersLoading?: boolean;
  membersError?: string;
  membersRevision?: number;
  /** The conversation's group size counting the viewer (the host's own group data): the red packet page's 「本群共 N 人」. */
  memberCount?: number;
  onMemberSearch?: (query: string) => void;
  onMembersRetry?: () => void;
  /** The host's copy for a failed plugin call (`sdk.plugin.*`), as given to `provideCorePluginUi`. */
  errorText?: CorePluginErrorText;
  /** The host's line for a page that failed to load for any other reason. */
  loadFailedText: string;
  /** Upgrade notices and image blocks; defaults to the one provided above (`provideCorePluginHost`). */
  host?: CorePluginHost;
}>(), { visible: true });
const emit = defineEmits<{ surfaceHints: [hints: { secure: boolean; maxBrightness: boolean }]; back: []; posted: [card: PluginPostedCard, owner: CorePluginPageEntry] }>();

const directory = inject(pluginUiDirectoryKey, {});
const native = inject(pluginUiNativeKey, undefined);
const { t, locale } = useFlareI18n();
const providedHost = inject(pluginUiHostKey, undefined);
const pluginHost = (): CorePluginHost => props.host ?? providedHost ?? {};
/**
 * The bridge page actions run native targets on: the one provided above (`provideCorePluginNativeBridge`) and the
 * host's (`CorePluginHost.native`). With both, a capability runs on the bridge that lists it, the provided one first.
 */
function nativeBridge(): NativePluginBridge | undefined {
  const hosted = pluginHost().native;
  if (!native || !hosted || native === hosted) return native ?? hosted;
  return {
    capabilities: [...new Set([...native.capabilities, ...hosted.capabilities])],
    invoke: (capability, payload, context) =>
      ((native.capabilities as readonly string[]).includes(capability) ? native : hosted).invoke(capability, payload, context),
  };
}
/**
 * UI-only memory for each open page. Never persist credentials, authorization or command outcomes here. `kind` is what
 * a covered page is to a later done key (§12.1), from the view it showed; unknown (never covered with a view) is a task.
 */
const pageFrame = (entry: CorePluginPageEntry) => ({ ...entry, filters: {} as Record<string, unknown>, contentState: {} as Record<string, unknown>, kind: undefined as FlarePluginPageKind | undefined });
const stack = ref([pageFrame(props.root)]);
/** The view each covered page showed, so returning to it shows it at once and re-reads it quietly (R4 return). */
const coveredViews = new WeakMap<object, PluginPagePresentation>();
function cover(): void {
  if (!view.value) return;
  coveredViews.set(toRaw(top.value), view.value);
  top.value.kind = flarePluginPageKind(shownView.value, props.pageAppearance?.({ pluginId: top.value.pluginId, page: top.value.page }));
}
function clearContentState(): void { stack.value = stack.value.map(entry => ({ ...entry, contentState: {} })); }
/** An action to run once on a pushed page's first load: the host policy's (with its operation) or the navigation's `run`. */
let pendingPrompt: { owner: CorePluginPageEntry; entry: CorePluginPageEntry; session: PluginUiSession | null;
  actionId: string; operation?: string } | undefined;
// Reopening the same entry is a new presentation even when every route field is equal.
watch(() => props.root, (root) => { pendingPrompt = undefined; stack.value = [pageFrame(root)]; }, { flush: "sync" });
const top = computed(() => stack.value[stack.value.length - 1]);
function openPage(entry: CorePluginPageEntry, run?: string): void {
  const prompt = busyActionId.value && props.visible !== false
    ? props.promptOnNavigate?.({ root: props.root, from: top.value, to: entry }) ?? (run ? { actionId: run } : undefined) : undefined;
  // Returning to a workflow's status page finishes that route. Back must
  // not reopen its already submitted editor or authorization form.
  const route = (value: CorePluginPageEntry) => JSON.stringify([
    value.pluginId, value.page, value.conversationId ?? "", value.args ?? {},
  ]);
  const existing = stack.value.findIndex(value => route(value) === route(entry));
  if (existing < 0) cover();
  stack.value = existing >= 0 ? stack.value.slice(0, existing + 1) : [...stack.value, pageFrame(entry)];
  pendingPrompt = prompt ? { ...prompt, owner: props.root, entry: top.value, session: session.value } : undefined;
}
const session = shallowRef<PluginUiSession | null>(null);
watch([() => props.port, () => props.viewerId], ([port]) => {
  pendingPrompt = undefined;
  clearContentState();
  session.value?.reset();
  session.value = port
    ? corePluginPageSession(port, props.platform, () => pluginManifestLocale(locale.value), () => top.value,
      openPage, nativeBridge())
    : null;
}, { immediate: true });
watch(() => props.visible, visible => { if (visible === false) { pendingPrompt = undefined; actionTicket++; session.value?.reset(); busyActionId.value = undefined; clearProtectedMedia(); clearContentState(); } });

const view = shallowRef<PluginPagePresentation>();
const shownView = computed(() => view.value && (props.mapPageView?.({pluginId: top.value.pluginId, page: top.value.page}, view.value) ?? view.value));
/**
 * The declarative page is always read first; when it says a web bundle is offered to this client (`view.bundle`), the
 * page opens in the kit's bundle host instead, so a declarative page never shows an opening state. The entries the
 * bundle could not show (closed by the bridge, failing) draw the view already read.
 */
const bundles = computed(() => pluginHost().bundles);
const entryKey = (entry: CorePluginPageEntry) => `${entry.pluginId}\u0000${entry.page}\u0000${entry.route ?? ""}`;
const declarative = ref<ReadonlySet<string>>(new Set());
const bundleShown = computed(() => Boolean(bundles.value) && view.value?.bundle === true
  && !declarative.value.has(entryKey(top.value)));
function bundleFallback(): void {
  declarative.value = new Set([...declarative.value, entryKey(top.value)]);
}
/** A bundle's `ui.navigate`: a declarative page of its plugin, or another route of the same bundle. */
function bundleNavigate(target: { page?: string; arguments?: Record<string, unknown>; bundleRoute?: string }): void {
  const entry = top.value;
  cover();
  if (target.page) {
    stack.value = [...stack.value, pageFrame({ pluginId: entry.pluginId, page: target.page, title: entry.title,
      ...(entry.conversationId ? { conversationId: entry.conversationId } : {}), ...(target.arguments ? { args: target.arguments } : {}) })];
  } else if (target.bundleRoute) {
    stack.value = [...stack.value, pageFrame({ ...entry, route: target.bundleRoute, ...(target.arguments ? { args: target.arguments } : {}) })];
  }
}
// A page this build cannot draw (D-18): the whole-page notice asks whether the build it needs is offered here.
const upgrade = useCorePluginUpgrade(() => view.value, pluginHost);
const loading = ref(false);
const refreshing = ref(false);
const loadingMore = ref(false);
const error = ref("");
const paginationError = ref("");
const pagingToken = ref(0);
const busyActionId = ref<string>();
const actionError = ref("");
const formErrors = shallowRef<FlarePluginFormError[]>([]);
const settleToken = ref(0);
let generation = 0;
let fileIdentity: object = {};
let paginationTicket = 0;
let actionTicket = 0;
const fileStates = shallowRef<Record<string, FlarePluginFileState>>({});
const filePreview = shallowRef<{ url: string; name: string }>();
const fileUploads = new PluginFileUploads({
  context: () => props.port && top.value ? {
    identity: fileIdentity,
    port: props.port,
    page: { pluginId: top.value.pluginId, page: top.value.page },
    platform: props.platform,
    locale: pluginManifestLocale(locale.value),
    conversationId: top.value.conversationId,
    arguments: top.value.args,
    // Only the displayed session fence is needed; Core re-reads page data.
    data: pluginFileSessionData(view.value?.data),
  } : null,
  changed: (states) => { fileStates.value = states; },
  choose: choosePluginFile,
  failure: (kind) => t(kind === "policy" ? "pluginFileRejected" : "pluginFileFailed"),
  preview: (url, name) => { filePreview.value = { url, name }; },
});
function clearFiles(): void {
  fileIdentity = {};
  filePreview.value = undefined;
  fileUploads.clear();
}
function fileAction(event: FlarePluginFileAction): void {
  if (busyActionId.value) return;
  if (event.action !== "preview") filePreview.value = undefined;
  // A document is captured by the host and uploaded by the engine into the input; everything else is the picker's.
  const side = event.input.side;
  if (event.input.kind === "document" && side && ["choose", "retry", "replace"].includes(event.action)) {
    const active = session.value;
    const context = capabilityContext(event.formValues);
    if (!active || !context) return;
    void fileUploads.captured(event, () => active.invokeCapability(context.page.pluginId,
      { capability: "documentCapture", params: { side }, into: event.inputId },
      { ...(top.value.conversationId ? { conversationId: top.value.conversationId } : {}), context }), flareDocumentFileName(side),
      () => takeCapturedPhoto(context.page.pluginId, side),
      (handedOver) => watchCapturedPhoto(context.page.pluginId, side, handedOver));
    return;
  }
  void fileUploads.action(event);
}

/** The shown page as a capability writing into one of its inputs reads it: the page, its arguments, the session fence. */
function capabilityContext(formValues?: Record<string, unknown>): PluginCapabilityPageContext | null {
  const entry = top.value;
  if (!entry || !view.value?.available) return null;
  return { page: { pluginId: entry.pluginId, page: entry.page }, ...(entry.args ? { arguments: entry.args } : {}),
    data: pluginFileSessionData(view.value.data), ...(formValues ? { formValues } : {}) };
}

/** A location fix as the kit's location input takes it. */
type LocationFix = { latitude: number; longitude: number; accuracyM: number; precision: "coarse" | "fine" };
type LocationState = { value?: LocationFix; locating?: boolean; error?: string };
const locationStates = shallowRef<Record<string, LocationState>>({});
function setLocation(inputId: string, state: LocationState | undefined): void {
  const next = { ...locationStates.value };
  if (state) next[inputId] = state;
  else delete next[inputId];
  locationStates.value = next;
}
function locationFix(value: unknown): LocationFix | undefined {
  const fix = value as Partial<LocationFix> | null;
  return fix && typeof fix.latitude === "number" && typeof fix.longitude === "number" && typeof fix.accuracyM === "number"
    && (fix.precision === "coarse" || fix.precision === "fine") ? fix as LocationFix : undefined;
}
/** A location input's key: one fix through the engine (the viewer confirms each time), written into the input. */
async function locationAction(event: { action: "locate" | "clear"; inputId: string; input: { precision?: string }; formValues: Record<string, unknown> }): Promise<void> {
  if (event.action === "clear") { setLocation(event.inputId, undefined); return; }
  const active = session.value;
  const context = capabilityContext(event.formValues);
  const precision = event.input.precision;
  if (!active || !context || (precision !== "coarse" && precision !== "fine") || locationStates.value[event.inputId]?.locating) return;
  const generationAtStart = generation;
  setLocation(event.inputId, { ...locationStates.value[event.inputId], locating: true, error: undefined });
  let outcome: PluginActionOutcome;
  try {
    outcome = await active.invokeCapability(context.page.pluginId, { capability: "locationOnce", params: { precision }, into: event.inputId },
      { ...(top.value.conversationId ? { conversationId: top.value.conversationId } : {}), context });
  } catch (cause) {
    outcome = { kind: "declined", reason: "unavailable" };
    console.warn("[plugin-page] location failed", cause instanceof Error ? cause.message : String(cause));
  }
  if (generationAtStart !== generation) return;
  const previous = locationStates.value[event.inputId]?.value;
  const fix = outcome.kind === "input" && outcome.input === event.inputId ? locationFix(outcome.value) : undefined;
  if (fix) setLocation(event.inputId, { value: fix });
  else if (outcome.kind === "declined" && outcome.reason !== "unavailable") setLocation(event.inputId, previous ? { value: previous } : undefined);
  else setLocation(event.inputId, { ...(previous ? { value: previous } : {}), error: t("pluginRuntime.unavailable") });
}

/** Protected media read on this page, by item id: an address in memory only, never cached. */
const protectedMedia = shallowRef<Record<string, FlarePluginProtectedMediaState>>({});
const protectedReads = new Map<string, AbortController>();
const protectedPreviews = new Map<string, () => void>();
function clearProtectedMedia(): void {
  for (const controller of protectedReads.values()) controller.abort();
  protectedReads.clear();
  for (const release of protectedPreviews.values()) release();
  protectedPreviews.clear();
  protectedMedia.value = {};
}
function setProtected(itemId: string, state: FlarePluginProtectedMediaState): void {
  protectedMedia.value = { ...protectedMedia.value, [itemId]: state };
}
/** One protected item: run its declared action with the item's form values, then show the address it returns. */
async function protectedMediaRead(read: FlarePluginProtectedMediaRead): Promise<void> {
  const active = session.value;
  const entry = top.value;
  if (!active || !entry || protectedMedia.value[read.item.id]?.loading) return;
  const generationAtStart = generation;
  const current = () => generationAtStart === generation && props.visible !== false;
  const controller = new AbortController();
  protectedReads.set(read.item.id, controller);
  protectedPreviews.get(read.item.id)?.();
  protectedPreviews.delete(read.item.id);
  setProtected(read.item.id, { loading: true });
  try {
    const outcome = await active.invokePageAction(entry.pluginId, entry.page, read.action.id, {
      userGesture: true,
      ...(entry.conversationId ? { conversationId: entry.conversationId } : {}),
      ...(view.value?.data ? { data: view.value.data } : {}),
      formValues: read.formValues,
    });
    if (!current()) return;
    const url = outcome.kind === "operation" && outcome.response.success === true
      ? flarePluginProtectedMediaUrl(outcome.response.data, read.urlPath) : undefined;
    if (!url) throw new Error("PRIVATE_MEDIA_ADDRESS_UNAVAILABLE");
    const preview = await protectedMediaPreview(url, {
      origin: typeof location !== "undefined" ? location.href : undefined,
      signal: controller.signal,
    });
    if (!current()) { preview.release(); return; }
    protectedPreviews.set(read.item.id, preview.release);
    setProtected(read.item.id, { url: preview.url });
  } catch (cause) {
    if (current()) setProtected(read.item.id, { error: props.errorText?.(cause) ?? t("pluginRuntime.unavailable") });
  } finally {
    if (protectedReads.get(read.item.id) === controller) protectedReads.delete(read.item.id);
  }
}

onBeforeUnmount(() => {
  generation++;
  paginationTicket++;
  actionTicket++;
  clearFiles();
  locationStates.value = {};
  clearProtectedMedia();
  session.value?.reset();
});

const failure = (cause: unknown) => props.errorText?.(cause) ?? props.loadFailedText;
/**
 * A refused command (`success: false`) in readable words (R8): the plugin's own (`message`, the page declares them for
 * the code), else the host's copy for the refusal's code (`data.errorCode`, as a thrown rejection's `machineReason`) or
 * error, never the raw text; the kit's generic line when there is none.
 */
function refusalText(result: { error?: unknown; data?: unknown }, message?: string): string {
  if (message) return message;
  const code = (result.data as { errorCode?: unknown } | null | undefined)?.errorCode;
  const readable = code || result.error ? props.errorText?.({ machineReason: code, message: result.error }) : undefined;
  return readable || t("pluginRuntime.rejected");
}

/**
 * The top entry's page with its filters. `open`: the first page, nothing shown meanwhile. `filter`: the first page with
 * new filters, the shown page kept until it arrives. `refresh`: the shown page read again from the first page, as many
 * pages as it had loaded (the core's refresh), kept until it arrives. `return`: the same refresh for a page uncovered by
 * a pop, whose view is already back on screen; the popped page's files and location fixes go with it.
 */
async function load(mode: "open" | "filter" | "refresh" | "return" = "open", requestedFilters?: Record<string, unknown>): Promise<void> {
  const prompt = mode === "open" ? pendingPrompt : undefined;
  pendingPrompt = undefined;
  const mine = ++generation;
  clearProtectedMedia();
  // A normal refresh keeps this form's picker, bytes and original upload
  // intent alive. A different page/query must release them.
  if (mode !== "refresh") {
    clearFiles();
    locationStates.value = {};
  }
  paginationTicket++;
  pagingToken.value++;
  loadingMore.value = false;
  paginationError.value = "";
  const active = session.value;
  const entry = top.value;
  error.value = "";
  if (!active || !entry) {
    view.value = undefined;
    loading.value = false;
    refreshing.value = false;
    return;
  }
  const filters = requestedFilters ?? entry.filters;
  const shown = mode === "open" ? undefined : view.value;
  if (shown) refreshing.value = true;
  else {
    loading.value = true;
    view.value = undefined;
  }
  try {
    const next = await active.page(entry.pluginId, entry.page, {
      ...(entry.conversationId ? { conversationId: entry.conversationId } : {}),
      ...(entry.args ? { args: entry.args } : {}),
      ...(Object.keys(filters).length ? { filters } : {}),
      ...((mode === "refresh" || mode === "return") && shown ? { refresh: shown } : {}),
    });
    if (mine === generation) {
      view.value = next;
      if (requestedFilters) stack.value = [...stack.value.slice(0, -1), { ...top.value, filters }];
    }
  } catch (cause) {
    console.warn("[plugin-page] load failed", cause instanceof Error ? cause.message : String(cause));
    if (mine === generation) error.value = failure(cause);
  } finally {
    if (mine === generation) {
      loading.value = false;
      refreshing.value = false;
    }
  }
  if (prompt && mine === generation && props.visible !== false && prompt.owner === props.root
      && prompt.session === session.value && prompt.entry === top.value && view.value?.available) {
    const nextAction = [...view.value.actions, ...(view.value.menuActions ?? [])].find(item => item.id === prompt.actionId);
    // The core already applied availability/permissions. Never bypass another form, confirmation or disabled state.
    if (nextAction?.target?.kind === "operation" && (prompt.operation === undefined || nextAction.target.operation === prompt.operation)
        && !nextAction.form?.length && !nextAction.confirm && !nextAction.disabledReason) {
      await action(nextAction.id, { page: { pluginId: entry.pluginId, page: entry.page }, data: view.value.data ?? {} });
    }
  }
}
// Getters only: the stack array among the sources would make the watcher fire on every stack write (a filter, say).
watch([() => props.root, () => session.value, () => top.value.pluginId, () => top.value.page, () => top.value.conversationId, () => JSON.stringify(top.value.args), () => stack.value.length, () => top.value.route], () => {
  // Invalidate both old UI settlement and the session's automatic page navigation. The SDK command journal lives
  // in the port; resetting this presentation session does not cancel, repeat or acknowledge a financial command.
  actionTicket++;
  session.value?.reset();
  busyActionId.value = undefined;
  actionError.value = "";
  formErrors.value = [];
  // Back on a page it covered (back, done, a flow returning to its status page): its last view now, then a quiet re-read.
  const covered = coveredViews.get(toRaw(top.value));
  coveredViews.delete(toRaw(top.value));
  if (covered) view.value = covered;
  void load(covered ? "return" : "open");
}, { immediate: true });

async function loadMore(cursor: string): Promise<void> {
  const active = session.value;
  const entry = top.value;
  const previous = view.value;
  if (!active || !previous || loadingMore.value || loading.value || refreshing.value) return;
  const mine = generation;
  const ticket = ++paginationTicket;
  loadingMore.value = true;
  paginationError.value = "";
  try {
    const merged = await active.page(entry.pluginId, entry.page, {
      ...(entry.conversationId ? { conversationId: entry.conversationId } : {}),
      ...(entry.args ? { args: entry.args } : {}),
      filters: entry.filters,
      page: { cursor, previous },
    });
    if (mine === generation && ticket === paginationTicket) view.value = merged;
  } catch (cause) {
    // Keep the records and report a read error without changing financial action settlement or form errors.
    if (mine === generation && ticket === paginationTicket) paginationError.value = failure(cause);
  } finally {
    if (mine === generation && ticket === paginationTicket) {
      loadingMore.value = false;
      pagingToken.value++;
    }
  }
}

/** A filter tab: the page's first page again with the new values (a filter the page drops comes back unset). */
function filter(values: Record<string, unknown>): void {
  void load("filter", values);
}

async function action(actionId: string, payload: FlarePluginPageActionPayload): Promise<void> {
  const active = session.value;
  const entry = top.value;
  const owner = props.root;
  if (!active || busyActionId.value) return;
  const ticket = ++actionTicket;
  const current = () => ticket === actionTicket && active === session.value && owner === props.root;
  const depth = stack.value.length;
  busyActionId.value = actionId;
  actionError.value = "";
  formErrors.value = [];
  let changed = false;
  let posted: PluginPostedCard | null = null;
  try {
    const outcome = await active.invokePageAction(entry.pluginId, entry.page, actionId, {
      userGesture: true,
      ...(entry.conversationId ? { conversationId: entry.conversationId } : {}),
      ...(payload.data ? { data: payload.data } : {}),
      ...(payload.row ? { row: payload.row as { key: string; input: Record<string, unknown> } } : {}),
      ...(payload.formValues ? { formValues: payload.formValues } : {}),
      ...(payload.selection ? { selection: payload.selection } : {}),
      ...(entry.args ? { arguments: entry.args } : {}),
    });
    if (!current()) return;
    if (outcome.kind === "formErrors") formErrors.value = outcome.errors;
    // A native action wrote into one of the page's inputs: a document's reference or a location fix.
    else if (outcome.kind === "input") {
      const fix = locationFix(outcome.value);
      if (fix) setLocation(outcome.input, { value: fix });
      else fileUploads.settle(outcome.input, outcome.value);
    } else if (outcome.kind === "declined") {
      if (outcome.reason === "unavailable") actionError.value = t("pluginRuntime.unavailable");
    }
    else if (outcome.kind === "operation") {
      changed = true;
      if (outcome.response.success === false) actionError.value = refusalText(outcome.response, outcome.message);
      else if (outcome.response.success === true && entry.conversationId === owner.conversationId) {
        posted = pluginPagePostedCard(outcome.response.data, owner.conversationId);
      }
    } else if (outcome.kind === "host") {
      changed = true;
      const result = outcome.result as { success?: unknown; status?: unknown; error?: unknown; data?: unknown } | null;
      if (result?.success === false) actionError.value = refusalText(result);
      else if (result?.status === "unknown") actionError.value = t("pluginRuntime.unavailable");
    }
  } catch (cause) {
    if (current()) actionError.value = props.errorText?.(cause) ?? t("pluginRuntime.unavailable");
  } finally {
    if (current()) {
      settleToken.value++;
      busyActionId.value = undefined;
    }
  }
  // The owning surface closes its entire stack; a nested page must never pop an unrelated route.
  if (current() && posted) { emit("posted", posted, owner); return; }
  // The kit re-reads after a clean settle (refresh "action", R4). A refused or unknown command may still have moved
  // what the page shows (a completed journal), so that one is re-read here; a page target opened the next page instead.
  if (current() && changed && actionError.value && stack.value.length === depth) void load("refresh");
}

/** An expired QR code on the page: run the query the block declares, then read the page again in place. */
async function refreshQr(request: FlarePluginQrRefresh): Promise<void> {
  const active = session.value;
  const entry = top.value;
  if (!active || !entry || !view.value?.available) return;
  try { await active.query(request.operation, entry.conversationId); } catch { return; }
  if (active === session.value) void load("refresh");
}

/** A page tab (rules.pageTabs): the sibling page replaces the shown one, with its arguments; back stays where it was. */
function tab(page: string): void {
  pendingPrompt = undefined;
  const { pluginId, title, providerName, args, conversationId } = top.value;
  stack.value = [...stack.value.slice(0, -1), pageFrame({ pluginId, page, title,
    ...(providerName ? { providerName } : {}), ...(args ? { args } : {}), ...(conversationId ? { conversationId } : {}) })];
}
function back(): void {
  pendingPrompt = undefined;
  if (stack.value.length > 1) stack.value = stack.value.slice(0, -1);
  else emit("back");
}
/**
 * A result page's done (R7, §12.1 doneTarget): pops to the nearest overview or records page below it, which the stack
 * watcher re-reads as a return (afterReturn); with none below, the plugin pages close.
 */
function done(): void {
  pendingPrompt = undefined;
  const target = flarePluginDoneTarget(stack.value.map(entry => entry.kind ?? "task"));
  if (target === null) emit("back");
  else stack.value = stack.value.slice(0, target + 1);
}
const contentPresentation = computed(() => view.value && props.pageContent?.(
  { pluginId: top.value.pluginId, page: top.value.page }, view.value,
));
</script>

<template>
  <CorePluginBundle
    v-bind="$attrs"
    v-if="bundleShown && bundles"
    class="core-plugin-page"
    :host="bundles"
    :plugin-id="top.pluginId"
    :contribution-id="top.page"
    presentation="page"
    :route="top.route"
    :args="top.args"
    :conversation="top.conversationId ? { id: top.conversationId, type: '' } : undefined"
    :title="top.title"
    back
    @back="back"
    @close="back"
    @navigate="bundleNavigate"
    @fallback="bundleFallback"
  />
  <FlarePluginPage
    v-bind="$attrs"
    v-else
    class="core-plugin-page"
    :page="{ pluginId: top.pluginId, page: top.page }"
    :title="top.title"
    :provider-name="props.root.providerName"
    :visible="visible"
    :encode-plugin-code="encodePluginCode ?? directory.encodePluginCode"
    @surface-hints="hints => emit('surfaceHints', hints)"
    :appearance="pageAppearance?.({ pluginId: top.pluginId, page: top.page })"
    :content-action-ids="contentPresentation?.actionIds"
    :content-state="top.contentState"
    :view="shownView"
    :filters="top.filters"
    :loading="loading"
    :error="error || paginationError || undefined"
    :refreshing="refreshing"
    :loading-more="loadingMore"
    :paging-token="pagingToken"
    back
    :resolve-user="resolveUser"
    :viewer-id="viewerId"
    :members="members"
    :members-loading="membersLoading"
    :members-error="membersError"
    :members-revision="membersRevision"
    :member-count="memberCount"
    :on-member-search="onMemberSearch"
    :on-members-retry="onMembersRetry"
    :busy-action-id="busyActionId"
    :action-error="actionError || undefined"
    :form-errors="formErrors"
    :settle-token="settleToken"
    :file-states="fileStates"
    :location-states="locationStates"
    :protected-media="protectedMedia"
    :resolve-image="pluginHost().resolveImage"
    :upgrade-status="upgrade.status.value"
    :on-update="upgrade.update.value"
    :upgrade-busy="upgrade.busy.value"
    @back="back"
    @refresh="load('refresh')"
    @done="done"
    @retry="load()"
    @load-more="loadMore"
    @filter="filter"
    @action="action"
    @file-action="fileAction"
    @location-action="locationAction"
    @protected-media-read="protectedMediaRead"
    @qr-refresh="refreshQr"
    @tab="tab"
  >
    <template v-if="contentPresentation" #content="context">
      <component :is="contentPresentation.component" v-bind="context" :content-state="top.contentState" />
    </template>
  </FlarePluginPage>
  <FlareImagePreview
    :show="Boolean(filePreview)"
    :image-src="filePreview?.url ?? ''"
    :alt="filePreview?.name ?? ''"
    @update:show="(show) => { if (!show) filePreview = undefined; }"
  />
</template>

<style scoped>
/* The page fills the destination it is pushed into. */
.core-plugin-page {
  height: 100%;
  min-height: 0;
}
</style>
