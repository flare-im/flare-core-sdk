import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformLifecycle', () {
    test('reports the first reading after install, then only changes',
        () async {
      final source = _FakeSource();
      final target = _Target();
      final lifecycle = PlatformLifecycle(
        source: source,
        notifyNetworkChange: target.notifyNetworkChange,
        setAppState: target.setAppState,
      )..install();

      source.emitNetwork(const PlatformNetworkState(
        available: true,
        interface: NetworkInterfaceKind.wifi,
        fingerprintHint: '192.168.1',
      ));
      source.emitAppState(AppState.foreground);
      await _settle();
      expect(target.networks, hasLength(1));
      expect(target.networks.single.reason, 'initial');
      expect(target.networks.single.interface, NetworkInterfaceKind.wifi);
      expect(target.networks.single.fingerprintHint, '192.168.1');
      expect(target.appStates, [AppState.foreground]);

      // Same reading again: nothing goes out.
      source.emitNetwork(const PlatformNetworkState(
        available: true,
        interface: NetworkInterfaceKind.wifi,
        fingerprintHint: '192.168.1',
      ));
      source.emitAppState(AppState.foreground);
      await _settle();
      expect(target.networks, hasLength(1));
      expect(target.appStates, hasLength(1));

      // Each field is part of the identity.
      for (final change in const [
        PlatformNetworkState(
          available: true,
          interface: NetworkInterfaceKind.wifi,
          fingerprintHint: '10.0.0',
        ),
        PlatformNetworkState(
          available: true,
          interface: NetworkInterfaceKind.wifi,
          fingerprintHint: '10.0.0',
          metered: true,
        ),
        PlatformNetworkState(
          available: true,
          interface: NetworkInterfaceKind.wifi,
          fingerprintHint: '10.0.0',
          metered: true,
          expensive: true,
        ),
        PlatformNetworkState(
          available: true,
          interface: NetworkInterfaceKind.cellular,
          fingerprintHint: '460-01',
        ),
        PlatformNetworkState(available: false),
      ]) {
        source.emitNetwork(change);
      }
      source.emitAppState(AppState.background);
      await _settle();
      expect(target.networks, hasLength(6));
      expect(target.networks.skip(1).map((request) => request.reason).toSet(),
          {'changed'});
      expect(target.networks.last.available, isFalse);
      expect(target.appStates, [AppState.foreground, AppState.background]);

      await lifecycle.dispose();
      expect(source.listening, isFalse);
      source.emitNetwork(const PlatformNetworkState(available: true));
      await _settle();
      expect(target.networks, hasLength(6));
    });

    test('setForeground and setBackground report through the same dedupe',
        () async {
      final source = _FakeSource();
      final target = _Target();
      final lifecycle = PlatformLifecycle(
        source: source,
        notifyNetworkChange: target.notifyNetworkChange,
        setAppState: target.setAppState,
      )..install();

      source.emitAppState(AppState.foreground);
      await _settle();
      await lifecycle.setForeground();
      await lifecycle.setBackground();
      await lifecycle.setBackground();
      expect(target.appStates, [AppState.foreground, AppState.background]);

      await lifecycle.dispose();
      await lifecycle.setForeground();
      expect(target.appStates, hasLength(2));
    });

    test('a rejected report goes to onError and later reports still flow',
        () async {
      final source = _FakeSource();
      final target = _Target()..failNext = true;
      final errors = <Object>[];
      PlatformLifecycle(
        source: source,
        notifyNetworkChange: target.notifyNetworkChange,
        setAppState: target.setAppState,
        onError: (error, _) => errors.add(error),
      ).install();

      source.emitNetwork(const PlatformNetworkState(available: false));
      await _settle();
      source.emitNetwork(const PlatformNetworkState(available: true));
      await _settle();

      expect(errors, hasLength(1));
      expect(
          target.networks.map((request) => request.available), [false, true]);
    });
  });

  group('platformInitConfig', () {
    test('fills the language and the desktop target by key', () {
      final config = platformInitConfig(
        {
          'app': {'locale': 'en'},
        },
        const PlatformAppInfo(locale: 'zh-Hant-TW', target: 'darwin-aarch64'),
      );
      expect(config['app'], {'locale': 'en', 'target': 'darwin-aarch64'});
    });

    const info = PlatformAppInfo(
      version: '3.2.1',
      build: 30201,
      distribution: 'play',
    );

    test('fills app when the host gave none', () {
      final config = platformInitConfig({'tenantId': '0'}, info);
      expect(config, {
        'tenantId': '0',
        'app': {'version': '3.2.1', 'build': 30201, 'distribution': 'play'},
      });
    });

    test('keeps host keys and fills only the missing ones', () {
      final config = platformInitConfig({
        'tenantId': '0',
        'app': {'channel': 'beta'},
      }, info);
      expect(config['app'], {
        'channel': 'beta',
        'version': '3.2.1',
        'build': 30201,
        'distribution': 'play',
      });

      final explicit = platformInitConfig({
        'app': {'version': '9.0.0', 'build': 1, 'distribution': ' '},
      }, info);
      expect(explicit['app'], {
        'version': '9.0.0',
        'build': 1,
        'distribution': 'play',
      });
    });

    test('fills sdkConfig.app in the wrapped shape', () {
      final config = platformInitConfig({
        'environment': 'development',
        'sdkConfig': {'tenantId': '0'},
      }, info);
      expect(config['environment'], 'development');
      expect(config['sdkConfig'], {
        'tenantId': '0',
        'app': {'version': '3.2.1', 'build': 30201, 'distribution': 'play'},
      });
    });

    test('writes no app when the platform knows nothing', () {
      expect(platformInitConfig({'tenantId': '0'}, null), {'tenantId': '0'});
      expect(
        platformInitConfig({'tenantId': '0'}, const PlatformAppInfo()),
        {'tenantId': '0'},
      );
    });
  });

  group('client installs the platform lifecycle', () {
    test('after init, with the platform app facts, and removes it on dispose',
        () async {
      final bridge = _LifecycleBridge();
      final source = _FakeSource(
        appInfo: const PlatformAppInfo(version: '1.0.0', build: 7),
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      expect(source.listening, isFalse);
      await client.init({
        'tenantId': '0',
        'app': {'channel': 'stable'},
      }, platform: source);
      expect(bridge.initRequest, {
        'tenantId': '0',
        'app': {'channel': 'stable', 'version': '1.0.0', 'build': 7},
      });
      expect(source.listening, isTrue);

      source.emitNetwork(const PlatformNetworkState(
        available: true,
        interface: NetworkInterfaceKind.cellular,
        fingerprintHint: '460-01',
      ));
      source.emitAppState(AppState.foreground);
      await _settle();
      expect(bridge.calls, [
        'connection.notify_network_change',
        'lifecycle.set_app_state',
      ]);
      expect(bridge.requests.first, {
        'available': true,
        'interface': 'cellular',
        'reason': 'initial',
        'fingerprintHint': '460-01',
      });
      expect(bridge.requests.last, {'appState': 'foreground'});

      await client.dispose();
      expect(source.listening, isFalse);
    });

    test('init failure installs nothing', () async {
      final bridge = _LifecycleBridge()..failInit = true;
      final source = _FakeSource();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await expectLater(
        client.init({'tenantId': '0'}, platform: source),
        throwsStateError,
      );
      expect(source.listening, isFalse);
    });

    test('installPlatformLifecycle false keeps it off', () async {
      final bridge = _LifecycleBridge();
      final source = _FakeSource();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.init(
        {'tenantId': '0'},
        platform: source,
        installPlatformLifecycle: false,
      );
      expect(bridge.initRequest, {'tenantId': '0'});
      expect(source.listening, isFalse);
    });

    test('uninit and hardReset remove it; a later init reuses the source',
        () async {
      final bridge = _LifecycleBridge();
      final source = _FakeSource();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.init({'tenantId': '0'}, platform: source);
      expect(source.listening, isTrue);
      await client.uninit();
      expect(source.listening, isFalse);
      // Through the plain interface: no source given, the first one is reused.
      final FlareImClient plain = client;
      await plain.init({'tenantId': '0'});
      expect(source.listening, isTrue);
      await client.hardReset();
      expect(source.listening, isFalse);
    });

    test('a client without a platform source sends init unchanged', () async {
      final bridge = _LifecycleBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.init({'tenantId': '0'});
      expect(bridge.initRequest, {'tenantId': '0'});
    });
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

final class _Target {
  final networks = <NetworkChangeRequest>[];
  final appStates = <AppState>[];
  bool failNext = false;

  Future<void> notifyNetworkChange(NetworkChangeRequest request) async {
    networks.add(request);
    if (failNext) {
      failNext = false;
      throw StateError('core rejected the report');
    }
  }

  Future<void> setAppState(SetAppStateRequest request) async {
    appStates.add(request.appState);
  }
}

final class _FakeSource implements PlatformLifecycleSource {
  _FakeSource({PlatformAppInfo? appInfo}) : appInfoValue = appInfo;

  final PlatformAppInfo? appInfoValue;
  final _network = StreamController<PlatformNetworkState>.broadcast();
  final _appState = StreamController<AppState>.broadcast();

  bool get listening => _network.hasListener || _appState.hasListener;

  void emitNetwork(PlatformNetworkState state) => _network.add(state);

  void emitAppState(AppState state) => _appState.add(state);

  @override
  Stream<PlatformNetworkState> network() => _network.stream;

  @override
  Stream<AppState> appState() => _appState.stream;

  @override
  Future<PlatformAppInfo?> appInfo() async => appInfoValue;
}

final class _LifecycleBridge implements NativeBridge {
  bool failInit = false;
  Object? initRequest;
  final calls = <String>[];
  final requests = <Object?>[];

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    switch (descriptor.operation) {
      case 'sdk.init':
        if (failInit) throw StateError('init failed');
        initRequest = request;
        return null as T;
      case 'event.unsubscribe_all':
      case 'sdk.dispose':
      case 'sdk.uninit':
      case 'sdk.hard_reset':
        return null as T;
      default:
        calls.add(descriptor.operation);
        requests.add(request);
        return null as T;
    }
  }
}
