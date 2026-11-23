<script setup lang="ts">
// A plugin card in the timeline: Core resolves the view over the card's stored state layers, the
// kit draws it (PluginView v2), and actions go back to Core with the viewer's selection or form
// values. The host's part of the kit contract lives here: `busyActionId` while an action is in
// flight, `error` cleared when the next one starts, Core's `formErrors` handed back to the form,
// `settleToken` moved once per finished action after its outcome is set, and "see all" in the kit
// detail sheet over `session.detail` with its own action state and its pages.
import { computed, inject, onBeforeUnmount, ref, shallowReactive, shallowRef, watch } from "vue";
import {
  FlareBottomSheet, FlarePluginDetailSheet, FlarePluginView, useFlareI18n,
  type FlarePluginActionPayload, type FlarePluginFormError, type FlarePluginMember, type FlarePluginQrRefresh,
  type FlarePluginResolveUser, type FlarePluginViewModel,
} from "@flare-im/vue-ui";
import type { PluginDetailPresentation } from "@flare-im/sdk/plugin-ui";
import {
  pluginUiConversationKey, pluginUiConversationTypeKey, pluginUiDirectoryKey, pluginUiErrorTextKey, pluginUiHostKey, pluginUiOpenPageKey,
  pluginUiSessionKey, pluginUiStateFeedKey,
} from "./context";
import { useCorePluginUpgrade } from "./upgrade";
import CorePluginBundle from "./CorePluginBundle.vue";

// The kit hands renderers more than these (isSelf, listeners); a card with a detail sheet has two roots.
defineOptions({ inheritAttrs: false });
const { t } = useFlareI18n();
const props = defineProps<{
  content: Record<string, unknown>;
  /** The timeline's id for the message; Core keeps the card state on it. */
  messageId?: string;
  /** The timeline's conversation, when the kit hands it to renderers. */
  conversationId?: string;
  /** Overrides the provided directory's resolver for this card. */
  resolveUser?: FlarePluginResolveUser;
  /** Overrides the provided directory's conversation members for this card. */
  members?: FlarePluginMember[];
}>();
const session = inject(pluginUiSessionKey, ref(null));
const hostConversation = inject(pluginUiConversationKey, () => undefined);
const hostConversationType = inject(pluginUiConversationTypeKey, () => undefined);
const openPage = inject(pluginUiOpenPageKey, undefined);
const directory = inject(pluginUiDirectoryKey, {});
const stateChanges = inject(pluginUiStateFeedKey, null);
const errorText = inject(pluginUiErrorTextKey, () => undefined);
const pluginHost = inject(pluginUiHostKey, {});
const resolver = computed(() => props.resolveUser ?? directory.resolveUser);
const members = computed(() => props.members ?? directory.members?.() ?? []);
const conversation = () => props.conversationId || hostConversation();

/** The plugin's name the platform wrote on the card: an inert card says which plugin it is from. */
const displayName = computed(() => session.value?.envelope(props.content)?.displayName ?? undefined);
const placeholder = (): FlarePluginViewModel => ({
  available: false, title: typeof props.content.description === "string" ? props.content.description : "", fields: [], actions: [],
});
const view = shallowRef<FlarePluginViewModel>(placeholder());
let viewGeneration = 0;
/**
 * Core merges the stored card state before it resolves the view; nothing is merged here. A view
 * equal to the one shown is not assigned again: a new view resets the kit's optimistic choice and
 * an unsent multiple-choice draft, and a repeated announcement of the same state must not.
 */
async function refresh(reset: boolean): Promise<void> {
  const mine = ++viewGeneration, host = session.value;
  if (reset) view.value = placeholder();
  const message = host?.envelope(props.content);
  if (!host || !message) return;
  const result = await host.present(message, props.messageId);
  if (mine !== viewGeneration || host !== session.value) return;
  if (!reset && JSON.stringify(result) === JSON.stringify(view.value)) return;
  view.value = result;
}

// An upgrade placeholder (D-18): the card's notice asks whether this device is offered the build it needs.
const upgrade = useCorePluginUpgrade(() => view.value, () => pluginHost);
/**
 * An expired QR code: run the query the block declares (Core checks the grant), then present the card again. A failed
 * query keeps the expired code, whose key the viewer can press again.
 */
async function refreshQr(request: FlarePluginQrRefresh): Promise<void> {
  const host = session.value;
  if (!host || !view.value.available) return;
  try { await host.query(request.operation, conversation()); } catch { return; }
  if (host === session.value) void refresh(false);
}

// ── actions ──────────────────────────────────────────────────────────────
/**
 * Where an action runs from: the card, or the detail sheet over it. Each has its own spinner, failure, form
 * errors and settle signal, so a failure in the detail stays in the sheet and never lands on the card below.
 */
interface ActionSurface {
  busyActionId: string | undefined;
  error: string;
  formErrors: FlarePluginFormError[];
  /** Moved once per finished action, after that action's error and formErrors are set (kit settleToken). */
  settleToken: number;
}
const actionSurface = (): ActionSurface => shallowReactive({ busyActionId: undefined, error: "", formErrors: [], settleToken: 0 });
const onCard = actionSurface();
const inDetail = actionSurface();
/** One per card identity: an action started for another message or session settles nothing here. */
let actionScope = 0;
/** One action per card at a time, from either surface. */
async function runAction(surface: ActionSurface, id: string, payload: FlarePluginActionPayload): Promise<void> {
  const host = session.value, scope = actionScope, message = host?.envelope(props.content);
  if (!host || !message || onCard.busyActionId || inDetail.busyActionId || !view.value.available) return;
  surface.busyActionId = id; surface.error = ""; surface.formErrors = [];
  let changed = false;
  try {
    const outcome = await host.invokeAction(message, id, {
      messageId: props.messageId, conversationId: conversation(), userGesture: true,
      ...(payload.formValues ? { formValues: payload.formValues } : {}), ...(payload.selection ? { selection: payload.selection } : {}),
    });
    if (scope !== actionScope) return;
    if (outcome.kind === "formErrors") surface.formErrors = outcome.errors;
    else if (outcome.kind === "operation" && outcome.response.success === false) surface.error = outcome.message || t("pluginRuntime.rejected");
    // A host capability that did not run (refused, backed out) changed nothing; one the host could not run says so.
    else if (outcome.kind === "declined") { if (outcome.reason === "unavailable") surface.error = t("pluginRuntime.unavailable"); }
    // Core has stored the state the plugin returned on this message: show it without waiting for the event.
    else changed = true;
  } catch (failure) {
    if (scope === actionScope) surface.error = errorText(failure) ?? t("pluginRuntime.unavailable");
  } finally {
    if (scope === actionScope) {
      // The outcome is set: settle it (closes a submitted form, keeps or reverts the optimistic choice).
      surface.settleToken++;
      surface.busyActionId = undefined;
    }
  }
  if (changed) {
    void refresh(false);
    if (detailOpen.value) void loadDetail(true);
  }
}
const cardAction = (id: string, payload: FlarePluginActionPayload = {}) => runAction(onCard, id, payload);
const detailAction = (id: string, payload: FlarePluginActionPayload = {}) => runAction(inDetail, id, payload);

// ── "see all" ────────────────────────────────────────────────────────────
const detailUsed = ref(false), detailOpen = ref(false), detailLoading = ref(false), detailError = ref("");
/** The next page is on its way (kit loadingMore). */
const detailLoadingMore = ref(false);
const detailPagingError = ref("");
const detailPagingToken = ref(0);
/** The sheet as Core returned it; handed back unchanged as `previous` for the next page. */
const detailView = shallowRef<PluginDetailPresentation>();
let detailGeneration = 0;
const detailRequest = () => ({ messageId: props.messageId, conversationId: conversation(), userGesture: true });
/**
 * Core runs the contribution's detail operation over the merged card data. `quiet` keeps the shown view while it
 * reloads and asks Core to refresh it: the first page again and as many more as the sheet had loaded, so a state
 * change never folds the pages the viewer opened.
 */
async function loadDetail(quiet = false): Promise<void> {
  const mine = ++detailGeneration, host = session.value, message = host?.envelope(props.content), shown = detailView.value;
  detailLoading.value = true;
  // A reload starts again from the first page: a page still on its way is dropped.
  detailError.value = ""; detailPagingError.value = ""; detailLoadingMore.value = false; detailPagingToken.value++;
  try {
    if (!host || !message) throw new Error("Plugin detail unavailable");
    const result = await host.detail(message, { ...detailRequest(), ...(quiet && shown ? { refresh: shown } : {}) });
    if (mine === detailGeneration) detailView.value = result;
  } catch (failure) {
    if (mine === detailGeneration) detailError.value = errorText(failure) ?? t("pluginRuntime.unavailable");
  } finally {
    if (mine === detailGeneration) detailLoading.value = false;
  }
}
/**
 * The page after `cursor` (the shown sheet's nextCursor): the same request plus the cursor and the shown sheet, which
 * Core returns with the page appended. The result replaces the sheet whole; nothing is merged here. A failure keeps
 * what is shown and says so where the detail's actions do.
 */
async function loadMoreDetail(cursor: string): Promise<void> {
  const host = session.value, message = host?.envelope(props.content), previous = detailView.value;
  if (!host || !message || !previous || detailLoading.value || detailLoadingMore.value) return;
  const mine = ++detailGeneration;
  detailLoadingMore.value = true; detailPagingError.value = "";
  try {
    const merged = await host.detail(message, { ...detailRequest(), page: { cursor, previous } });
    if (mine === detailGeneration) detailView.value = merged;
  } catch (failure) {
    if (mine === detailGeneration) detailPagingError.value = errorText(failure) ?? t("pluginRuntime.unavailable");
  } finally {
    if (mine === detailGeneration) { detailPagingToken.value++; detailLoadingMore.value = false; }
  }
}
/**
 * A card whose contribution's bundle variant Core selected opens its "view all" in the kit's bundle host when the host
 * provides bundles (design 8.9, presentation `detail`); the card itself stays declarative (D-02). Only a card the
 * engine marks (`bundle` on its presented view) tries one, so every other card opens its detail sheet at once. A
 * bundle that cannot show falls back to the declarative detail sheet for this card.
 */
const bundleDetail = shallowRef<{ pluginId: string; contributionId: string; args: Record<string, unknown> } | null>(null);
const bundleTitle = ref("");
let detailDeclarative = false;
function bundleArguments(payload: Record<string, unknown>): Record<string, unknown> {
  const args: Record<string, unknown> = props.messageId ? { messageId: props.messageId } : {};
  // The hello carries at most 16 KiB of arguments: a large payload is left for the bundle to query.
  try { if (JSON.stringify(payload).length <= 12 * 1024) args.payload = payload; } catch { /* left out */ }
  return args;
}
function bundleDetailFallback(): void {
  bundleDetail.value = null;
  detailDeclarative = true;
  openDetail();
}
function openDetail(): void {
  if (!view.value.available || !view.value.detail) return;
  const message = session.value?.envelope(props.content);
  const offered = (view.value as { bundle?: unknown }).bundle === true;
  if (pluginHost.bundles && message && offered && !detailDeclarative) {
    bundleTitle.value = "";
    bundleDetail.value = { pluginId: message.pluginId, contributionId: message.contributionId, args: bundleArguments(message.payload) };
    return;
  }
  detailUsed.value = true; detailOpen.value = true; detailView.value = undefined;
  inDetail.error = ""; inDetail.formErrors = [];
  void loadDetail();
}
/** What the detail bundle's hello says about the conversation: its id and, when the host provided it, its type. */
function bundleConversation(): { id: string; type: string } | undefined {
  const id = conversation();
  return id ? { id, type: hostConversationType() ?? "" } : undefined;
}
/**
 * The detail bundle's `ui.navigate` to a page of its plugin: the host opens it beside the chat, as an action's page
 * target would (the sheet stays open, as on Flutter). A route inside the bundle (`bundleRoute`) has no page of its own
 * here, and a host without `openPage` keeps the navigation unanswered, as before.
 */
function bundleNavigate(target: { page?: string; arguments?: Record<string, unknown>; bundleRoute?: string }): void {
  const detail = bundleDetail.value;
  if (!openPage || !detail || !target.page) return;
  const conversationId = conversation();
  openPage({
    pluginId: detail.pluginId,
    page: target.page,
    title: displayName.value ?? "",
    ...(target.arguments ? { args: target.arguments } : {}),
    ...(conversationId ? { conversationId } : {}),
  });
}
function closeDetail(): void {
  bundleDetail.value = null;
  detailGeneration++;
  detailOpen.value = false; detailLoading.value = false; detailError.value = ""; detailPagingError.value = ""; detailLoadingMore.value = false;
}

// ── lifecycle ────────────────────────────────────────────────────────────
// Another message or session: drop what belonged to the previous card. A stored message's card
// changes only with its stored state; a reload hands the row a fresh content object.
watch([() => props.messageId ?? props.content, () => session.value], () => {
  actionScope++;
  for (const surface of [onCard, inDetail]) { surface.busyActionId = undefined; surface.error = ""; surface.formErrors = []; }
  closeDetail();
  void refresh(true);
}, { immediate: true });
// New card state on either layer (the viewer's own, the shared one others change in real time) or a catalog the SDK
// invalidated: the SDK announces the card's message, and only then is it presented again. Nothing is polled.
const stopStateChanges = stateChanges?.((change) => {
  if (!props.messageId || change.messageId !== props.messageId) return;
  void refresh(false);
  if (detailOpen.value && detailView.value) void loadDetail(true);
});
onBeforeUnmount(() => { viewGeneration++; actionScope++; detailGeneration++; stopStateChanges?.(); });
</script>
<template>
  <FlareBottomSheet v-if="bundleDetail" :open="true" :title="bundleTitle || view.title" @close="bundleDetail = null">
    <CorePluginBundle
      v-if="pluginHost.bundles"
      :host="pluginHost.bundles"
      :plugin-id="bundleDetail.pluginId"
      :contribution-id="bundleDetail.contributionId"
      presentation="detail"
      :args="bundleDetail.args"
      :conversation="bundleConversation()"
      @title="(value) => { bundleTitle = value; }"
      @close="bundleDetail = null"
      @navigate="bundleNavigate"
      @fallback="bundleDetailFallback"
    />
  </FlareBottomSheet>
  <FlarePluginView
    :view="view"
    :display-name="displayName"
    :busy-action-id="onCard.busyActionId"
    :error="onCard.error || undefined"
    :form-errors="onCard.formErrors"
    :settle-token="onCard.settleToken"
    :resolve-user="resolver"
    :members="members"
    :resolve-image="pluginHost.resolveImage"
    :upgrade-status="upgrade.status.value"
    :on-update="upgrade.update.value"
    :upgrade-busy="upgrade.busy.value"
    @action="cardAction"
    @open-detail="openDetail"
    @qr-refresh="refreshQr"
  />
  <FlarePluginDetailSheet
    v-if="detailUsed"
    :open="detailOpen"
    :title="view.title"
    :presentation="pluginHost.detailPresentation"
    :view="detailView"
    :loading="detailLoading"
    :error="detailError || undefined"
    :resolve-user="resolver"
    :members="members"
    :busy-action-id="inDetail.busyActionId"
    :action-error="inDetail.error || undefined"
    :form-errors="inDetail.formErrors"
    :settle-token="inDetail.settleToken"
    :loading-more="detailLoadingMore"
    :pagination-error="detailPagingError || undefined"
    :paging-token="detailPagingToken"
    @retry="loadDetail(Boolean(detailView))"
    @close="closeDetail"
    @action="detailAction"
    @load-more="loadMoreDetail"
  />
</template>
