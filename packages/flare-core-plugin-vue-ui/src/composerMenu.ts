import { onBeforeUnmount, shallowRef, watch } from "vue";
import { FLARE_STANDARD_COMPOSER_TOOL_IDS, type FlarePluginAction, type FlarePluginViewModel } from "@flare-im/vue-ui";

/** The optional tools and entries from the Social SDK menu; the server authorizes every action. */
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
  /**
   * An upgrade placeholder (D-18): this build cannot draw the item. It stays in the panel with the "needs update" badge
   * and opens the upgrade notice instead of its form. `minBuild` is the plugin's floor, when it names one.
   */
  upgrade?: { minBuild?: number };
}

export type ComposerMenuItem = ComposerFeatureItem | ComposerPluginItem;

export interface ComposerMenu {
  tools: string[];
  actions: ComposerMenuItem[];
}

/** The optional menu before the first successful read. */
export const CLOSED_COMPOSER_MENU: ComposerMenu = Object.freeze({ tools: [], actions: [] }) as ComposerMenu;

const text = (value: unknown): value is string => typeof value === "string" && value.length > 0;

/** An entry's upgrade mark (`{minBuild?}`); a floor that is not a positive build number is dropped, the mark kept. */
export function parseUpgrade(value: unknown): { minBuild?: number } | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) return undefined;
  const minBuild = (value as { minBuild?: unknown }).minBuild;
  return typeof minBuild === "number" && Number.isSafeInteger(minBuild) && minBuild > 0 ? { minBuild } : {};
}

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
      const upgrade = parseUpgrade(item.upgrade);
      actions.push({ id: item.id, kind: "plugin", pluginId: item.pluginId, contributionId: item.contributionId, label: item.label, order,
        ...(icon ? { icon } : {}), ...(upgrade ? { upgrade } : {}) });
    }
  }
  return { tools, actions };
}

/** A chat keeps its primary toolbar and shows file picking when there are no optional panel entries. */
export function resolveChatComposerMenu(menu: ComposerMenu, availableCalls: readonly string[]): ComposerMenu {
  const seen = new Set<string>();
  const actions = menu.actions.filter(item => {
    if (item.kind === "feature" && (item.id === "image" || item.id === "voice")) return false;
    if (item.kind === "plugin" && item.pluginId === "flare.call" && !item.upgrade) {
      const call = item.contributionId === "flare.call.audio" ? "audioCall"
        : item.contributionId === "flare.call.video" ? "videoCall" : undefined;
      if (call && !availableCalls.includes(call)) return false;
    }
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
  return {
    tools: [...new Set([...FLARE_STANDARD_COMPOSER_TOOL_IDS, ...menu.tools])],
    actions: actions.length ? actions : [{ id: "file", kind: "feature", icon: "file", order: 30 }],
  };
}

/**
 * The "+" panel items in the kit's action shape, in the menu's order. Built-in items carry no label
 * (the kit names its unified ids); a plugin's unknown icon name draws the kit's plugin glyph. An upgrade
 * placeholder carries `upgradeBadge` (the kit's `pluginUpgrade.badge` copy) as its badge.
 */
export function composerPanelActions(menu: ComposerMenu, upgradeBadge?: string) {
  return menu.actions.map((item, index) => ({
    id: item.id,
    kind: item.kind,
    // The SDK already ordered built-ins and authorized plugins. Preserve that
    // sequence when a kit re-sorts action priorities (including negative plugin priorities).
    order: index,
    ...(item.kind === "plugin" ? { label: item.label } : {}),
    ...(item.icon ? { icon: item.icon } : {}),
    ...(item.kind === "plugin" && item.upgrade && upgradeBadge ? { badge: upgradeBadge } : {}),
  }));
}

export interface ComposerActionRoutes {
  /** Built-in items the host sends itself (card, poll). Pickers and voice stay with the kit. */
  features: Readonly<Record<string, () => void>>;
  /** Plugins with a native page, by `pluginId/contributionId`. */
  plugins: Readonly<Record<string, (item: ComposerPluginItem) => void>>;
  /** Every other plugin: the generic entry. */
  fallback: (item: ComposerPluginItem) => void;
  /** An upgrade placeholder: the upgrade notice (`PluginUpgradeSheet`), never the form. Without it nothing happens. */
  upgrade?: (item: ComposerPluginItem) => void;
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
  if (item.upgrade) {
    if (!routes.upgrade) return false;
    routes.upgrade(item);
    return true;
  }
  (routes.plugins[`${item.pluginId}/${item.contributionId}`] ?? routes.fallback)(item);
  return true;
}

/**
 * A "+" item that is only a way into one page: its contribution shows nothing (no field, block or input) and has
 * exactly one action, a page target with no confirm, form or disabled reason. The host opens that page at once instead
 * of a sheet with one key; any plugin can be such an entry, so no host names one.
 */
export function composerDirectPage(view: FlarePluginViewModel & { bundle?: boolean }): FlarePluginAction | undefined {
  if (!view.available || view.bundle || view.fields.length || view.blocks?.length || view.inputs?.length
    || view.menuActions?.length || view.actions.length !== 1) return;
  const action = view.actions[0]!;
  return action.target?.kind === "page" && !action.confirm && !action.form?.length && !action.disabledReason ? action : undefined;
}

/** Reloads the current conversation's optional menu and keeps the last successful read on failure. */
export function useComposerMenu(load: (conversationId: string) => Promise<unknown>, conversationId: () => string,
  onRefresh?: () => void) {
  const menu = shallowRef<ComposerMenu>(CLOSED_COMPOSER_MENU);
  const status = shallowRef<"loading" | "ready" | "failed">("loading");
  let generation = 0;
  const cache = new Map<string, ComposerMenu>();
  async function refresh(): Promise<void> {
    const mine = ++generation, id = conversationId();
    status.value = "loading";
    menu.value = cache.get(id) ?? CLOSED_COMPOSER_MENU;
    onRefresh?.();
    if (!id) { menu.value = CLOSED_COMPOSER_MENU; status.value = "ready"; return; }
    try {
      const value = parseComposerMenu(await load(id));
      if (mine === generation) { cache.set(id, value); menu.value = value; status.value = "ready"; }
    } catch {
      if (mine === generation) status.value = "failed";
    }
  }
  watch(conversationId, () => { void refresh(); }, { immediate: true });
  const onVisible = () => { if (document.visibilityState === "visible") void refresh(); };
  if (typeof document !== "undefined") document.addEventListener("visibilitychange", onVisible);
  onBeforeUnmount(() => {
    generation++;
    if (typeof document !== "undefined") document.removeEventListener("visibilitychange", onVisible);
  });
  return { menu, status, refresh };
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
