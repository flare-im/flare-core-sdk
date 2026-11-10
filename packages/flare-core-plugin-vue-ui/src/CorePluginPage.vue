<script setup lang="ts">
/**
 * A plugin page (a wallet, a ledger) hosted on the core SDK: the kit's FlarePluginPage over `pluginPage`. The 我 entries
 * of plugins and the page targets of card actions open here.
 *
 * The page document, its source, paging, rows and actions are declared by the plugin and resolved by Core; this only
 * holds the filters and the page stack and forwards requests: the first page and a refresh (`refresh` with the shown
 * view), a next page (`page` with the cursor and the shown view, Core merges them), a filter (the first page with the
 * new values), a page action (`invokePageAction` with the view's `data` and the row's `row`, no message). A page target
 * an action opens is pushed with its own plugin; back pops it, and on the root page emits `back`.
 */
import { computed, onBeforeUnmount, ref, shallowRef, watch } from "vue";
import {
  FlarePluginPage,
  FlareImagePreview,
  useFlareI18n,
  type FlarePluginFormError,
  type FlarePluginFileAction,
  type FlarePluginFileState,
  type FlarePluginPageAppearance,
  type FlarePluginPageRef,
  type FlarePluginPageActionPayload,
  type FlarePluginResolveUser,
  type FlarePluginMember,
} from "@flare-im/vue-ui";
import {
  pluginManifestLocale,
  type PluginPagePresentation,
  type PluginPlatform,
  type PluginUiPort,
  type PluginUiSession,
} from "@flare-im/sdk/plugin-ui";
import type { CorePluginErrorText } from "./context";
import { corePluginPageSession, pluginPagePostedCard, type CorePluginPageEntry } from "./pluginPage";
import type { PluginPostedCard } from "./composerMenu";
import { PluginFileUploads, choosePluginFile, pluginFileSessionData } from "./pluginFileUploads";

const props = defineProps<{
  /** The page the stack starts from. */
  root: CorePluginPageEntry;
  pageAppearance?: (page: FlarePluginPageRef) => FlarePluginPageAppearance;
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
  onMemberSearch?: (query: string) => void;
  onMembersRetry?: () => void;
  /** The host's copy for a failed plugin call (`sdk.plugin.*`), as given to `provideCorePluginUi`. */
  errorText?: CorePluginErrorText;
  /** The host's line for a page that failed to load for any other reason. */
  loadFailedText: string;
}>();
const emit = defineEmits<{ back: []; posted: [card: PluginPostedCard, owner: CorePluginPageEntry] }>();

const { t, locale } = useFlareI18n();
/** The pages opened from the root, the root first. Each keeps its own filters. */
const stack = ref<Array<CorePluginPageEntry & { filters: Record<string, unknown> }>>([{ ...props.root, filters: {} }]);
// Reopening the same entry is a new presentation even when every route field is equal.
watch(() => props.root, (root) => { stack.value = [{ ...root, filters: {} }]; }, { flush: "sync" });
const top = computed(() => stack.value[stack.value.length - 1]);
const session = shallowRef<PluginUiSession | null>(null);
watch([() => props.port, () => props.viewerId], ([port]) => {
  session.value?.reset();
  session.value = port
    ? corePluginPageSession(port, props.platform, () => pluginManifestLocale(locale.value), () => top.value,
      (entry) => { stack.value = [...stack.value, { ...entry, filters: {} }]; })
    : null;
}, { immediate: true });

const view = shallowRef<PluginPagePresentation>();
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
  if (!busyActionId.value) {
    if (event.action !== "preview") filePreview.value = undefined;
    void fileUploads.action(event);
  }
}

onBeforeUnmount(() => {
  generation++;
  paginationTicket++;
  actionTicket++;
  clearFiles();
  session.value?.reset();
});

const failure = (cause: unknown) => props.errorText?.(cause) ?? props.loadFailedText;

/**
 * The top entry's page with its filters. `open`: the first page, nothing shown meanwhile. `filter`: the first page with
 * new filters, the shown page kept until it arrives. `refresh`: the shown page read again from the first page, as many
 * pages as it had loaded (the core's refresh), kept until it arrives.
 */
async function load(mode: "open" | "filter" | "refresh" = "open", requestedFilters?: Record<string, unknown>): Promise<void> {
  const mine = ++generation;
  // A normal refresh keeps this form's picker, bytes and original upload
  // intent alive. A different page/query must release them.
  if (mode !== "refresh") clearFiles();
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
      ...(mode === "refresh" && shown ? { refresh: shown } : {}),
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
}
// Getters only: the stack array among the sources would make the watcher fire on every stack write (a filter, say).
watch([() => props.root, () => session.value, () => top.value.pluginId, () => top.value.page, () => top.value.conversationId, () => JSON.stringify(top.value.args), () => stack.value.length], () => {
  // Invalidate both old UI settlement and the session's automatic page navigation. The SDK command journal lives
  // in the port; resetting this presentation session does not cancel, repeat or acknowledge a financial command.
  actionTicket++;
  session.value?.reset();
  busyActionId.value = undefined;
  actionError.value = "";
  formErrors.value = [];
  void load();
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
    });
    if (!current()) return;
    if (outcome.kind === "formErrors") formErrors.value = outcome.errors;
    else if (outcome.kind === "operation") {
      changed = true;
      if (outcome.response.success === false) actionError.value = t("pluginRuntime.rejected");
      else if (outcome.response.success === true && entry.conversationId === owner.conversationId) {
        posted = pluginPagePostedCard(outcome.response.data, owner.conversationId);
      }
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
  // An operation may have moved what the page shows; a page target has opened the next page instead.
  if (current() && changed && stack.value.length === depth) void load("refresh");
}

function back(): void {
  if (stack.value.length > 1) stack.value = stack.value.slice(0, -1);
  else emit("back");
}
</script>

<template>
  <FlarePluginPage
    class="core-plugin-page"
    :page="{ pluginId: top.pluginId, page: top.page }"
    :title="top.title"
    :appearance="pageAppearance?.({ pluginId: top.pluginId, page: top.page })"
    :view="view"
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
    :on-member-search="onMemberSearch"
    :on-members-retry="onMembersRetry"
    :busy-action-id="busyActionId"
    :action-error="actionError || undefined"
    :form-errors="formErrors"
    :settle-token="settleToken"
    :file-states="fileStates"
    @back="back"
    @refresh="load('refresh')"
    @retry="load()"
    @load-more="loadMore"
    @filter="filter"
    @action="action"
    @file-action="fileAction"
  />
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
