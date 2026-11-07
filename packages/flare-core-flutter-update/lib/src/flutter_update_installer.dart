import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Method channel of the native plugin (`execute`, `canPrompt`,
/// `completeHandoff`).
const String kFlareUpdateMethodChannel = 'flare_core_flutter_update';

/// Event channel of the handoff progress; Android only, the other hosts have
/// no store that works in the background.
const String kFlareUpdateHandoffChannel = 'flare_core_flutter_update/handoff';

/// Opens a link in the system; false when nothing can.
typedef FlareUpdateUrlOpener = Future<bool> Function(Uri url);

/// A controller for [engine] with the host's installer and foreground events.
FlareUpdateController flutterUpdateController(
  FlareUpdateEngine engine, {
  void Function(Object error, StackTrace stackTrace)? onError,
}) =>
    FlareUpdateController(
      engine: engine,
      installer: FlutterUpdateInstaller(),
      foreground: flutterForegroundEvents(),
      onError: onError,
    );

/// An event each time the app comes back from the background. An overlay that
/// only took the focus, such as a system dialog, is not a return.
Stream<void> flutterForegroundEvents() {
  AppLifecycleListener? listener;
  late final StreamController<void> controller;
  controller = StreamController<void>(
    onListen: () {
      listener = AppLifecycleListener(
        binding: WidgetsFlutterBinding.ensureInitialized(),
        onShow: () => controller.add(null),
      );
    },
    onCancel: () {
      listener?.dispose();
      listener = null;
      return controller.close();
    },
  );
  return controller.stream;
}

/// The install plans of the host platform. Android, iOS and macOS go through
/// the native plugin; Windows and Linux have none and open the plan's link.
final class FlutterUpdateInstaller implements FlareUpdateInstaller {
  FlutterUpdateInstaller({
    MethodChannel methods = const MethodChannel(kFlareUpdateMethodChannel),
    EventChannel handoffEvents = const EventChannel(kFlareUpdateHandoffChannel),
    bool? nativeInstaller,
    bool? nativeHandoff,
    FlareUpdateUrlOpener? openUrl,
  })  : _methods = methods,
        _handoffEvents = handoffEvents,
        _nativeInstaller = nativeInstaller ?? _platformHasNativeInstaller(),
        _nativeHandoff = nativeHandoff ?? _platformHasNativeHandoff(),
        _openUrl = openUrl ?? _openInSystem;

  final MethodChannel _methods;
  final EventChannel _handoffEvents;
  final bool _nativeInstaller;
  final bool _nativeHandoff;
  final FlareUpdateUrlOpener _openUrl;

  static bool _platformHasNativeInstaller() =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool _platformHasNativeHandoff() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> _openInSystem(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<FlareUpdateInstallResult> execute(FlareUpdateInstallPlan plan) async {
    if (!_nativeInstaller) return _openInBrowser(plan);
    try {
      final raw = await _methods.invokeMapMethod<String, Object?>(
        'execute',
        plan.toMap(),
      );
      return raw == null ? _failed : FlareUpdateInstallResult.fromMap(raw);
    } on MissingPluginException {
      return _failed;
    } on PlatformException {
      return _failed;
    }
  }

  /// Only the native installer can ask a store; everywhere else nothing stands
  /// in the way of the prompt.
  @override
  Future<bool> canPrompt(FlareUpdateRelease release) async {
    if (!_nativeInstaller) return true;
    try {
      return await _methods.invokeMethod<bool>('canPrompt', release.toMap()) ??
          true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Stream<FlareUpdateHandoff> handoffs() {
    if (!_nativeHandoff) return const Stream<FlareUpdateHandoff>.empty();
    return _handoffEvents
        .receiveBroadcastStream()
        .map(_handoffOf)
        .where((handoff) => handoff != null)
        .cast<FlareUpdateHandoff>();
  }

  @override
  Future<FlareUpdateInstallResult> completeHandoff() async {
    if (!_nativeInstaller) {
      return const FlareUpdateInstallResult(FlareUpdateOutcome.cancelled);
    }
    try {
      final raw =
          await _methods.invokeMapMethod<String, Object?>('completeHandoff');
      return raw == null ? _failed : FlareUpdateInstallResult.fromMap(raw);
    } on MissingPluginException {
      return _failed;
    } on PlatformException {
      return _failed;
    }
  }

  Future<FlareUpdateInstallResult> _openInBrowser(
    FlareUpdateInstallPlan plan,
  ) async {
    final link = plan is FlareUpdateOpenStore ? plan.url : null;
    final url = link == null ? null : Uri.tryParse(link);
    if (url == null) return _failed;
    final opened = await _openUrl(url);
    return opened
        ? const FlareUpdateInstallResult(FlareUpdateOutcome.completed)
        : _failed;
  }

  static FlareUpdateHandoff? _handoffOf(Object? event) {
    for (final handoff in FlareUpdateHandoff.values) {
      if (handoff.name == event) return handoff;
    }
    return null;
  }

  static const FlareUpdateInstallResult _failed =
      FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.installFailed);
}
