import 'dart:async';

import 'package:flare_core_flutter_push/flare_core_flutter_push.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('test.flare.push/presenter');
  const taps = EventChannel('test.flare.push/presenter/taps');
  const pushMethods = MethodChannel('test.flare.push');
  const pushRoutes = EventChannel('test.flare.push/routes');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late FlareNotificationPresenter presenter;

  setUp(() {
    calls = [];
    presenter = FlareNotificationPresenter.withChannels(
      methods: methods,
      taps: taps,
      push: FlarePush.withChannels(methods: pushMethods, routes: pushRoutes),
    );
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        'attach' => {'attached': true, 'backend': 'freedesktop'},
        'permissionStatus' => 'notDetermined',
        'requestPermission' => 'granted',
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(pushMethods, (call) async {
      return switch (call.method) {
        'permissionStatus' => 'granted',
        _ => null,
      };
    });
  });

  tearDown(() async {
    for (final host in _hosts) {
      await host.close();
    }
    _hosts.clear();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(pushMethods, null);
    messenger.setMockStreamHandler(taps, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('桌面：系统展示面、清除与角标转给原生，应用内与空的不转，不告诉引擎', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final host = _Host();
    expect(presenter.kind, FlareNotificationPresenterKind.desktop);
    await presenter.attach(
      host,
      options: const FlareNotificationPresenterOptions(
        windowsAppUserModelId: ' com.example.app ',
      ),
    );
    expect(presenter.backend, 'freedesktop');
    expect(calls.single.method, 'attach');
    expect(
        calls.single.arguments, {'windowsAppUserModelId': 'com.example.app'});
    calls.clear();

    host.presentations
      ..add(_presentation('c:01'))
      ..add(_presentation('c:02', surface: PlatformNotificationSurface.inApp))
      ..add(_presentation('c:03', title: '', body: ''));
    host.corrections
      ..add(const PlatformNotificationClear(['c:01']))
      ..add(const PlatformNotificationBadge(3))
      ..add(const PlatformNotificationClearAll());
    await _settle();
    expect(calls.map((call) => call.method), [
      'present',
      'clear',
      'setBadge',
      'clearAll',
    ]);
    expect(calls.first.arguments, _presentation('c:01').toWire());
    expect(calls[1].arguments, {
      'collapseIds': ['c:01'],
    });
    expect(calls[2].arguments, {'count': 3});
    expect(host.presenter, isEmpty);

    calls.clear();
    await presenter.signOut();
    expect(
        calls.map((call) => call.method), ['detach', 'clearAll', 'setBadge']);
    expect(calls.last.arguments, {'count': 0});

    // 摘下之后不再转
    calls.clear();
    host.presentations.add(_presentation('c:04'));
    await _settle();
    expect(calls, isEmpty);
    expect(host.presenter, isEmpty);
  });

  test('桌面：授权走原生，点击解码，坏的丢掉', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(
      await presenter.permissionStatus(),
      FlarePushPermissionStatus.notDetermined,
    );
    expect(
      await presenter.requestPermission(),
      FlarePushPermissionStatus.granted,
    );
    messenger.setMockStreamHandler(
      taps,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events.success({'conversationId': ''});
          events.success({
            'conversationId': 'conv',
            'messageId': 'm1',
            'seq': 9,
          });
          events.endOfStream();
        },
      ),
    );
    expect(await presenter.routes.toList(), [
      const PlatformTapRoute(conversationId: 'conv', messageId: 'm1', seq: 9),
    ]);
  });

  test('Android：只告诉原生要不要，通知由 FlarePush 转；摘下时先直接告诉引擎断开', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final host = _Host();
    expect(presenter.kind, FlareNotificationPresenterKind.androidBackground);
    await presenter.attach(host);
    host.presentations.add(_presentation('c:01'));
    await _settle();
    expect(calls.map((call) => call.method), ['attach']);
    // 接上由原生经推送宿主告诉引擎，这里不报
    expect(host.presenter, isEmpty);
    expect(
      await presenter.permissionStatus(),
      FlarePushPermissionStatus.granted,
    );

    await presenter.detach();
    expect(host.presenter, [false]);
    expect(calls.map((call) => call.method), ['attach', 'detach']);
    expect(await presenter.routes.isEmpty, isTrue);
  });

  test('iOS 与其余平台什么也不做', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final host = _Host();
    expect(presenter.isSupported, isFalse);
    await presenter.attach(host);
    await presenter.signOut();
    expect(
      await presenter.permissionStatus(),
      FlarePushPermissionStatus.denied,
    );
    expect(calls, isEmpty);
    expect(host.presenter, isEmpty);
  });
}

PlatformNotificationPresentation _presentation(
  String collapseId, {
  String title = 'Ann',
  String body = 'hi',
  PlatformNotificationSurface surface = PlatformNotificationSurface.system,
}) =>
    PlatformNotificationPresentation(
      collapseId: collapseId,
      threadId: collapseId,
      conversationId: 'conv',
      messageId: 'm1',
      seq: 7,
      title: title,
      body: body,
      sound: true,
      surface: surface,
    );

/// 等方法通道上排着的调用都送到。
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// 每个测试建的宿主，测完关掉它们的流。
final _hosts = <_Host>[];

final class _Host implements FlarePushHost {
  _Host() {
    _hosts.add(this);
  }

  final corrections =
      StreamController<PlatformNotificationCorrection>.broadcast();
  final presentations =
      StreamController<PlatformNotificationPresentation>.broadcast();

  Future<void> close() async {
    await corrections.close();
    await presentations.close();
  }

  final presenter = <bool>[];

  @override
  Future<void> updatePushToken(PlatformPushToken token) async {}

  @override
  Future<void> setPushPermission({required bool allowed}) async {}

  @override
  Future<void> reconcilePush() async {}

  @override
  Future<PlatformPushOutcome> handleRemoteMessage({
    required String provider,
    required Map<String, String> payload,
    required int budgetMs,
  }) async =>
      const PlatformPushOutcome(action: PlatformPushAction.ignore);

  @override
  Future<PlatformTapRoute?> resolveNotificationTap({
    required Map<String, String> payload,
  }) async =>
      null;

  @override
  Future<int> totalUnread() async => 0;

  @override
  Stream<PlatformNotificationCorrection> notificationCorrections() =>
      corrections.stream;

  @override
  Stream<PlatformNotificationPresentation> notificationPresentations() =>
      presentations.stream;

  @override
  Future<void> setBackgroundPresenter({required bool attached}) async =>
      presenter.add(attached);
}
