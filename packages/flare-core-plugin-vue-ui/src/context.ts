import type { InjectionKey, Ref } from "vue";
import type { FlarePluginMember, FlarePluginResolveUser } from "@flare-im/vue-ui";
import type { NativePluginBridge, PluginUiSession } from "@flare-im/sdk/plugin-ui";
export const pluginUiSessionKey: InjectionKey<Ref<PluginUiSession | null>> = Symbol("core-plugin-ui-session");
export const pluginUiNativeKey: InjectionKey<NativePluginBridge> = Symbol("core-plugin-ui-native");
/** The conversation the timeline shows; card actions are dispatched bound to it. */
export const pluginUiConversationKey: InjectionKey<() => string | undefined> = Symbol("core-plugin-ui-conversation");

/** Who the people in plugin cards are, as the host knows them. Both members are optional. */
export interface CorePluginDirectory {
  /** Binds code encoding to the trusted page plugin, never a plugin-supplied route key. */
  encodePluginCode?: (pluginId: string, token: string) => Promise<string>;
  /** Name and avatar of a user id (people and entries blocks); sync or async. Unknown ids draw the kit's fallback. */
  resolveUser?: FlarePluginResolveUser;
  /**
   * Members of the open conversation, offered by `members` form inputs. Read when a card or the
   * "+" entry renders, so return a stable array (a computed's value), not a new one per call.
   */
  members?: () => FlarePluginMember[] | undefined;
}
export const pluginUiDirectoryKey: InjectionKey<CorePluginDirectory> = Symbol("core-plugin-ui-directory");

/**
 * One card whose stored state moved: the core SDK's `onMessagePluginStateChanged` (an action result, the shared layer
 * pushed by Core, the viewer layer read in the background, or the catalog invalidated). `messageId` is the id the card
 * was presented with (the server id).
 */
export interface CorePluginStateChange {
  messageId: string;
  conversationId?: string;
}
/** Subscribes to card state changes; returns the unsubscribe. The host forwards the SDK event into it. */
export type CorePluginStateFeed = (listener: (change: CorePluginStateChange) => void) => () => void;
export const pluginUiStateFeedKey: InjectionKey<CorePluginStateFeed> = Symbol("core-plugin-ui-state-feed");

/**
 * The host's words for a failed plugin call (the SDK reports `sdk.plugin.*` keys, the host owns their copy).
 * Undefined keeps the kit's generic line.
 */
export type CorePluginErrorText = (error: unknown) => string | undefined;
export const pluginUiErrorTextKey: InjectionKey<CorePluginErrorText> = Symbol("core-plugin-ui-error-text");
