import 'dart:async';

import 'package:flare_core_flutter_push/flare_core_flutter_push.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('test.flare.push');
  const routeEvents = EventChannel('test.flare.push/routes');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late FlarePush push;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    push = FlarePush.withChannels(methods: methods, routes: routeEvents);
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        'permissionStatus' => 'notDetermined',
        'canRequestPermission' => true,
        'requestPermission' => 'granted',
        'openNotificationSettings' => true,
        'installGetui' => true,
        'openBatterySettings' => true,
        'openAutoStartSettings' => false,
        'backgroundStatus' => {
            'delivery': 'restricted',
            'ignoringBatteryOptimizations': false,
            'backgroundRestricted': true,
            'vendor': 'xiaomi',
            'hasAutoStartSettings': true,
          },
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
    messenger.setMockStreamHandler(routeEvents, null);
    debugDefaultTargetPlatformOverride = null;
  });

  /// 模拟原生模块调 Dart，返回解码后的结果（出错时抛 [PlatformException]）。
  Future<Object?> fromNative(String method, [Object? arguments]) async {
    final data = await messenger.handlePlatformMessage(
      methods.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      null,
    );
    if (data == null) throw MissingPluginException(method);
    return codec.decodeEnvelope(data);
  }

  test('启停、宿主、权限、语言与登出都转给原生模块', () async {
    expect(push.isStarted, isFalse);
    await push.start(options: const FlarePushOptions(smallIcon: 'ic_push'));
    expect(push.isStarted, isTrue);
    await push.attach(_Host());
    await push.setLocale('en-US');
    expect(
      await push.permissionStatus(),
      FlarePushPermissionStatus.notDetermined,
    );
    expect(await push.canRequestPermission(), isTrue);
    expect(await push.requestPermission(), FlarePushPermissionStatus.granted);
    expect(await push.openNotificationSettings(), isTrue);
    await push.detach();
    await push.signOut();
    expect(calls.map((call) => call.method), [
      'start',
      'permissionStatus',
      'backgroundStatus',
      'attach',
      'setLocale',
      'permissionStatus',
      'canRequestPermission',
      'requestPermission',
      'openNotificationSettings',
      'detach',
      'signOut',
    ]);
    expect(calls.first.arguments, {'fcm': true, 'smallIcon': 'ic_push'});
    expect(calls[4].arguments, 'en-US');
  });

  test('申请返回之后的权限，并交给 permissionChanges', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        // 系统不会再弹框：原生模块不申请，答现状
        'canRequestPermission' => false,
        'requestPermission' => 'denied',
        _ => null,
      };
    });
    final seen = <FlarePushPermissionStatus>[];
    final subscription = push.permissionChanges.listen(seen.add);
    expect(await push.canRequestPermission(), isFalse);
    expect(await push.requestPermission(), FlarePushPermissionStatus.denied);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [FlarePushPermissionStatus.denied]);
    await subscription.cancel();
  });

  test('权限：启动时读一次，原生的变化变了才发，新监听者先拿到当前值', () async {
    final seen = <FlarePushPermissionStatus>[];
    final subscription = push.permissionChanges.listen(seen.add);
    await push.start();
    await fromNative('permissionChanged', 'notDetermined');
    await fromNative('permissionChanged', 'granted');
    await fromNative('permissionChanged', 'granted');
    // 监听者在微任务里收到
    await Future<void>.delayed(Duration.zero);
    expect(seen, [
      FlarePushPermissionStatus.notDetermined,
      FlarePushPermissionStatus.granted,
    ]);
    await subscription.cancel();

    expect(
      await push.permissionChanges.first,
      FlarePushPermissionStatus.granted,
    );
  });

  test('原生模块的宿主调用交给接上的宿主，结果按契约形状回去', () async {
    final host = _Host();
    await push.attach(host);

    await fromNative('updatePushToken', {
      'provider': 'fcm',
      'platform': 'android',
      'token': 'os-test-token',
      'capabilities': ['dataMessages'],
    });
    expect(host.tokens.single.capabilities, ['dataMessages']);

    await fromNative('setPushPermission', {'allowed': true});
    expect(host.permissions, [true]);

    final outcome = await fromNative('handleRemoteMessage', {
      'provider': 'fcm',
      'payload': {'collapse_id': 'c:00', 'seq': 12},
      'budgetMs': 8000,
    });
    expect(host.payloads.single, {'collapse_id': 'c:00', 'seq': '12'});
    expect(host.budgets.single, 8000);
    expect((outcome! as Map)['action'], 'present');

    expect(
      await fromNative('resolveNotificationTap', {
        'payload': {'collapse_id': 'c:00'},
      }),
      {'conversationId': 'conv', 'messageId': 'm1'},
    );
    expect(await fromNative('totalUnread'), 4);
  });

  test('接着宿主期间把它报来的更正转给原生模块，摘下后不再转', () async {
    final host = _Host();
    await push.attach(host);
    host.corrections
      ..add(const PlatformNotificationClear(['c:1', 'c:2']))
      ..add(const PlatformNotificationBadge(3))
      ..add(const PlatformNotificationClearAll());
    await _settle();
    await push.detach();
    expect(host.corrections.hasListener, isFalse);
    host.corrections.add(const PlatformNotificationBadge(9));
    await _settle();

    expect(calls.map((call) => call.method), [
      'attach',
      'clearNotifications',
      'setBadge',
      'clearAllNotifications',
      'detach',
    ]);
    expect(calls[1].arguments, {
      'collapseIds': ['c:1', 'c:2'],
    });
    expect(calls[2].arguments, {'count': 3});
  });

  test('换宿主或登出时上一个宿主的更正不再转', () async {
    final first = _Host();
    final second = _Host();
    await push.attach(first);
    await push.attach(second);
    expect(first.corrections.hasListener, isFalse);
    expect(second.corrections.hasListener, isTrue);
    await push.signOut();
    expect(second.corrections.hasListener, isFalse);
  });

  test('没有宿主时报错，原生模块据此按载荷处理；登出也摘下宿主', () async {
    await push.start();
    await expectLater(
      fromNative('handleRemoteMessage', {
        'provider': 'fcm',
        'payload': <String, String>{},
      }),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'detached'),
      ),
    );
    await push.attach(_Host());
    await push.signOut();
    await expectLater(
      fromNative('totalUnread'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('Android 上桥接个推与后台限制引导', () async {
    expect(await push.installGetui(), isTrue);
    expect(
      await push.backgroundStatus(),
      const FlarePushBackgroundStatus(
        delivery: FlarePushBackgroundDelivery.restricted,
        ignoringBatteryOptimizations: false,
        backgroundRestricted: true,
        vendor: FlarePushVendor.xiaomi,
        hasAutoStartSettings: true,
      ),
    );
    expect(await push.openBatterySettings(), isTrue);
    expect(await push.openAutoStartSettings(), isFalse);
    expect(calls.map((call) => call.method), [
      'installGetui',
      'backgroundStatus',
      'openBatterySettings',
      'openAutoStartSettings',
    ]);
  });

  test('后台限制：启动时读一次，原生的变化变了才发，新监听者先拿到当前值', () async {
    final seen = <FlarePushBackgroundDelivery>[];
    final subscription = push.backgroundChanges.listen(
      (status) => seen.add(status.delivery),
    );
    await push.start();
    const optimized = {
      'delivery': 'optimized',
      'ignoringBatteryOptimizations': false,
      'backgroundRestricted': false,
      'vendor': 'xiaomi',
      'hasAutoStartSettings': true,
    };
    await fromNative('backgroundChanged', optimized);
    await fromNative('backgroundChanged', optimized);
    // 认不出的丢掉
    await fromNative('backgroundChanged', 'restricted');
    await Future<void>.delayed(Duration.zero);
    expect(seen, [
      FlarePushBackgroundDelivery.restricted,
      FlarePushBackgroundDelivery.optimized,
    ]);
    await subscription.cancel();

    final current = await push.backgroundChanges.first;
    expect(current.delivery, FlarePushBackgroundDelivery.optimized);
    expect(current.vendor, FlarePushVendor.xiaomi);
  });

  test('iOS 上没有个推与后台限制，不调原生，后台限制的变化什么也不发', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await push.installGetui(), isFalse);
    expect(await push.backgroundStatus(), isNull);
    expect(await push.openBatterySettings(), isFalse);
    expect(await push.openAutoStartSettings(), isFalse);
    expect(calls, isEmpty);

    final seen = <FlarePushBackgroundStatus>[];
    final subscription = push.backgroundChanges.listen(seen.add);
    await push.start();
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);
    expect(calls.map((call) => call.method), ['start', 'permissionStatus']);
    await subscription.cancel();
  });

  test('点击去向解码，坏的丢掉', () async {
    messenger.setMockStreamHandler(
      routeEvents,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events.success({'conversationId': ''});
          events.success({'conversationId': 'conv', 'seq': 3});
          events.endOfStream();
        },
      ),
    );
    expect(await push.routes.toList(), [
      const PlatformTapRoute(conversationId: 'conv', seq: 3),
    ]);
  });

  test('Android：链路在线时的系统通知转给原生模块，应用内的不转', () async {
    final host = _Host();
    await push.attach(host);
    calls.clear();
    host.presentations
      ..add(
        const PlatformNotificationPresentation(
          collapseId: 'c:01',
          threadId: 'c:01',
          conversationId: 'conv',
          messageId: 'm1',
          seq: 7,
          title: 'Ann',
          body: 'hi',
          sound: true,
        ),
      )
      ..add(
        const PlatformNotificationPresentation(
          collapseId: 'c:02',
          threadId: 'c:02',
          conversationId: 'other',
          title: 'Bob',
          body: 'yo',
          sound: false,
          surface: PlatformNotificationSurface.inApp,
        ),
      );
    await _settle();
    expect(calls.map((call) => call.method), ['presentNotification']);
    expect(calls.single.arguments, {
      'collapseId': 'c:01',
      'threadId': 'c:01',
      'conversationId': 'conv',
      'messageId': 'm1',
      'seq': 7,
      'title': 'Ann',
      'body': 'hi',
      'count': 1,
      'sound': true,
      'channel': 'messages',
      'surface': 'system',
    });

    // 摘下之后不再转
    await push.detach();
    calls.clear();
    host.presentations.add(
      const PlatformNotificationPresentation(
        collapseId: 'c:03',
        threadId: 'c:03',
        conversationId: 'conv',
        title: 'Ann',
        body: 'again',
        sound: true,
      ),
    );
    await _settle();
    expect(calls, isEmpty);
  });

  test('Android：后台展示器经宿主告诉引擎接上或断开', () async {
    final host = _Host();
    await push.attach(host);
    await fromNative('setBackgroundPresenter', {'attached': true});
    await fromNative('setBackgroundPresenter', {'attached': false});
    expect(host.presenter, [true, false]);
  });

  test('没有系统推送的平台什么也不做', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await push.start();
    await push.attach(_Host());
    expect(push.isStarted, isFalse);
    expect(await push.permissionStatus(), FlarePushPermissionStatus.denied);
    expect(await push.canRequestPermission(), isFalse);
    expect(await push.requestPermission(), FlarePushPermissionStatus.denied);
    await push.setLocale('en-US');
    await push.signOut();
    expect(calls, isEmpty);
  });
}

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
  final tokens = <PlatformPushToken>[];
  final permissions = <bool>[];
  final payloads = <Map<String, String>>[];
  final budgets = <int>[];

  @override
  Future<void> updatePushToken(PlatformPushToken token) async =>
      tokens.add(token);

  @override
  Future<void> setPushPermission({required bool allowed}) async =>
      permissions.add(allowed);

  @override
  Future<void> reconcilePush() async {}

  @override
  Future<PlatformPushOutcome> handleRemoteMessage({
    required String provider,
    required Map<String, String> payload,
    required int budgetMs,
  }) async {
    payloads.add(payload);
    budgets.add(budgetMs);
    return const PlatformPushOutcome(
      action: PlatformPushAction.present,
      presentation: PlatformNotificationPresentation(
        collapseId: 'c:00',
        threadId: 'c:00',
        conversationId: 'conv',
        title: 'Ann',
        body: 'hi',
        sound: true,
      ),
    );
  }

  @override
  Future<PlatformTapRoute?> resolveNotificationTap({
    required Map<String, String> payload,
  }) async =>
      const PlatformTapRoute(conversationId: 'conv', messageId: 'm1');

  @override
  Future<int> totalUnread() async => 4;

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
