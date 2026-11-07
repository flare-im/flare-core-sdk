import 'dart:async';

import '../api/client.dart';
import '../model/command/network_change_request.dart';
import '../model/command/set_app_state_request.dart';
import '../model/entity/app_state.dart';
import '../model/entity/network_interface_kind.dart';

/// One reading of the device network, as a platform source reports it.
///
/// [fingerprintHint] is a coarse network identity (Wi-Fi: the default
/// gateway's IPv4 /24 or IPv6 /64 prefix; cellular: MCC-MNC when the platform
/// gives it without a permission). The core hashes it locally with
/// [interface]; it is never an SSID or BSSID.
final class PlatformNetworkState {
  const PlatformNetworkState({
    required this.available,
    this.interface,
    this.expensive,
    this.metered,
    this.fingerprintHint,
  });

  /// A reading from the platform channel map
  /// (`{available, interface, expensive, metered, fingerprintHint}`); unknown
  /// or ill-typed fields are left out.
  factory PlatformNetworkState.fromMap(Map<Object?, Object?> map) {
    final interface = map['interface'];
    final hint = map['fingerprintHint'];
    return PlatformNetworkState(
      available: map['available'] != false,
      interface: interface is String ? _interfaceKind(interface) : null,
      expensive: map['expensive'] is bool ? map['expensive'] as bool : null,
      metered: map['metered'] is bool ? map['metered'] as bool : null,
      fingerprintHint: hint is String && hint.isNotEmpty ? hint : null,
    );
  }

  final bool available;
  final NetworkInterfaceKind? interface;
  final bool? expensive;
  final bool? metered;
  final String? fingerprintHint;

  /// The core request for this reading.
  NetworkChangeRequest toRequest({String? reason}) => NetworkChangeRequest(
        available: available,
        interface: interface,
        expensive: expensive,
        metered: metered,
        reason: reason,
        fingerprintHint: fingerprintHint,
      );

  @override
  bool operator ==(Object other) =>
      other is PlatformNetworkState &&
      other.available == available &&
      other.interface == interface &&
      other.expensive == expensive &&
      other.metered == metered &&
      other.fingerprintHint == fingerprintHint;

  @override
  int get hashCode =>
      Object.hash(available, interface, expensive, metered, fingerprintHint);

  @override
  String toString() => 'PlatformNetworkState(available: $available, '
      'interface: ${interface?.name}, expensive: $expensive, '
      'metered: $metered, fingerprintHint: $fingerprintHint)';

  static NetworkInterfaceKind _interfaceKind(String value) {
    for (final kind in NetworkInterfaceKind.values) {
      if (kind.name == value) return kind;
    }
    return NetworkInterfaceKind.other;
  }
}

/// Version facts the platform reads for `sdkConfig.app`.
final class PlatformAppInfo {
  const PlatformAppInfo({
    this.version,
    this.build,
    this.distribution,
    this.locale,
    this.target,
  });

  /// Facts from the platform channel map (`{version, build, distribution}`);
  /// blank or ill-typed fields are left out.
  factory PlatformAppInfo.fromMap(Map<Object?, Object?> map) {
    final version = map['version'];
    final build = map['build'];
    final distribution = map['distribution'];
    return PlatformAppInfo(
      version: version is String && version.trim().isNotEmpty
          ? version.trim()
          : null,
      build: build is int && build >= 0 ? build : null,
      distribution: distribution is String && distribution.trim().isNotEmpty
          ? distribution.trim()
          : null,
    );
  }

  /// Version name (Android `versionName`, Apple `CFBundleShortVersionString`).
  final String? version;

  /// Monotonic integer build (Android `versionCode`, Apple numeric
  /// `CFBundleVersion`); the server compares builds only.
  final int? build;

  /// Where the app was installed from: `appstore`, `testflight`, `play`,
  /// `appgallery`, `direct` and so on.
  final String? distribution;

  /// The system language as BCP-47; the update notes are picked by it. A host
  /// with its own language setting gives `app.locale` itself.
  final String? locale;

  /// The desktop target (`darwin-aarch64` and so on) the release manifest
  /// picks its artifact by; mobile platforms have none.
  final String? target;

  bool get isEmpty =>
      version == null &&
      build == null &&
      distribution == null &&
      locale == null &&
      target == null;

  /// The `app` object of the init configuration.
  Map<String, Object?> toJson() => {
        if (version != null) 'version': version,
        if (build != null) 'build': build,
        if (distribution != null) 'distribution': distribution,
        if (locale != null) 'locale': locale,
        if (target != null) 'target': target,
      };
}

/// Where a platform's network, foreground state and version facts come from.
///
/// The Flutter plugin `flare_core_flutter_lifecycle` implements it with the
/// native network callbacks and `AppLifecycleListener`; a pure Dart host has
/// none.
abstract interface class PlatformLifecycleSource {
  /// Network readings. The first one after listening is the current network.
  Stream<PlatformNetworkState> network();

  /// Foreground and background. The first one after listening is the current
  /// state.
  Stream<AppState> appState();

  /// Version facts for `sdkConfig.app`; null when the platform cannot say.
  Future<PlatformAppInfo?> appInfo();
}

/// The init configuration the core receives: [request] with the platform's
/// [appInfo] filling the `app` keys the host left out.
///
/// Keys the host gives (`version`, `build`, `distribution`, `locale`, `target`,
/// `channel`) stay as they are; the platform fills only missing or blank ones,
/// and never `channel`. With nothing to fill, `app` is not
/// written: the core replaces its build-time app facts with whatever `app`
/// it receives. Both init shapes are accepted, a bare configuration (`app` at
/// the top) and the `{environment, sdkConfig}` wrapper (`sdkConfig.app`).
Map<String, Object?> platformInitConfig(
  Map<String, Object?> request,
  PlatformAppInfo? appInfo,
) {
  final root = Map<String, Object?>.of(request);
  if (appInfo == null || appInfo.isEmpty) return root;
  final wrapped =
      root.containsKey('sdkConfig') || root.containsKey('environment');
  final config = _stringKeyed(wrapped ? root['sdkConfig'] : root);
  final app = _stringKeyed(config['app']);
  appInfo.toJson().forEach((key, value) {
    final existing = app[key];
    if (existing == null || (existing is String && existing.trim().isEmpty)) {
      app[key] = value;
    }
  });
  config['app'] = app;
  if (!wrapped) return config;
  root['sdkConfig'] = config;
  return root;
}

Map<String, Object?> _stringKeyed(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, Object?>{};

/// Reports the platform's network and foreground state to the core.
///
/// The client installs one after `init` succeeds when it has a platform
/// source (unless `init` is told `installPlatformLifecycle: false`) and
/// removes it on `uninit`, `dispose` and `hardReset`; apps add no wiring of
/// their own. Each network
/// change goes to `connection.notifyNetworkChange` and each foreground change
/// to `lifecycle.setAppState`: the first reading after installing always,
/// later ones only when they differ from the last report. The core's link
/// supervisor alone decides what to do with them.
final class PlatformLifecycle {
  PlatformLifecycle({
    required PlatformLifecycleSource source,
    required Future<void> Function(NetworkChangeRequest request)
        notifyNetworkChange,
    required Future<void> Function(SetAppStateRequest request) setAppState,
    void Function(Object error, StackTrace stackTrace)? onError,
  })  : _source = source,
        _notifyNetworkChange = notifyNetworkChange,
        _setAppState = setAppState,
        _onError = onError;

  /// The lifecycle that drives [client].
  factory PlatformLifecycle.forClient(
    FlareImClient client,
    PlatformLifecycleSource source, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) =>
      PlatformLifecycle(
        source: source,
        notifyNetworkChange: client.connection.notifyNetworkChange,
        setAppState: client.lifecycle.setAppState,
        onError: onError,
      );

  final PlatformLifecycleSource _source;
  final Future<void> Function(NetworkChangeRequest request)
      _notifyNetworkChange;
  final Future<void> Function(SetAppStateRequest request) _setAppState;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  StreamSubscription<PlatformNetworkState>? _networkSubscription;
  StreamSubscription<AppState>? _appStateSubscription;
  PlatformNetworkState? _lastNetwork;
  AppState? _lastAppState;
  bool _installed = false;
  bool _disposed = false;

  bool get installed => _installed && !_disposed;

  /// Starts listening; the current network and app state go out first.
  void install() {
    if (_installed || _disposed) return;
    _installed = true;
    _networkSubscription = _source.network().listen(
          _reportNetwork,
          onError: _reportError,
        );
    _appStateSubscription = _source.appState().listen(
          (state) => unawaited(_reportAppState(state)),
          onError: _reportError,
        );
  }

  /// Reports the foreground now, as if the source had said so.
  Future<void> setForeground() => _reportAppState(AppState.foreground);

  /// Reports the background now, as if the source had said so.
  Future<void> setBackground() => _reportAppState(AppState.background);

  /// Stops listening; later readings are dropped.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      if (_networkSubscription != null) _networkSubscription!.cancel(),
      if (_appStateSubscription != null) _appStateSubscription!.cancel(),
    ]);
    _networkSubscription = null;
    _appStateSubscription = null;
  }

  void _reportNetwork(PlatformNetworkState state) {
    if (_disposed || state == _lastNetwork) return;
    final first = _lastNetwork == null;
    _lastNetwork = state;
    unawaited(_guard(() => _notifyNetworkChange(
          state.toRequest(reason: first ? 'initial' : 'changed'),
        )));
  }

  Future<void> _reportAppState(AppState state) async {
    if (_disposed || state == _lastAppState) return;
    _lastAppState = state;
    await _guard(() => _setAppState(SetAppStateRequest(appState: state)));
  }

  /// Reports are best effort: the core rejecting one never breaks the stream.
  Future<void> _guard(Future<void> Function() report) async {
    try {
      await report();
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _reportError(Object error, [StackTrace? stackTrace]) {
    _onError?.call(error, stackTrace ?? StackTrace.current);
  }
}
