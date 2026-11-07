import 'dart:ffi';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';

import 'flutter_platform_lifecycle_source.dart';

/// Entry point for Flutter apps.
abstract final class FlareCoreFlutter {
  const FlareCoreFlutter._();

  /// Creates a client backed by the native core library, initialized with
  /// [config] for this device.
  ///
  /// `init` fills the `app` keys the host left out (`version`, `build`,
  /// `distribution`) from the installed package, then installs the platform
  /// lifecycle: native network changes go to
  /// `connection.notifyNetworkChange` and foreground changes to
  /// `lifecycle.setAppState`, the current state first. `uninit`, `dispose`
  /// and `hardReset` remove it, and a later `init` on the client installs it
  /// again. [installPlatformLifecycle] `false` keeps it off (tests only).
  /// When `init` fails the client is disposed and the error rethrown.
  static Future<FlareImClient> createClient(
    Map<String, Object?> config, {
    DynamicLibrary? library,
    String? libraryPath,
    bool installPlatformLifecycle = true,
  }) {
    return _initialize(
      FlareCoreSdk.createClient(library: library, libraryPath: libraryPath),
      config,
      installPlatformLifecycle: installPlatformLifecycle,
      platform: FlutterPlatformLifecycleSource(),
    );
  }

  /// [createClient] over a custom bridge, for host integration tests.
  static Future<FlareImClient> createClientWithBridge(
    NativeBridge bridge,
    Map<String, Object?> config, {
    bool installPlatformLifecycle = true,
    PlatformLifecycleSource? platform,
  }) {
    return _initialize(
      FlareCoreSdk.createClientWithBridge(bridge),
      config,
      installPlatformLifecycle: installPlatformLifecycle,
      platform: platform ?? FlutterPlatformLifecycleSource(),
    );
  }

  static Future<FlareImClient> _initialize(
    DefaultFlareImClient client,
    Map<String, Object?> config, {
    required bool installPlatformLifecycle,
    required PlatformLifecycleSource platform,
  }) async {
    try {
      await client.init(
        config,
        installPlatformLifecycle: installPlatformLifecycle,
        platform: platform,
      );
    } catch (_) {
      await client.dispose().catchError((Object _) {});
      rethrow;
    }
    return client;
  }
}
