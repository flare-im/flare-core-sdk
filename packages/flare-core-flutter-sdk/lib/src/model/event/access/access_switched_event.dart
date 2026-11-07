// GENERATED. Do not edit by hand.
import 'access_endpoint.dart';

/// Payload of access://switched: the IM connection moved to another access point (sent once, when the new connection is ready).
final class AccessSwitchedEvent {
  /// wire: `from`. Where the connection was.
  final AccessEndpoint from;
  /// wire: `to`. Where the connection is now.
  final AccessEndpoint to;
  /// wire: `reason`. Why: failure, drain, failback, manual or manifest.
  final String reason;

  const AccessSwitchedEvent({
    required this.from,
    required this.to,
    this.reason = '',
  });
}
