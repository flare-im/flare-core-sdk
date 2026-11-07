import 'flare_update_models.dart';

/// Carries out an install plan. Platform capability only: the engine decides
/// what to install and whether it is trustworthy, and the Dart layer holds no
/// update logic of its own.
///
/// The Flutter plugin `flare_core_flutter_update` implements it on the host
/// platforms.
abstract interface class FlareUpdateInstaller {
  /// Runs [plan] to its end and says how it went. A store page that opened is
  /// `completed`; `started` is for work that goes on in the background, whose
  /// end comes through [handoffs]. An install that replaces the running process
  /// never returns.
  Future<FlareUpdateInstallResult> execute(FlareUpdateInstallPlan plan);

  /// False when the store says it has nothing for [release], so the user
  /// should not hear of it.
  Future<bool> canPrompt(FlareUpdateRelease release);

  /// The progress of an update a store took over; empty for hosts without one.
  Stream<FlareUpdateHandoff> handoffs();

  /// Finishes a `restartReady` handoff. The user asked for it; the app
  /// restarts.
  Future<FlareUpdateInstallResult> completeHandoff();
}

/// The engine as the controller needs it. It references no client, so a host
/// wires in whichever engine it runs: the core client or the social SDK.
abstract interface class FlareUpdateEngine {
  /// Calls an `update.*` route ([FlareUpdateOperations]) and returns its
  /// decoded JSON object. A refusal is a [FlareUpdateException] carrying the
  /// error code.
  Future<Map<String, Object?>> dispatch(
    String operation, [
    Map<String, Object?> params = const {},
  ]);

  /// Every `update://state` payload.
  Stream<Map<String, Object?>> stateEvents();
}
