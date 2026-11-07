// GENERATED. Do not edit by hand.
import '../model/model.dart';

/// Update listener callbacks.
abstract class UpdateEventListener {
  const UpdateEventListener();
  /// The update center state changed (update://state). Delivered with a session; before sign-in read update.getState.
  void onUpdateState(UpdateStatus event) {}
}
