// GENERATED. Do not edit by hand.

/// Result of accepting a new set of addresses. Link readiness is reported separately through normal connection status.
final class EndpointUpdate {
  /// wire: `changed`. 
  final bool changed;
  /// wire: `revision`. Accepted endpoint generation for this initialized client.
  final int revision;

  const EndpointUpdate({
    this.changed = false,
    this.revision = 0,
  });
}
