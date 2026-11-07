// GENERATED. Do not edit by hand.
// Module API: `lifecycle` — Platform lifecycle signals the core needs (foreground and background).
import '../../model/model.dart';

/// Platform lifecycle signals the core needs (foreground and background).
abstract interface class LifecycleApi {
  /// setAppState maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `lifecycle.set_app_state`.
  Future<void> setAppState(SetAppStateRequest request);
}
