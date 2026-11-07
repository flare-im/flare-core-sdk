// GENERATED. Do not edit by hand.
import '../model/model.dart';

/// Connection listener callbacks.
abstract class ConnectionEventListener {
  const ConnectionEventListener();
  /// The connection status changed (connection://status). Replace the held status whole and hand it to the Kit ConnectionNotice unchanged.
  void onConnectionStatusChanged(ConnectionStatus event) {}
}
