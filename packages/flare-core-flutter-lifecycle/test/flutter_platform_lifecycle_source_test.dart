import 'package:flare_core_flutter_lifecycle/flare_core_flutter_lifecycle.dart';
import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const methods = MethodChannel('test/flare_core_flutter_lifecycle');
  const network = EventChannel('test/flare_core_flutter_lifecycle/network');
  late _FakeNative native;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    native = _FakeNative(binding, methods, network)..register();
  });

  tearDown(() => native.unregister());

  Future<FlareImClient> create(
    _RecordingBridge bridge,
    Map<String, Object?> config, {
    bool installPlatformLifecycle = true,
    bool nativeNetwork = true,
    String? locale,
    String? target,
  }) =>
      FlareCoreFlutter.createClientWithBridge(
        bridge,
        config,
        installPlatformLifecycle: installPlatformLifecycle,
        platform: FlutterPlatformLifecycleSource(
          methods: methods,
          networkEvents: network,
          nativeNetwork: nativeNetwork,
          locale: () => locale,
          target: () => target,
        ),
      );

  group('flutterOpenedLinks', () {
    const links = EventChannel('test/flare_core_flutter_lifecycle/links');

    tearDown(
      () => messenger.setMockStreamHandler(links, null),
    );

    test('gives the links the system opens the app with', () async {
      messenger.setMockStreamHandler(
        links,
        MockStreamHandler.inline(
          onListen: (_, events) {
            events
              ..success('flare-recover://v1?p=a&k=b&s=c')
              ..success(7)
              ..endOfStream();
          },
        ),
      );

      final opened =
          await flutterOpenedLinks(events: links, nativeLinks: true).toList();

      expect(opened, ['flare-recover://v1?p=a&k=b&s=c']);
    });

    test('a platform that routes its links gives none here', () async {
      final opened =
          await flutterOpenedLinks(events: links, nativeLinks: false).toList();

      expect(opened, isEmpty);
    });

    test('gives a link among the launch arguments first', () async {
      messenger.setMockStreamHandler(
        links,
        MockStreamHandler.inline(
          onListen: (_, events) {
            events
              ..success('flare-recover://v1?p=b')
              ..endOfStream();
          },
        ),
      );

      final opened = await flutterOpenedLinks(
        launchArguments: const ['flare-recover://v1?p=a'],
        events: links,
        nativeLinks: true,
      ).toList();

      expect(opened, ['flare-recover://v1?p=a', 'flare-recover://v1?p=b']);
    });

    test('a launch link needs no native channel', () async {
      final opened = await flutterOpenedLinks(
        launchArguments: const ['--flag', 'flare-recover://v1?p=a'],
        events: links,
        nativeLinks: false,
      ).toList();

      expect(opened, ['flare-recover://v1?p=a']);
    });
  });

  test('reports the current network first, then only changes', () async {
    final bridge = _RecordingBridge();
    native.initial = {
      'available': true,
      'interface': 'wifi',
      'metered': false,
      'fingerprintHint': '192.168.1',
    };
    final sdk = await create(bridge, {'tenantId': '0'});
    await _settle();
    expect(native.listens, 1);
    expect(bridge.networkReports, [
      {
        'available': true,
        'interface': 'wifi',
        'metered': false,
        'reason': 'initial',
        'fingerprintHint': '192.168.1',
      },
    ]);

    // The native side repeats itself (onAvailable plus onCapabilitiesChanged):
    // nothing new goes out.
    await native.emit(native.initial!);
    await native.emit({...native.initial!});
    expect(bridge.networkReports, hasLength(1));

    await native.emit({
      'available': true,
      'interface': 'cellular',
      'metered': true,
      'fingerprintHint': '460-01',
    });
    await native.emit({'available': false});
    await native.emit({'available': false});
    expect(bridge.networkReports.skip(1), [
      {
        'available': true,
        'interface': 'cellular',
        'metered': true,
        'reason': 'changed',
        'fingerprintHint': '460-01',
      },
      {'available': false, 'reason': 'changed'},
    ]);

    await sdk.dispose();
    expect(native.cancels, 1);
  });

  test('maps Flutter lifecycle states to foreground and background', () async {
    final bridge = _RecordingBridge();
    final sdk = await create(bridge, {'tenantId': '0'});
    await _settle();
    expect(bridge.appStates, ['foreground']);

    // Going to the background: inactive is still visible, hidden is not.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _settle();
    expect(bridge.appStates, ['foreground', 'background']);

    // And back.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle();
    expect(bridge.appStates, ['foreground', 'background', 'foreground']);

    await sdk.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await _settle();
    expect(bridge.appStates, hasLength(3));
  });

  test('starts in the background when the app is not visible', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final bridge = _RecordingBridge();
    final sdk = await create(bridge, {'tenantId': '0'});
    await _settle();
    expect(bridge.appStates, ['background']);
    await sdk.dispose();
  });

  test('appStateOf covers every lifecycle state', () {
    expect(appStateOf(null), AppState.foreground);
    expect(appStateOf(AppLifecycleState.resumed), AppState.foreground);
    expect(appStateOf(AppLifecycleState.inactive), AppState.foreground);
    expect(appStateOf(AppLifecycleState.hidden), AppState.background);
    expect(appStateOf(AppLifecycleState.paused), AppState.background);
    expect(appStateOf(AppLifecycleState.detached), AppState.background);
  });

  test('installPlatformLifecycle false keeps network and app state quiet',
      () async {
    final bridge = _RecordingBridge();
    native.initial = {'available': true, 'interface': 'wifi'};
    await create(bridge, {'tenantId': '0'}, installPlatformLifecycle: false);
    await _settle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _settle();

    expect(native.listens, 0);
    expect(bridge.networkReports, isEmpty);
    expect(bridge.appStates, isEmpty);
    expect(bridge.initRequest, {'tenantId': '0'});
  });

  test('fills the app keys the host left out from the native package info',
      () async {
    final bridge = _RecordingBridge();
    native.appInfo = {
      'version': '2.4.0',
      'build': 240,
      'distribution': 'play',
    };
    // The host gives only the channel: version, build and distribution are
    // still filled.
    final sdk = await create(bridge, {
      'tenantId': '0',
      'app': {'channel': 'beta'},
    });
    expect(bridge.initRequest, {
      'tenantId': '0',
      'app': {
        'channel': 'beta',
        'version': '2.4.0',
        'build': 240,
        'distribution': 'play',
      },
    });

    // Keys the host gives win; a later init reuses the platform source.
    await sdk.init({
      'environment': 'development',
      'sdkConfig': {
        'app': {'version': '9.9.9', 'distribution': 'direct'},
      },
    });
    expect(bridge.initRequest, {
      'environment': 'development',
      'sdkConfig': {
        'app': {'version': '9.9.9', 'distribution': 'direct', 'build': 240},
      },
    });
    // The reinstalled lifecycle listens again.
    expect(native.listens, 2);
    await sdk.dispose();
  });

  test('fills the language and the desktop target without a native plugin',
      () async {
    final bridge = _RecordingBridge();
    final sdk = await create(
      bridge,
      {'tenantId': '0'},
      locale: 'zh-Hant-TW',
      target: 'linux-x86_64',
    );
    expect(bridge.initRequest, {
      'tenantId': '0',
      'app': {'locale': 'zh-Hant-TW', 'target': 'linux-x86_64'},
    });
    await sdk.dispose();
  });

  test('a failed init disposes the client and installs nothing', () async {
    final bridge = _RecordingBridge()..failInit = true;

    await expectLater(create(bridge, {'tenantId': '0'}), throwsStateError);
    await _settle();
    expect(bridge.disposed, isTrue);
    expect(native.listens, 0);
    expect(bridge.appStates, isEmpty);
  });

  test('without the native plugin, init carries the host config unchanged',
      () async {
    final bridge = _RecordingBridge();
    native.unregister();
    final sdk = await create(bridge, {'tenantId': '0'}, nativeNetwork: false);
    await _settle();

    expect(bridge.initRequest, {'tenantId': '0'});
    expect(bridge.networkReports, isEmpty);
    // App state still comes from Flutter itself.
    expect(bridge.appStates, ['foreground']);
    await sdk.dispose();
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Plays the native plugin: answers `appInfo` and drives the network channel.
final class _FakeNative {
  _FakeNative(this.binding, this.methods, this.network);

  final TestWidgetsFlutterBinding binding;
  final MethodChannel methods;
  final EventChannel network;
  Map<String, Object?>? initial;
  Map<String, Object?>? appInfo;
  int listens = 0;
  int cancels = 0;

  TestDefaultBinaryMessenger get _messenger => binding.defaultBinaryMessenger;

  void register() {
    _messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'appInfo') return appInfo;
      throw MissingPluginException(call.method);
    });
    _messenger.setMockStreamHandler(
      network,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          listens++;
          final current = initial;
          if (current != null) sink.success(current);
        },
        onCancel: (_) => cancels++,
      ),
    );
  }

  void unregister() {
    _messenger.setMockMethodCallHandler(methods, null);
    _messenger.setMockStreamHandler(network, null);
  }

  /// Sends one reading over the event channel as the native side would.
  Future<void> emit(Map<String, Object?> reading) async {
    await _messenger.handlePlatformMessage(
      network.name,
      const StandardMethodCodec().encodeSuccessEnvelope(reading),
      (_) {},
    );
    await _settle();
  }
}

final class _RecordingBridge implements NativeBridge {
  bool failInit = false;
  bool disposed = false;
  Object? initRequest;
  final networkReports = <Object?>[];
  final appStates = <Object?>[];

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    switch (descriptor.operation) {
      case 'sdk.init':
        if (failInit) throw StateError('init failed');
        initRequest = request;
      case 'sdk.dispose':
        disposed = true;
      case 'connection.notify_network_change':
        networkReports.add(request);
      case 'lifecycle.set_app_state':
        appStates.add((request! as Map)['appState']);
      default:
        break;
    }
    return null as T;
  }
}
