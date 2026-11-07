import 'dart:async';
import 'dart:ffi' show Abi;

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'flutter_recover_scheme.dart';

/// Method channel of the native plugin (`appInfo`).
const String kFlareLifecycleMethodChannel = 'flare_core_flutter_lifecycle';

/// Event channel of the native network readings.
const String kFlareLifecycleNetworkChannel =
    'flare_core_flutter_lifecycle/network';

/// Event channel of the links the system opens the app with; macOS only.
const String kFlareLifecycleLinksChannel = 'flare_core_flutter_lifecycle/links';

/// The links the system opens the app with, the one that launched it first.
///
/// On macOS the app declares the scheme in `CFBundleURLTypes` and the native
/// plugin sends the links here. On Windows and Linux the app registers itself
/// with [registerFlutterRecoverScheme] and the system starts it with the link
/// as an argument, so hand `main`'s arguments in as [launchArguments]. On
/// Android and iOS the engine hands a link over as a route, which
/// `didPushRouteInformation` or the router already takes, so this stays empty.
Stream<String> flutterOpenedLinks({
  List<String> launchArguments = const [],
  EventChannel events = const EventChannel(kFlareLifecycleLinksChannel),
  bool? nativeLinks,
}) async* {
  final launchLink = flutterLaunchLink(launchArguments);
  if (launchLink != null) yield launchLink;
  final native =
      nativeLinks ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS);
  if (!native) return;
  yield* events
      .receiveBroadcastStream()
      .where((event) => event is String)
      .cast<String>();
}

/// The Flutter platform source: network readings from the native plugin
/// (Android `ConnectivityManager.registerDefaultNetworkCallback`, iOS and
/// macOS `NWPathMonitor`), foreground state from [AppLifecycleListener], and
/// the installed package's version.
///
/// [FlareCoreFlutter.createClient] uses it; hosts that drive another client
/// (the social SDK) hand it to a [PlatformLifecycle] themselves.
final class FlutterPlatformLifecycleSource implements PlatformLifecycleSource {
  FlutterPlatformLifecycleSource({
    MethodChannel methods = const MethodChannel(kFlareLifecycleMethodChannel),
    EventChannel networkEvents =
        const EventChannel(kFlareLifecycleNetworkChannel),
    bool? nativeNetwork,
    String? Function() locale = systemLocale,
    String? Function() target = desktopTarget,
  })  : _methods = methods,
        _networkEvents = networkEvents,
        _nativeNetwork = nativeNetwork ?? _platformHasNativeNetwork(),
        _locale = locale,
        _target = target;

  final MethodChannel _methods;
  final EventChannel _networkEvents;
  final bool _nativeNetwork;
  final String? Function() _locale;
  final String? Function() _target;

  static bool _platformHasNativeNetwork() =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Native network readings; the plugin sends the current network first.
  /// Platforms without the native plugin report none.
  @override
  Stream<PlatformNetworkState> network() {
    if (!_nativeNetwork) return const Stream<PlatformNetworkState>.empty();
    return _networkEvents
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) =>
            PlatformNetworkState.fromMap(event as Map<Object?, Object?>));
  }

  /// Foreground and background from [AppLifecycleListener], the current
  /// state first.
  @override
  Stream<AppState> appState() {
    AppLifecycleListener? listener;
    late final StreamController<AppState> controller;
    controller = StreamController<AppState>(
      onListen: () {
        final binding = WidgetsFlutterBinding.ensureInitialized();
        controller.add(appStateOf(binding.lifecycleState));
        listener = AppLifecycleListener(
          binding: binding,
          onStateChange: (state) => controller.add(appStateOf(state)),
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

  /// The installed package's version, build and distribution, left out where
  /// the native plugin is missing or cannot read them, with the system language
  /// and the desktop target, which need no plugin.
  @override
  Future<PlatformAppInfo?> appInfo() async {
    final package = await _packageInfo();
    return PlatformAppInfo(
      version: package?.version,
      build: package?.build,
      distribution: package?.distribution,
      locale: _locale(),
      target: _target(),
    );
  }

  Future<PlatformAppInfo?> _packageInfo() async {
    try {
      final raw = await _methods.invokeMapMethod<Object?, Object?>('appInfo');
      return raw == null ? null : PlatformAppInfo.fromMap(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// The system language as BCP-47; null when the platform gives none.
String? systemLocale() {
  final tag = PlatformDispatcher.instance.locale.toLanguageTag();
  return tag.isEmpty || tag == 'und' ? null : tag;
}

/// The desktop target the release manifest names, such as `darwin-aarch64`;
/// null on mobile platforms.
String? desktopTarget() {
  if (kIsWeb) return null;
  final system = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'darwin',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    _ => null,
  };
  if (system == null) return null;
  final abi = Abi.current();
  if (abi == Abi.macosArm64 || abi == Abi.windowsArm64 || abi == Abi.linuxArm64) {
    return '$system-aarch64';
  }
  if (abi == Abi.macosX64 || abi == Abi.windowsX64 || abi == Abi.linuxX64) {
    return '$system-x86_64';
  }
  return null;
}

/// What the core hears for a Flutter lifecycle state: visible states
/// (resumed, and inactive while a system overlay covers the app) are
/// foreground; hidden, paused and detached are background. Before the engine
/// reports a state the app is taken to be in the foreground.
AppState appStateOf(AppLifecycleState? state) => switch (state) {
      null ||
      AppLifecycleState.resumed ||
      AppLifecycleState.inactive =>
        AppState.foreground,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached =>
        AppState.background,
    };
