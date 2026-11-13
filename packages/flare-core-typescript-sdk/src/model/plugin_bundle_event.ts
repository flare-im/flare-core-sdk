/** GENERATED. Do not edit by hand. */

/** Something for an open web bundle page. */
export interface PluginBundleEvent {
  /** wire: `sessionId`. The page's session (pluginBundleOpen). */
  sessionId: string;
  /** wire: `envelope`. A bridge event to post to the page as it is: catalog.changed, entity.state, lifecycle.revoked. */
  envelope?: string;
  /** wire: `close`. Close the page: withdrawn, suspended, disabled, replaced, evicted or signedOut. */
  close?: string;
}
