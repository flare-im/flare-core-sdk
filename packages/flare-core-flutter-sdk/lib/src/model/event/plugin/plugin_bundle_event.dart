// GENERATED. Do not edit by hand.

/// Something for an open web bundle page.
final class PluginBundleEvent {
  /// wire: `sessionId`. The page's session (pluginBundleOpen).
  final String sessionId;
  /// wire: `envelope`. A bridge event to post to the page as it is: catalog.changed, entity.state, lifecycle.revoked.
  final String? envelope;
  /// wire: `close`. Close the page: withdrawn, suspended, disabled, replaced, evicted or signedOut.
  final String? close;

  const PluginBundleEvent({
    this.sessionId = '',
    this.envelope,
    this.close,
  });
}
