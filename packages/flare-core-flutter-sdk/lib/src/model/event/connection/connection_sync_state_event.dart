// GENERATED. Do not edit by hand.

/// Payload of the coarse sync state hint (connection.sync_state_changed). Connection status itself arrives as ConnectionStatus.
final class ConnectionSyncStateEvent {
  /// wire: `state`. The core sync state name.
  final String state;

  const ConnectionSyncStateEvent({
    this.state = '',
  });
}
