import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import 'push_port.dart';

enum PushHostState {
  stopped,
  starting,
  permissionDenied,
  waitingForToken,
  listening,
  unavailable,
}

/// One foreground-isolate host per application. OS callbacks never start a
/// second client/store. Not a background service or proof of vendor delivery.
final class NativePushHost extends ChangeNotifier with WidgetsBindingObserver {
  NativePushHost({
    required NativePushPort port,
    required PushBindingCallbacks binding,
  }) : _port = port,
       _binding = binding;

  final NativePushPort _port;
  final PushBindingCallbacks _binding;
  // Latest hint only: a paused listener cannot accumulate vendor metadata.
  // Null retires the wake/navigation hint on logout/stop.
  final _hintValue = ValueNotifier<PushHint?>(null);
  ValueListenable<PushHint?> get hint => _hintValue;
  PushHostState get state => _state;
  PushHostState _state = PushHostState.stopped;
  // These fence only host callbacks; no identity/registration mirror is stored.
  bool _running = false;
  bool _session = false;
  bool _disposed = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  int _generation = 0;
  int _lifetime = 0;
  Future<void>? _starting;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  bool _current(int generation) =>
      !_disposed && _running && generation == _generation;
  bool _live(int lifetime) => !_disposed && _running && lifetime == _lifetime;

  void _set(PushHostState value) {
    if (_disposed || value == _state) return;
    _state = value;
    notifyListeners();
  }

  /// Opt-in only, and never prompts. Call after the normal SDK init so pending
  /// revocations can recover even if no account is currently signed in.
  Future<void> start() {
    if (_disposed) throw StateError('Push host disposed');
    if (_starting case final pending?) return pending;
    if (_running) return Future.value();
    final run = _start();
    _starting = run;
    return run.whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    _running = true;
    final lifetime = ++_lifetime;
    _set(PushHostState.starting);
    try {
      await _binding.permission(false);
      if (!_live(lifetime)) return;
      await _port.initialize().timeout(const Duration(seconds: 10));
      if (!_live(lifetime)) return;
      await _port.setAutoInit(true).timeout(const Duration(seconds: 8));
      if (!_live(lifetime)) {
        await _port.setAutoInit(false).timeout(const Duration(seconds: 8));
        return;
      }
      _subscriptions.add(
        _port.tokenChanges.listen(
          (_) => unawaited(refresh()),
          onError: (Object _) => _set(PushHostState.unavailable),
        ),
      );
      _subscriptions.add(
        _port.opened.listen(
          _hint,
          onError: (Object _) => _set(PushHostState.unavailable),
        ),
      );
      _subscriptions.add(
        _port.foreground.listen(
          _hint,
          onError: (Object _) => _set(PushHostState.unavailable),
        ),
      );
      WidgetsBinding.instance.addObserver(this);
      final initial = await _port.initialHint().timeout(
        const Duration(seconds: 5),
      );
      if (!_live(lifetime)) return;
      if (initial != null) _hint(initial);
      await refresh();
    } catch (_) {
      if (_live(lifetime)) {
        await _cancelSubscriptions();
        _running = false;
        try {
          await _port.setAutoInit(false).timeout(const Duration(seconds: 8));
        } catch (_) {}
        _set(PushHostState.unavailable);
      }
      // No driver exception/token/payload in diagnostics. Explicit start retry
      // is allowed; no hidden timer, registration replay or fallback provider.
    }
  }

  void _hint(PushHint hint) {
    if (_running && _session && !_disposed) _hintValue.value = hint;
  }

  /// Call false BEFORE logout/switch, true AFTER successful normal login. This
  /// invalidates pending OS reads; it does not replace the SDK's session fence.
  Future<void> setSessionActive(bool active) async {
    if (_disposed) return;
    _session = active;
    _hintValue.value = null;
    ++_generation;
    // Deliberately not queued behind an in-flight OS token callback.
    try {
      await _binding.permission(false);
    } catch (_) {
      _set(PushHostState.unavailable);
    }
    try {
      await _port.clearNotifications().timeout(const Duration(seconds: 5));
    } catch (_) {
      _set(PushHostState.unavailable);
    }
    if (_running) await refresh();
  }

  /// Coalesces OS reads with bounded memory. Unknown registration results are
  /// handled by Rust, not retried here. A resume also recovers pending revokes.
  Future<void> refresh({bool requestPermission = false}) async {
    if (!_running || _disposed) return;
    if (_refreshing) {
      // Never queue a permission prompt behind a callback.
      if (!requestPermission) _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final generation = _generation;
        try {
          final reading = _port.permission(request: requestPermission);
          // A user-owned OS permission dialog is not a network timeout.
          final allowed = await (requestPermission
              ? reading
              : reading.timeout(const Duration(seconds: 8)));
          requestPermission = false;
          if (!_current(generation)) continue;
          if (!allowed || !_session) {
            await _binding.permission(false);
            if (!_current(generation)) continue;
            _set(
              allowed ? PushHostState.stopped : PushHostState.permissionDenied,
            );
            await _binding.reconcile();
            continue;
          }
          final value = await _port.token().timeout(const Duration(seconds: 8));
          if (!_current(generation)) continue;
          if (value == null || value.isEmpty) {
            await _binding.permission(false);
            if (!_current(generation)) continue;
            await _binding.invalidate(_port.provider);
            if (!_current(generation)) continue;
            _set(PushHostState.waitingForToken);
          } else {
            await _binding.token(
              PushTokenInput(
                platform: _port.platform,
                provider: _port.provider,
                token: value,
              ),
            );
            if (!_current(generation)) continue;
            await _binding.permission(true);
            if (_current(generation)) _set(PushHostState.listening);
          }
          if (_current(generation)) await _binding.reconcile();
        } catch (_) {
          if (_current(generation)) _set(PushHostState.unavailable);
        }
      } while (_refreshAgain && _running && !_disposed);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(onResume());
  }

  /// Permission withdrawal must bypass an unresolved token registration. This
  /// read never queues behind _refreshing; the SDK retires its fixed identity.
  Future<void> onResume() async {
    if (!_running || _disposed) return;
    final lifetime = _lifetime;
    try {
      if (!await _port.permission().timeout(const Duration(seconds: 8))) {
        if (!_live(lifetime)) return;
        ++_generation;
        await _binding.permission(false);
        if (_live(lifetime)) _set(PushHostState.permissionDenied);
        return;
      }
      if (_live(lifetime)) await refresh();
    } catch (_) {
      if (_live(lifetime)) _set(PushHostState.unavailable);
    }
  }

  Future<void> _cancelSubscriptions() async {
    WidgetsBinding.instance.removeObserver(this);
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  /// Await before disposing SDK. OS credentials remain vendor-owned; disabling
  /// auto-init is not claimed to delete an FCM installation or recall a push.
  Future<void> stop() async {
    _running = false;
    if (!_disposed) _hintValue.value = null;
    ++_generation;
    ++_lifetime;
    try {
      await _binding.permission(false);
    } catch (_) {
      _set(PushHostState.unavailable);
    }
    await _cancelSubscriptions();
    try {
      await _port.setAutoInit(false).timeout(const Duration(seconds: 8));
      await _port.clearNotifications().timeout(const Duration(seconds: 5));
    } catch (_) {
      _set(PushHostState.unavailable);
      return;
    }
    _set(PushHostState.stopped);
  }

  @override
  void dispose() {
    // The owner must await stop() before client disposal. Synchronous disposal
    // only retires listeners; it cannot promise async revocation completion.
    _disposed = true;
    _running = false;
    ++_generation;
    ++_lifetime;
    unawaited(_cancelSubscriptions());
    _hintValue.dispose();
    super.dispose();
  }
}
