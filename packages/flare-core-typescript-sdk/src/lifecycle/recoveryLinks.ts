/**
 * Recovery links reaching a desktop app from the system (`flare-recover://`). The deep link plugin is the app's: this
 * package does not depend on it, and only its two functions are used.
 */

const RECOVERY_SCHEME = "flare-recover://";

/** `getCurrent` and `onOpenUrl` of `@tauri-apps/plugin-deep-link`. */
export interface DeepLinkSource {
  /** The link the app was started with: `onOpenUrl` only reports what arrives while it runs. */
  getCurrent(): Promise<string[] | null>;
  onOpenUrl(handler: (urls: string[]) => void): Promise<unknown>;
}

/**
 * Calls `onLink` with every recovery link: the one the app was started with, then each one that arrives. The link
 * goes to `access.import_recovery` verbatim, which judges it; other schemes are not this function's.
 */
export async function followRecoveryLinks(source: DeepLinkSource, onLink: (link: string) => void): Promise<void> {
  const take = (urls: readonly string[] | null): void => {
    const link = urls?.find((url) => url.toLowerCase().startsWith(RECOVERY_SCHEME));
    if (link) onLink(link);
  };
  await source.onOpenUrl(take);
  take(await source.getCurrent());
}
