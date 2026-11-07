import { onBeforeUnmount, shallowRef, watch } from "vue";

/**
 * The composer's toolbar and "+" panel as the social SDK's `composerMenu` describes them: built-in
 * items behind the tenant's feature switches, then the composer actions authorized plugins declare.
 * Hosts hand the result to the kit unchanged; which items exist, their order and their icons are
 * never written in an app. Display only: the server still authorizes every send and every action.
 */
export type ComposerToolId = "emoji" | "mention" | "voice" | "image" | "richText" | "attachments";

export interface ComposerFeatureItem {
  id: string;
  kind: "feature";
  featureKey?: string;
  icon?: string;
  order: number;
}

export interface ComposerPluginItem {
  id: string;
  kind: "plugin";
  pluginId: string;
  contributionId: string;
  label: string;
  icon?: string;
  order: number;
}

export type ComposerMenuItem = ComposerFeatureItem | ComposerPluginItem;

export interface ComposerMenu {
  tools: string[];
  actions: ComposerMenuItem[];
}

/** What a composer shows when the menu cannot be read: every feature off, no plugin listed. */
export const CLOSED_COMPOSER_MENU: ComposerMenu = Object.freeze({ tools: [], actions: [] }) as ComposerMenu;

const text = (value: unknown): value is string => typeof value === "string" && value.length > 0;

/** Reads a menu, leaving out anything malformed rather than guessing at it. */
export function parseComposerMenu(value: unknown): ComposerMenu {
  if (!value || typeof value !== "object") return CLOSED_COMPOSER_MENU;
  const raw = value as { tools?: unknown; actions?: unknown };
  const tools = Array.isArray(raw.tools) ? raw.tools.filter(text) : [];
  const actions: ComposerMenuItem[] = [];
  for (const entry of Array.isArray(raw.actions) ? raw.actions : []) {
    if (!entry || typeof entry !== "object") continue;
    const item = entry as Record<string, unknown>;
    const order = Number.isFinite(item.order) ? (item.order as number) : 1000;
    const icon = text(item.icon) ? item.icon : undefined;
    if (!text(item.id)) continue;
    if (item.kind === "feature") {
      actions.push({ id: item.id, kind: "feature", order, ...(icon ? { icon } : {}), ...(text(item.featureKey) ? { featureKey: item.featureKey } : {}) });
    } else if (item.kind === "plugin" && text(item.pluginId) && text(item.contributionId) && text(item.label)) {
      actions.push({ id: item.id, kind: "plugin", pluginId: item.pluginId, contributionId: item.contributionId, label: item.label, order, ...(icon ? { icon } : {}) });
    }
  }
  return { tools, actions };
}

/**
 * The "+" panel items in the kit's action shape, in the menu's order. Built-in items carry no label
 * (the kit names its unified ids); a plugin's unknown icon name draws the kit's plugin glyph.
 */
export function composerPanelActions(menu: ComposerMenu) {
  return menu.actions.map((item, index) => ({
    id: item.id,
    kind: item.kind,
    // The SDK already ordered built-ins and authorized plugins. Preserve that
    // sequence when a kit re-sorts action priorities (including negative plugin priorities).
    order: index,
    ...(item.kind === "plugin" ? { label: item.label } : {}),
    ...(item.icon ? { icon: item.icon } : {}),
  }));
}

export interface ComposerActionRoutes {
  /** Built-in items the host sends itself (card, poll). Pickers and voice stay with the kit. */
  features: Readonly<Record<string, () => void>>;
  /** Plugins with a native page, by `pluginId/contributionId`. */
  plugins: Readonly<Record<string, (item: ComposerPluginItem) => void>>;
  /** Every other plugin: the generic entry. */
  fallback: (item: ComposerPluginItem) => void;
}

/** Runs what a tapped "+" item means. False when the menu does not list it (nothing happens). */
export function routeComposerAction(menu: ComposerMenu, id: string, routes: ComposerActionRoutes): boolean {
  const item = menu.actions.find((entry) => entry.id === id);
  if (!item) return false;
  if (item.kind === "feature") {
    const send = routes.features[item.id];
    if (!send) return false;
    send();
    return true;
  }
  (routes.plugins[`${item.pluginId}/${item.contributionId}`] ?? routes.fallback)(item);
  return true;
}

/**
 * The menu for the open conversation: read on entering and switching conversations and when the
 * page comes back to the foreground, never polled. A failed read closes everything (design §3).
 * The previous conversation's menu stays up until the next one arrives, so the toolbar does not
 * blink on every switch.
 */
export function useComposerMenu(load: (conversationId: string) => Promise<unknown>, conversationId: () => string,
  onRefresh?: () => void) {
  const menu = shallowRef<ComposerMenu>(CLOSED_COMPOSER_MENU);
  let generation = 0;
  async function refresh(): Promise<void> {
    const mine = ++generation, id = conversationId();
    onRefresh?.();
    if (!id) { menu.value = CLOSED_COMPOSER_MENU; return; }
    try {
      const value = parseComposerMenu(await load(id));
      if (mine === generation) menu.value = value;
    } catch {
      if (mine === generation) menu.value = CLOSED_COMPOSER_MENU;
    }
  }
  watch(conversationId, () => { void refresh(); }, { immediate: true });
  const onVisible = () => { if (document.visibilityState === "visible") void refresh(); };
  if (typeof document !== "undefined") document.addEventListener("visibilitychange", onVisible);
  onBeforeUnmount(() => {
    generation++;
    if (typeof document !== "undefined") document.removeEventListener("visibilitychange", onVisible);
  });
  return { menu, refresh };
}

/** The card Core posted for a create result, in the user's name: where it went and its ids. */
export interface PluginPostedCard {
  conversationId: string;
  serverMsgId: string;
  clientMsgId: string;
}

/**
 * The card a create result says Core posted (`data.posted`). The card itself reaches the timeline like any message
 * pushed to the conversation; the host only uses this to point at it. Clients never post plugin cards.
 */
export function pluginPostedCard(data: unknown): PluginPostedCard | null {
  const posted = (data as { posted?: unknown } | null | undefined)?.posted as Partial<PluginPostedCard> | undefined;
  if (!posted || typeof posted !== "object") return null;
  if (!text(posted.conversationId) || !text(posted.serverMsgId)) return null;
  return { conversationId: posted.conversationId, serverMsgId: posted.serverMsgId, clientMsgId: text(posted.clientMsgId) ? posted.clientMsgId : "" };
}
