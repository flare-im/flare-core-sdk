import { PluginUiSession, type PluginPageTarget, type PluginPlatform, type PluginUiPort } from "@flare-im/sdk/plugin-ui";
import { pluginPostedCard, type PluginPostedCard } from "./composerMenu";

/** A terminal posted result may close only the flow owned by this trusted conversation. */
export function pluginPagePostedCard(data: unknown, conversationId: string | undefined): PluginPostedCard | null {
  if (!conversationId?.trim()) return null;
  const posted = pluginPostedCard(data);
  return posted && posted.conversationId === conversationId && posted.serverMsgId.trim() && posted.clientMsgId.trim()
    ? posted : null;
}

/** One page on a plugin page stack: what to open and with which arguments (the opening action's payload). */
export interface CorePluginPageEntry {
  pluginId: string;
  page: string;
  /** The host's title while the page has none of its own (the title of the 我 entry that opened it). */
  title: string;
  args?: Record<string, unknown>;
  conversationId?: string;
}

/**
 * The entry a page target opens: its plugin, its page, the payload the action bound as its arguments. Hosts pass it
 * a card's page target (the navigate of their chat PluginUiSession) to open the page somewhere of their own.
 */
export function corePluginPageEntry(target: PluginPageTarget, args?: Record<string, unknown>, title = ""): CorePluginPageEntry {
  return { pluginId: target.pluginId, page: target.page, title, ...(target.conversationId ? { conversationId: target.conversationId } : {}), ...(args ? { args } : {}) };
}

/**
 * The session a page stack runs on: a page target an action opens is pushed with its own plugin and the payload the
 * action bound as its arguments; the top page's title stands in until the new page has its own.
 */
export function corePluginPageSession(port: PluginUiPort, platform: PluginPlatform, locale: () => string,
  top: () => CorePluginPageEntry | undefined, push: (entry: CorePluginPageEntry) => void): PluginUiSession {
  return new PluginUiSession(port, platform, locale, undefined, (target, args) => {
    push(corePluginPageEntry(target, args, top()?.title ?? ""));
  });
}
