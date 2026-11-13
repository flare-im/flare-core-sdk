import { inject, onBeforeUnmount, provide, type Ref } from "vue";
import { provideFlareMessageRenderers, useFlareMessageRenderers } from "@flare-im/vue-ui";
import type { PluginUiSession } from "@flare-im/sdk/plugin-ui";
import {
  pluginUiConversationKey, pluginUiDirectoryKey, pluginUiErrorTextKey, pluginUiHostKey, pluginUiSessionKey, pluginUiStateFeedKey,
  type CorePluginDirectory, type CorePluginErrorText, type CorePluginHost, type CorePluginStateFeed,
} from "./context";
import PluginMessage from "./PluginMessage.vue";
/** The generic card, for hosts that render some plugins with their own components and the rest with this. */
export { PluginMessage as CorePluginMessage };
/** The generic "+" entry for a plugin item the host has no page for. */
export { default as PluginComposerSheet } from "./PluginComposerSheet.vue";
/** The upgrade notice of a "+" or 我 entry this build cannot draw (an entry with `upgrade`). */
export { default as PluginUpgradeSheet } from "./PluginUpgradeSheet.vue";
export * from "./composerMenu";
/** A plugin page (a 我 entry, a card's page target) over the core SDK's `pluginPage`, with its own page stack. */
export { default as CorePluginPage } from "./CorePluginPage.vue";
export { corePluginPageEntry, corePluginPageSession, type CorePluginPageEntry } from "./pluginPage";
export { usePluginMemberSearch } from "./memberSearch";
export { CORE_PLUGIN_STATE_CHANNEL, createCorePluginStateFeed, usePluginPostedCards, type CorePluginStateHub } from "./hostFeeds";
export type { CorePluginBundleHost, CorePluginDirectory, CorePluginErrorText, CorePluginHost, CorePluginStateChange, CorePluginStateFeed } from "./context";
/** A contribution's web bundle variant (a page, a card's detail, a "+" form) in the kit's bundle host, with its fallback. */
export { default as CorePluginBundle } from "./CorePluginBundle.vue";
export { CORE_PLUGIN_BUNDLE_MAX_FAILURES, corePluginBundleFailed, corePluginBundleGaveUp, corePluginBundleResultData, resetCorePluginBundleFailures } from "./pluginBundle";
/** The engine's bundle events channel and the hub the host routes them into. */
export { PLUGIN_BUNDLE_EVENT_CHANNEL, createPluginBundleEventHub, browserBundleRuntime, type PluginBundleEventHub } from "@flare-im/sdk/plugin-ui";
export { corePluginUpgradeKey, useCorePluginUpgrade, type CorePluginUpgradeSubject } from "./upgrade";
/** The host's part of plugin capabilities (consent, document capture, file pick, payment confirmation, one location
 * fix) for browser and webview hosts: mount once while signed in, fed from `im://plugin_capability_request`. */
export { default as CorePluginCapabilityHost } from "./CorePluginCapabilityHost.vue";
/** The capabilities the viewer allowed "always", as settings rows that take one back. */
export { default as CorePluginConsentList } from "./CorePluginConsentList.vue";
export {
  CORE_PLUGIN_CAPABILITY_REQUEST_CHANNEL, browserLocateOnce, browserPickFile, corePluginCapabilityFile, corePluginCapabilityRequest,
  createCorePluginCapabilityRequestFeed, type CorePluginCapabilityMethod, type CorePluginCapabilityRequest,
  type CorePluginCapabilityRequestFeed, type CorePluginCapabilityRequestHub, type CorePluginCapabilityResult,
} from "./capabilityRequests";

export interface CorePluginUiOptions extends CorePluginDirectory {
  /** The conversation the timeline shows; card actions are dispatched bound to it. */
  conversationId?: () => string | undefined;
  /** Card state changes (the SDK's `onMessagePluginStateChanged`): a card presents again when its message is named. */
  stateChanges?: CorePluginStateFeed;
  /** The host's copy for a failed plugin call (`sdk.plugin.*`). */
  errorText?: CorePluginErrorText;
  /** Upgrade notices and image blocks (see `CorePluginHost`). */
  host?: CorePluginHost;
}

/** Call in the chat owner and reset the session when tenant/user changes. `resolveUser` and `members` are the
 * directory cards and the "+" entry use (see `provideCorePluginDirectory`). */
export function provideCorePluginUi(session: Ref<PluginUiSession | null>, options: CorePluginUiOptions = {}): void {
  provide(pluginUiSessionKey, session);
  if (options.conversationId) provide(pluginUiConversationKey, options.conversationId);
  if (options.resolveUser || options.members) provideCorePluginDirectory({ resolveUser: options.resolveUser, members: options.members });
  if (options.stateChanges) provide(pluginUiStateFeedKey, options.stateChanges);
  if (options.errorText) provide(pluginUiErrorTextKey, options.errorText);
  if (options.host) provideCorePluginHost(options.host);
  provideFlareMessageRenderers({ ...useFlareMessageRenderers(), "custom:flare.plugin.message.v1": PluginMessage });
}
/**
 * Who the people in plugin cards are: names and avatars for user ids (people, entries) and the open
 * conversation's members (members inputs of card forms and the "+" entry). Call in the chat owner,
 * next to `provideCorePluginUi` or a plugin's own provider that calls it; without it cards draw the
 * kit's fallback names and members inputs offer nobody.
 */
export function provideCorePluginDirectory(directory: CorePluginDirectory): void {
  provide(pluginUiDirectoryKey, directory);
}

/** Upgrade notices and image blocks for the plugin cards and pages below (a 我 page with no chat owner above it). */
export function provideCorePluginHost(host: CorePluginHost): void {
  provide(pluginUiHostKey, host);
}

/**
 * For a card component: run `onChange` whenever the provided feed names this card's message. Nothing is polled; a card
 * without a feed above it presents once and on its own actions.
 */
export function useCorePluginStateChanges(messageId: () => string | undefined, onChange: () => void): void {
  const feed = inject(pluginUiStateFeedKey, null);
  if (!feed) return;
  const stop = feed((change) => {
    const id = messageId();
    if (id && change.messageId === id) onChange();
  });
  onBeforeUnmount(stop);
}

/** The provided copy for a failed plugin call, or undefined (the caller's generic line). */
export function useCorePluginErrorText(): CorePluginErrorText {
  return inject(pluginUiErrorTextKey, () => undefined);
}
