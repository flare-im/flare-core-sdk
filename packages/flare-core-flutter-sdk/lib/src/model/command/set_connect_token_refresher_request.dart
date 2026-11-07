// GENERATED. Do not edit by hand.

/// Installs or removes the host's connect token refresher at the native boundary. Platform packages build it from their one host function; hosts do not send it themselves.
final class SetConnectTokenRefresherRequest {
  /// wire: `enabled`. Whether a refresher is installed.
  final bool enabled;

  const SetConnectTokenRefresherRequest({
    this.enabled = false,
  });
}
