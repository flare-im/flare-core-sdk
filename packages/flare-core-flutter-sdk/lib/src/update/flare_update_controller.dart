import 'dart:async';

import 'flare_update_installer.dart';
import 'flare_update_models.dart';

/// Binds an app to the update center. The engine decides everything; this runs
/// the steps the platform has to take and keeps [status] current, so an app
/// hands [status] to the Kit and connects the Kit's callbacks to the methods
/// here, with no flow of its own.
///
/// Events only reach the host while there is a session, so they are not the
/// only source of [status]: the status is read on [install], on every
/// [foreground] event and on [onLoginSucceeded], every route's return value
/// is taken as the latest status, and while the state is `checking`,
/// `downloading` or `verifying` a silence of [pollInterval] triggers a read.
/// That read is also how a check ends: `update.check` answers at once with
/// `checking` and runs in the background.
///
/// The engine maintains `prompt` and `readOnly`, so an app binds them directly.
/// [status] only adds what the engine cannot know: a store that has nothing to
/// offer, a store update waiting for a restart. Apart from [refresh], methods
/// report a failure through `status.error` rather than by throwing.
final class FlareUpdateController {
  FlareUpdateController({
    required FlareUpdateEngine engine,
    required FlareUpdateInstaller installer,
    Stream<void>? foreground,
    void Function(Object error, StackTrace stackTrace)? onError,
    this.pollInterval = defaultPollInterval,
  })  : _engine = engine,
        _installer = installer,
        _foreground = foreground,
        _onError = onError;

  /// How long a running operation may stay silent before the status is read.
  static const Duration defaultPollInterval = Duration(milliseconds: 500);

  static const Set<FlareUpdateState> _downloadStates = {
    FlareUpdateState.downloading,
    FlareUpdateState.verifying,
  };
  static const Set<FlareUpdateState> _polledStates = {
    FlareUpdateState.checking,
    FlareUpdateState.downloading,
    FlareUpdateState.verifying,
  };

  final Duration pollInterval;
  final FlareUpdateEngine _engine;
  final FlareUpdateInstaller _installer;
  final Stream<void>? _foreground;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  final StreamController<FlareUpdateStatus> _statuses =
      StreamController<FlareUpdateStatus>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  FlareUpdateStatus? _shown;
  FlareUpdateStatus? _engineStatus;
  FlareUpdateHandoff _handoff = FlareUpdateHandoff.none;
  int _revision = 0;
  Timer? _pollTimer;
  bool _installed = false;
  bool _disposed = false;
  bool _updating = false;

  FlareUpdateError? _localError;
  bool _sentToBackground = false;
  String? _pendingLocale;
  bool _sendingLocale = false;
  ({int build, bool open})? _storeAnswer;

  /// The latest status for the UI; null until the first read.
  FlareUpdateStatus? get status => _shown;

  /// Every change of [status].
  Stream<FlareUpdateStatus> get statuses => _statuses.stream;

  /// Starts listening and reads the current status. Calling it again does
  /// nothing.
  void install() {
    if (_installed || _disposed) return;
    _installed = true;
    _subscriptions
      ..add(_engine.stateEvents().listen(_onEvent, onError: _reportError))
      ..add(_installer.handoffs().listen(
            (handoff) => unawaited(_onHandoff(handoff)),
            onError: _reportError,
          ));
    final foreground = _foreground;
    if (foreground != null) {
      _subscriptions.add(foreground.listen(
        (_) => _onForeground(),
        onError: _reportError,
      ));
    }
    _readInBackground();
  }

  /// Stops listening; later statuses are dropped.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    await Future.wait(_subscriptions.map((item) => item.cancel()));
    _subscriptions.clear();
    await _statuses.close();
  }

  /// Reads the status again; events do not arrive before login, so call this
  /// when login succeeds.
  void onLoginSucceeded() => _readInBackground();

  /// Reads the status again after a refused login: it leaves no session, so no
  /// event says the server turned this build away.
  void onLoginFailed() => _readInBackground();

  /// Reads the current status from the engine; a failed read throws.
  Future<FlareUpdateStatus> refresh() => _call(FlareUpdateOperations.getState);

  /// Tells the engine the language the app shows: the release notes and
  /// [FlareUpdateStatus.blockReason] follow it at once. Call it when the app
  /// reads its language at start and when the person changes it.
  ///
  /// Before `init` the engine refuses a language and does not keep it, so the
  /// value waits here for the first status, which only comes once the engine
  /// is up. One the engine refused goes again with the next status. A failure
  /// is no step of the update: it goes to `onError`, not to `status.error`.
  Future<void> setLocale(String locale) async {
    _pendingLocale = locale;
    if (_engineStatus != null) await _sendLocale();
  }

  /// The resource packs of this run, in `id` order. The engine reads them once
  /// when it starts, so what a check brings or withdraws shows on the next
  /// start and this answers the same all run. Packs are no step of the update
  /// and nothing waits for them: a failure goes to `onError`, not to
  /// `status.error`, and answers no packs, which leaves the app on its built-in
  /// resources.
  Future<List<FlareUpdateResourcePack>> loadResources() async {
    var packs = const <FlareUpdateResourcePack>[];
    await _quietly(() async {
      packs = FlareUpdateResourcePack.listFromMap(
        await _engine.dispatch(FlareUpdateOperations.getResources),
      );
    });
    return packs;
  }

  /// Starts a check for a release; [manual] is not held back by the check
  /// interval. The engine answers at once, with `checking` when a check runs,
  /// so the result is not what this returns: it reaches [status] by event or
  /// by the poll that state starts.
  Future<FlareUpdateStatus?> check({bool manual = true}) => _userAction(
        () => _call(FlareUpdateOperations.check, {'manual': manual}),
        fallback: FlareUpdateErrorCodes.manifestUnavailable,
      );

  /// Runs the update: download when the release needs one, then
  /// `update.install`, the plan, and `update.report_install`. When the last
  /// error asks for confirmation on a metered network, calling this again is
  /// that confirmation. A store update waiting for a restart restarts now.
  Future<FlareUpdateStatus?> update() async {
    _sentToBackground = false;
    if (_updating) return _shown;
    _updating = true;
    final allowMetered =
        _shown?.error?.code == FlareUpdateErrorCodes.meteredConfirmationRequired;
    try {
      return await _userAction(
        () => _runUpdate(allowMetered),
        fallback: FlareUpdateErrorCodes.installFailed,
      );
    } finally {
      _updating = false;
    }
  }

  /// Puts the prompt aside through `update.defer`; what that means is the
  /// engine's to decide. A download put aside goes on, and when it ends it
  /// waits for the user: an update they walked away from does not open the
  /// installer by itself.
  Future<FlareUpdateStatus?> later() {
    if (_downloadStates.contains(_engineStatus?.state)) {
      _sentToBackground = true;
    }
    return _userAction(() => _call(FlareUpdateOperations.defer));
  }

  /// Skips the optional release on offer; the engine refuses a forced one.
  Future<FlareUpdateStatus?> skip() async {
    final build = _engineStatus?.release?.build;
    if (build == null) return _shown;
    return _userAction(() => _call(FlareUpdateOperations.skip, {'build': build}));
  }

  /// Tells the engine the prompt in [status] is on screen, which is what its
  /// frequency rules count.
  Future<FlareUpdateStatus?> markPrompted() async {
    final shown = _shown;
    if (shown == null) return null;
    if (!shown.prompt.interrupts) return shown;
    // A forced prompt can stand before the manifest arrives, with no release to
    // name.
    final build = shown.release?.build;
    return _userAction(() => _call(
          FlareUpdateOperations.markPrompted,
          {if (build != null) 'build': build, 'form': shown.prompt.name},
        ));
  }

  /// Puts a forced update aside to browse read only. This is `update.defer`:
  /// the engine folds the prompt away, sets `readOnly`, and prompts again on the
  /// next start or return to the foreground. Does nothing when
  /// [FlareUpdateStatus.canContinueReadOnly] is false.
  Future<FlareUpdateStatus?> continueReadOnly() async {
    if (_engineStatus?.canContinueReadOnly != true) return _shown;
    return later();
  }

  /// Opens the fallback link of the last error; false when there is none or
  /// nothing can open it.
  Future<bool> openFallback() async {
    final url = _shown?.error?.fallbackUrl;
    if (url == null) return false;
    final result = await _installer.execute(
      FlareUpdateOpenStore(store: FlareUpdateOpenStore.website, url: url),
    );
    return result.outcome == FlareUpdateOutcome.completed;
  }

  /// One call at a time, so two quick changes cannot arrive out of order.
  Future<void> _sendLocale() async {
    final locale = _pendingLocale;
    if (locale == null || _sendingLocale) return;
    _sendingLocale = true;
    await _quietly(() async {
      await _call(FlareUpdateOperations.setLocale, {'locale': locale});
      if (_pendingLocale == locale) _pendingLocale = null;
    });
    _sendingLocale = false;
    final newer = _pendingLocale;
    if (newer != null && newer != locale) await _sendLocale();
  }

  Future<FlareUpdateStatus?> _runUpdate(bool allowMetered) async {
    if (_handoff == FlareUpdateHandoff.restartReady) {
      return _report(await _installer.completeHandoff());
    }
    var status = _engineStatus ?? await _call(FlareUpdateOperations.getState);
    final release = status.release;
    if (release == null) {
      // Refused by the server before any manifest arrived: find the release
      // instead of doing nothing. The check runs in the background; the poll
      // of `checking` brings the release to the prompt, which then offers it.
      if (status.state != FlareUpdateState.required) return status;
      return _call(FlareUpdateOperations.check, {'manual': true});
    }
    if (release.kind == FlareUpdateKind.package &&
        status.state != FlareUpdateState.readyToInstall) {
      if (!_downloadStates.contains(status.state)) {
        status = await _call(
          FlareUpdateOperations.download,
          {'allowMetered': allowMetered},
        );
      }
      status = await _downloaded(status);
      if (status.state != FlareUpdateState.readyToInstall ||
          _sentToBackground) {
        return status;
      }
    }
    final Map<String, Object?> planned;
    try {
      planned = await _engine.dispatch(FlareUpdateOperations.install);
    } on FlareUpdateException {
      // The refusal only names the code; the status also has what the Kit
      // needs next, such as the fallback link.
      await _quietly(refresh);
      rethrow;
    }
    final plan = FlareUpdateInstallPlan.fromMap(planned);
    // The route returns the plan, not a status; the state moved to
    // `installing`.
    await _call(FlareUpdateOperations.getState);
    return _report(await _installer.execute(plan));
  }

  Future<FlareUpdateStatus> _downloaded(FlareUpdateStatus status) {
    if (!_downloadStates.contains(status.state)) return Future.value(status);
    return statuses.firstWhere(
      (next) => !_downloadStates.contains(next.state),
      orElse: () => _shown ?? status,
    );
  }

  Future<FlareUpdateStatus> _report(FlareUpdateInstallResult result) =>
      _call(FlareUpdateOperations.reportInstall, result.toReportParams());

  Future<FlareUpdateStatus> _call(
    String operation, [
    Map<String, Object?> params = const {},
  ]) async =>
      _adopt(FlareUpdateStatus.fromMap(await _engine.dispatch(operation, params)));

  /// A step the user asked for: an earlier failure no longer stands, and a new
  /// one reaches `status.error` with the engine's code, or [fallback] when the
  /// failure carries none.
  Future<FlareUpdateStatus?> _userAction(
    Future<FlareUpdateStatus?> Function() action, {
    String? fallback,
  }) async {
    _localError = null;
    try {
      return await action();
    } on Exception catch (failure, stackTrace) {
      _reportError(failure, stackTrace);
      final refused = failure is FlareUpdateException ? failure : null;
      final code = refused?.code ?? fallback;
      if (code != null) {
        _localError = FlareUpdateError(
          code: code,
          retryable: refused?.retryable ?? true,
          fallbackUrl: refused?.fallbackUrl,
        );
        _publish();
      }
      return _shown;
    }
  }

  void _onEvent(Map<String, Object?> payload) {
    try {
      _adopt(FlareUpdateStatus.fromMap(payload));
    } on FlareUpdateWireError catch (malformed, stackTrace) {
      _reportError(malformed, stackTrace);
    }
  }

  void _onForeground() {
    // The store may have caught up with the release in the meantime.
    _storeAnswer = null;
    // Says so itself: `lifecycle.set_app_state` may arrive after this read, and
    // what is due on a return would then be missed until the next one.
    unawaited(_quietly(
      () => _call(FlareUpdateOperations.getState, {'foreground': true}),
    ));
  }

  Future<void> _onHandoff(FlareUpdateHandoff handoff) async {
    _handoff = handoff;
    _publish();
    final result = switch (handoff) {
      FlareUpdateHandoff.failed => const FlareUpdateInstallResult.failed(
          FlareUpdateErrorCodes.installFailed,
        ),
      FlareUpdateHandoff.cancelled =>
        const FlareUpdateInstallResult(FlareUpdateOutcome.cancelled),
      FlareUpdateHandoff.none || FlareUpdateHandoff.restartReady => null,
    };
    if (result != null) await _quietly(() => _report(result));
  }

  void _readInBackground() => unawaited(_quietly(refresh));

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _reportError(Object error, [StackTrace? stackTrace]) {
    _onError?.call(error, stackTrace ?? StackTrace.current);
  }

  /// Takes [status] as the latest word from the engine and returns what the UI
  /// now shows.
  FlareUpdateStatus _adopt(FlareUpdateStatus status) {
    if (_disposed) return _shown ?? status;
    _engineStatus = status;
    _revision += 1;
    final unanswered = _releaseToAskTheStoreAbout(status);
    _armPoll(status);
    _publish();
    if (unanswered != null) unawaited(_askTheStore(unanswered));
    if (_pendingLocale != null) unawaited(_sendLocale());
    return _shown ?? status;
  }

  /// Any status restarts the wait, so a poll only runs after a real silence.
  void _armPoll(FlareUpdateStatus status) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_polledStates.contains(status.state)) return;
    final seen = _revision;
    _pollTimer = Timer(pollInterval, () => unawaited(_poll(seen)));
  }

  Future<void> _poll(int seen) => _quietly(() async {
        final payload = await _engine.dispatch(FlareUpdateOperations.getState);
        // A status that arrived while this read was out is newer than what it
        // brings back.
        if (_revision == seen) _adopt(FlareUpdateStatus.fromMap(payload));
      });

  FlareUpdateRelease? _releaseToAskTheStoreAbout(FlareUpdateStatus status) {
    final release = status.release;
    if (release == null ||
        !_isStoreGated(release) ||
        _storeAnswer?.build == release.build) {
      return null;
    }
    _storeAnswer = (build: release.build, open: false);
    return release;
  }

  Future<void> _askTheStore(FlareUpdateRelease release) async {
    var open = false;
    try {
      open = await _installer.canPrompt(release);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
    if (_storeAnswer?.build == release.build) {
      _storeAnswer = (build: release.build, open: open);
    }
    _publish();
  }

  /// A forced release is never gated: the server is already refusing this
  /// build, so the prompt is the user's only explanation and the store page
  /// their only way forward.
  bool _isStoreGated(FlareUpdateRelease release) =>
      release.kind == FlareUpdateKind.store && !release.mandatory;

  void _publish() {
    final status = _engineStatus;
    if (status == null || _disposed) return;
    final shown = _present(status);
    _shown = shown;
    _statuses.add(shown);
  }

  FlareUpdateStatus _present(FlareUpdateStatus status) {
    var result = status;
    if (result.error == null && _localError != null) {
      result = result.overlaid(error: _localError);
    }
    final release = status.release;
    if (release != null && _handoff == FlareUpdateHandoff.restartReady) {
      result = result.overlaid(state: FlareUpdateState.readyToInstall);
    } else if (release != null &&
        _isStoreGated(release) &&
        _storeAnswer?.open != true) {
      result = result.overlaid(prompt: FlareUpdatePromptForm.none);
    }
    return result;
  }
}
