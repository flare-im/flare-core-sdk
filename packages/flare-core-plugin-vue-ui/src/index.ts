import { inject, onBeforeUnmount, provide, type Ref } from "vue";
import { provideFlareMessageRenderers, useFlareMessageRenderers } from "@flare-im/vue-ui";
import type { PluginUiSession } from "@flare-im/sdk/plugin-ui";
import {
  pluginUiConversationKey, pluginUiDirectoryKey, pluginUiErrorTextKey, pluginUiSessionKey, pluginUiStateFeedKey,
  type CorePluginDirectory, type CorePluginErrorText, type CorePluginStateFeed,
} from "./context";
import PluginMessage from "./PluginMessage.vue";
/** The generic card, for hosts that render some plugins with their own components and the rest with this. */
export { PluginMessage as CorePluginMessage };
/** The generic "+" entry for a plugin item the host has no page for. */
export { default as PluginComposerSheet } from "./PluginComposerSheet.vue";
export * from "./composerMenu";
/** A plugin page (a 我 entry, a card's page target) over the core SDK's `pluginPage`, with its own page stack. */
export { default as CorePluginPage } from "./CorePluginPage.vue";
export { corePluginPageEntry, corePluginPageSession, type CorePluginPageEntry } from "./pluginPage";
export { usePluginMemberSearch } from "./memberSearch";
export { CORE_PLUGIN_STATE_CHANNEL, createCorePluginStateFeed, usePluginPostedCards, type CorePluginStateHub } from "./hostFeeds";
export type { CorePluginDirectory, CorePluginErrorText, CorePluginStateChange, CorePluginStateFeed } from "./context";

export interface CorePluginUiOptions extends CorePluginDirectory {
  /** The conversation the timeline shows; card actions are dispatched bound to it. */
  conversationId?: () => string | undefined;
  /** Card state changes (the SDK's `onMessagePluginStateChanged`): a card presents again when its message is named. */
  stateChanges?: CorePluginStateFeed;
  /** The host's copy for a failed plugin call (`sdk.plugin.*`). */
  errorText?: CorePluginErrorText;
}

/** Call in the chat owner and reset the session when tenant/user changes. `resolveUser` and `members` are the
 * directory cards and the "+" entry use (see `provideCorePluginDirectory`). */
export function provideCorePluginUi(session: Ref<PluginUiSession | null>, options: CorePluginUiOptions = {}): void {
  provide(pluginUiSessionKey, session);
  if (options.conversationId) provide(pluginUiConversationKey, options.conversationId);
  if (options.resolveUser || options.members) provideCorePluginDirectory({ resolveUser: options.resolveUser, members: options.members });
  if (options.stateChanges) provide(pluginUiStateFeedKey, options.stateChanges);
  if (options.errorText) provide(pluginUiErrorTextKey, options.errorText);
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
