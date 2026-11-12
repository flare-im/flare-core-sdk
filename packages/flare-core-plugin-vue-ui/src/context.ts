import type { InjectionKey, Ref } from "vue";
import type {
  FlarePluginImageSource, FlarePluginMember, FlarePluginResolveUser, FlarePluginUpgradeStatus,
} from "@flare-im/vue-ui";
import type { NativePluginBridge, PluginUiSession } from "@flare-im/sdk/plugin-ui";
export const pluginUiSessionKey: InjectionKey<Ref<PluginUiSession | null>> = Symbol("core-plugin-ui-session");
/** The conversation the timeline shows; card actions are dispatched bound to it. */
export const pluginUiConversationKey: InjectionKey<() => string | undefined> = Symbol("core-plugin-ui-conversation");

/** Who the people in plugin cards are, as the host knows them. Both members are optional. */
export interface CorePluginDirectory {
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

/**
 * What the host does for plugin views beyond calling Core: upgrade notices and image blocks. Every member is optional;
 * without one the kit keeps its fallback (the notice's description without a key, the "image unavailable" frame).
 */
export interface CorePluginHost {
  /** `update.plugin_upgrade_status` for an upgrade placeholder's `minBuild` (the social SDK's `plugins.upgradeStatus`). */
  upgradeStatus?: (minBuild?: number) => Promise<FlarePluginUpgradeStatus>;
  /** `update.open_flow`: the "Update" key of an upgrade notice; the app's update prompt draws the flow. */
  openUpdate?: () => Promise<void>;
  /** An image block's address: an asset path of the plugin or a private file id, read the host's way. */
  resolveImage?: (source: FlarePluginImageSource) => string | undefined | Promise<string | undefined>;
  /** The native capabilities page actions may run here (those of the host's native allowlist, e.g. `webClipboardBridge`). */
  native?: NativePluginBridge;
}
export const pluginUiHostKey: InjectionKey<CorePluginHost> = Symbol("core-plugin-ui-host");
