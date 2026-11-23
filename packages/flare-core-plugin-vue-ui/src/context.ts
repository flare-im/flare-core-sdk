import type { InjectionKey, Ref } from "vue";
import type {
  FlarePluginImageSource, FlarePluginMember, FlarePluginResolveUser, FlarePluginUpgradeStatus,
} from "@flare-im/vue-ui";
import type { NativePluginBridge, PluginBundleEventHub, PluginBundleOpened, PluginBundlePort, PluginUiSession } from "@flare-im/sdk/plugin-ui";
import type { CorePluginPageEntry } from "./pluginPage";
export const pluginUiSessionKey: InjectionKey<Ref<PluginUiSession | null>> = Symbol("core-plugin-ui-session");
export const pluginUiNativeKey: InjectionKey<NativePluginBridge> = Symbol("core-plugin-ui-native");
/** The conversation the timeline shows; card actions are dispatched bound to it. */
export const pluginUiConversationKey: InjectionKey<() => string | undefined> = Symbol("core-plugin-ui-conversation");
/** The kind of the conversation the timeline shows, as a plugin web bundle's hello names it. */
export type CorePluginConversationType = "single" | "group";
/** The open conversation's type, read when a card opens its detail bundle. */
export const pluginUiConversationTypeKey: InjectionKey<() => CorePluginConversationType | undefined> = Symbol("core-plugin-ui-conversation-type");
/**
 * A page a plugin surface asks the host to open beside the chat: a card's detail bundle that navigates (`ui.navigate`
 * to a page of its plugin). The host shows it its own way, usually as a `CorePluginPage` with this entry as the root.
 */
export type CorePluginOpenPage = (entry: CorePluginPageEntry) => void;
export const pluginUiOpenPageKey: InjectionKey<CorePluginOpenPage> = Symbol("core-plugin-ui-open-page");

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

/**
 * What the host does for plugin views beyond calling Core: upgrade notices and image blocks. Every member is optional;
 * without one the kit keeps its fallback (the notice's description without a key, the "image unavailable" frame).
 */
export interface CorePluginHost {
  /** Browsing long card records can use a full-height page on Web hosts. */
  detailPresentation?: "sheet" | "page";
  /** `update.plugin_upgrade_status` for an upgrade placeholder's `minBuild` (the social SDK's `plugins.upgradeStatus`). */
  upgradeStatus?: (minBuild?: number) => Promise<FlarePluginUpgradeStatus>;
  /** `update.open_flow`: the "Update" key of an upgrade notice; the app's update prompt draws the flow. */
  openUpdate?: () => Promise<void>;
  /** An image block's address: an asset path of the plugin or a private file id, read the host's way. */
  resolveImage?: (source: FlarePluginImageSource) => string | undefined | Promise<string | undefined>;
  /** The native capabilities page actions may run here (those of the host's native allowlist, e.g. `webClipboardBridge`). */
  native?: NativePluginBridge;
  /**
   * Plugin web bundles (L3): pages, card details and "+" forms whose bundle variant Core selected open in the kit's
   * FlarePluginBundleHost; without it (or when the engine offers no bundle) the declarative variant draws.
   */
  bundles?: CorePluginBundleHost;
}

/** What a browser or webview host provides for plugin web bundles. */
export interface CorePluginBundleHost {
  /** The engine's bundle routes (the social SDK's `plugins` facade). */
  port: PluginBundlePort;
  /** The engine's bundle events (`im://plugin_bundle_event`), routed into it by the host. */
  events: PluginBundleEventHub;
  /** The app's theme for the bundle's hello and `theme.changed`. */
  theme: () => { mode: "light" | "dark"; tokens?: Record<string, string> };
  /**
   * The frame's file base of an opened page. Web: the unpacked copy on the sandbox domain (`opened.root`, the default).
   * Tauri: registers the cache files with the app's `flare-plugin` protocol and answers `flare-plugin://{key}/{sha256}/`
   * (one registration per bundle version).
   */
  files?: (opened: PluginBundleOpened) => string | Promise<string>;
  /** The page closed: a host that registered files drops them. */
  released?: (opened: PluginBundleOpened) => void;
  /** Web: the app's https origin, for the bundle policy's `frame-ancestors`. */
  hostOrigin?: () => string | undefined;
  /** Opens a confirmed https link (Tauri: the system browser); a new browsing context by default. */
  openExternal?: (url: string) => void | Promise<void>;
}
export const pluginUiHostKey: InjectionKey<CorePluginHost> = Symbol("core-plugin-ui-host");
