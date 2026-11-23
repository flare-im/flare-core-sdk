import { inject, onBeforeUnmount, provide, type Ref } from "vue";
import { provideFlareMessageRenderers, useFlareMessageRenderers } from "@flare-im/vue-ui";
import type { NativePluginBridge, PluginUiSession } from "@flare-im/sdk/plugin-ui";
import {
  pluginUiConversationKey, pluginUiConversationTypeKey, pluginUiDirectoryKey, pluginUiErrorTextKey, pluginUiHostKey, pluginUiOpenPageKey,
  pluginUiSessionKey, pluginUiStateFeedKey, pluginUiNativeKey,
  type CorePluginConversationType, type CorePluginDirectory, type CorePluginErrorText, type CorePluginHost, type CorePluginOpenPage,
  type CorePluginStateFeed,
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
export { corePluginPageEntry, corePluginPageSession, type CorePluginPageEntry, type CorePluginPagePromptPolicy } from "./pluginPage";
export { usePluginMemberSearch } from "./memberSearch";
export { CORE_PLUGIN_STATE_CHANNEL, createCorePluginStateFeed, usePluginPostedCards, type CorePluginStateHub } from "./hostFeeds";
export type {
  CorePluginBundleHost, CorePluginConversationType, CorePluginDirectory, CorePluginErrorText, CorePluginHost, CorePluginOpenPage,
  CorePluginStateChange, CorePluginStateFeed,
} from "./context";
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
  /** Trusted host capabilities, shared by page stacks and card/composer sessions. */
  native?: NativePluginBridge;
  /** The conversation the timeline shows; card actions are dispatched bound to it. */
  conversationId?: () => string | undefined;
  /**
   * That conversation's type, `single` or `group` (or a getter, for a chat owner whose conversation changes). A card's
   * detail web bundle is told it in its hello; without it the bundle gets an empty type, as before.
   */
  conversationType?: CorePluginConversationType | (() => CorePluginConversationType | undefined);
  /**
   * Opens a page beside the chat when a card's detail web bundle navigates to a page of its plugin (`ui.navigate` with
   * `page`); the entry carries the plugin, the page, its arguments and the conversation. The detail sheet stays open,
   * as on Flutter. Without it such a navigation does nothing, as before.
   */
  openPage?: CorePluginOpenPage;
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
  if (options.native) provideCorePluginNativeBridge(options.native);
  if (options.conversationId) provide(pluginUiConversationKey, options.conversationId);
  if (options.conversationType) {
    const type = options.conversationType;
    provide(pluginUiConversationTypeKey, typeof type === "function" ? type : () => type);
  }
  if (options.openPage) provide(pluginUiOpenPageKey, options.openPage);
  if (options.resolveUser || options.members || options.encodePluginCode) provideCorePluginDirectory({ resolveUser: options.resolveUser, members: options.members, encodePluginCode: options.encodePluginCode });
  if (options.stateChanges) provide(pluginUiStateFeedKey, options.stateChanges);
  if (options.errorText) provide(pluginUiErrorTextKey, options.errorText);
  if (options.host) provideCorePluginHost(options.host);
  provideFlareMessageRenderers({ ...useFlareMessageRenderers(), "custom:flare.plugin.message.v1": PluginMessage });
}
/** Install once above page/card owners; implementations belong to the SDK host. */
export function provideCorePluginNativeBridge(bridge: NativePluginBridge): void { provide(pluginUiNativeKey, bridge); }
export function useCorePluginNativeBridge(): NativePluginBridge | undefined { return inject(pluginUiNativeKey, undefined); }
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
export { offerCapturedPhoto } from "./capturedPhotos";
