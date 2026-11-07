// GENERATED. Do not edit by hand.
import '../model/model.dart';

/// Access listener callbacks.
abstract class AccessEventListener {
  const AccessEventListener();
  /// The IM connection moved to another access point (access://switched).
  void onAccessSwitched(AccessSwitchedEvent event) {}
  /// A new access manifest was accepted (access://changed).
  void onAccessChanged(AccessChangedEvent event) {}
}
