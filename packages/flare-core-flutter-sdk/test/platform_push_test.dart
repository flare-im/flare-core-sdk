import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('线上形状', () {
    test('令牌登记不带空的可选字段，读回来相同，打印不带令牌', () {
      const token = PlatformPushToken(
        provider: 'fcm',
        platform: 'android',
        token: 'os-test-token',
        appBundle: 'com.example.app',
        locale: 'zh-CN',
        capabilities: ['dataMessages'],
      );
      expect(token.toWire(), {
        'provider': 'fcm',
        'platform': 'android',
        'token': 'os-test-token',
        'appBundle': 'com.example.app',
        'locale': 'zh-CN',
        'capabilities': ['dataMessages'],
      });
      expect(PlatformPushToken.fromWire(token.toWire()), token);
      expect(token.toString(), isNot(contains('os-test-token')));
      expect(PlatformPushToken.fromWire({'provider': 'fcm'}), isNull);
    });

    test('处理结果按契约的驼峰键读写，动作的几种写法都认', () {
      final outcome = PlatformPushOutcome.fromWire(<Object?, Object?>{
        'action': 'present',
        'presentation': <Object?, Object?>{
          'collapseId': 'c:00',
          'threadId': '',
          'conversationId': 'conv',
          'messageId': 'm1',
          'seq': '9007199254740993',
          'title': 'Ann',
          'body': 'hi',
          'count': 0,
          'sound': true,
          'channel': 'mentions',
          'surface': 'inApp',
        },
        'clearCollapseIds': ['c:01', ''],
        'badge': 3,
      });
      expect(outcome.action, PlatformPushAction.present);
      final shown = outcome.presentation!;
      expect(shown.threadId, 'c:00');
      expect(shown.seq, 9007199254740993);
      expect(shown.count, 1);
      expect(shown.channel, PlatformNotificationChannel.mentions);
      expect(shown.surface, PlatformNotificationSurface.inApp);
      expect(outcome.clearCollapseIds, ['c:01']);
      expect(outcome.badge, 3);
      expect(PlatformPushOutcome.fromWire(outcome.toWire()), outcome);

      expect(PlatformPushAction.fromWire('badge_only'), PlatformPushAction.badgeOnly);
      expect(PlatformPushAction.fromWire('BADGE_ONLY'), PlatformPushAction.badgeOnly);
      expect(PlatformPushAction.fromWire('dance'), PlatformPushAction.ignore);
      expect(PlatformPushOutcome.fromWire('not an object').action,
          PlatformPushAction.ignore);
    });

    test('没有合并键的展示意图按缺失处理', () {
      final outcome = PlatformPushOutcome.fromWire({
        'action': 'present',
        'presentation': {'title': 'x'},
      });
      expect(outcome.presentation, isNull);
    });

    test('清除与角标事件读成更正', () {
      expect(
        PlatformNotificationCorrection.fromClearWire({
          'collapseIds': ['c:1', ' ', 'c:2'],
          'all': false,
        }),
        const PlatformNotificationClear(['c:1', 'c:2']),
      );
      expect(
        PlatformNotificationCorrection.fromClearWire({
          'collapseIds': <String>[],
          'all': true,
        }),
        const PlatformNotificationClearAll(),
      );
      expect(
        PlatformNotificationCorrection.fromClearWire({
          'collapseIds': <String>[],
          'all': false,
        }),
        isNull,
      );
      expect(
        PlatformNotificationCorrection.fromBadgeWire({'count': 12}),
        const PlatformNotificationBadge(12),
      );
      expect(PlatformNotificationCorrection.fromBadgeWire({'count': -1}), isNull);
      expect(PlatformNotificationCorrection.fromBadgeWire('12'), isNull);
    });

    test('点击去向：没有会话时为 null', () {
      expect(PlatformTapRoute.fromWire(const <String, Object?>{}), isNull);
      expect(PlatformTapRoute.fromWire({'conversationId': ''}), isNull);
      const route = PlatformTapRoute(conversationId: 'conv', seq: 7);
      expect(route.toWire(), {'conversationId': 'conv', 'seq': 7});
      expect(PlatformTapRoute.fromWire(route.toWire()), route);
    });
  });

  group('CorePushHost', () {
    test('令牌、权限、对账走 session 的推送操作，可选字段原样带上', () async {
      final native = _Bridge();
      final host = CorePushHost(FlareCoreSdk.createClientWithBridge(native));
      await host.updatePushToken(const PlatformPushToken(
        provider: 'apns',
        platform: 'ios',
        token: 'aabb',
        appBundle: 'com.example.app',
        environment: 'sandbox',
        timeZone: 'Asia/Shanghai',
      ));
      await host.setPushPermission(allowed: false);
      await host.reconcilePush();
      expect(native.calls.map((call) => call.$1), [
        'sdk.update_push_token',
        'sdk.set_push_permission',
        'sdk.reconcile_push',
      ]);
      expect(native.calls.first.$2, {
        'provider': 'apns',
        'platform': 'ios',
        'token': 'aabb',
        'appBundle': 'com.example.app',
        'environment': 'sandbox',
        'timeZone': 'Asia/Shanghai',
        'capabilities': <String>[],
      });
      expect(native.calls[1].$2, {'allowed': false});
    });

    test('远程推送与点击转成平台模块的值', () async {
      final native = _Bridge()
        ..answers['sdk.handle_remote_message'] = {
          'action': 'update',
          'presentation': {
            'collapseId': 'c:00',
            'threadId': 'c:00',
            'conversationId': 'conv',
            'messageId': 'm1',
            'seq': 12,
            'title': 'Ann',
            'body': 'hi',
            'count': 2,
            'sound': false,
            'channel': 'quiet',
            'surface': 'system',
          },
          'clearCollapseIds': <String>[],
        }
        ..answers['sdk.resolve_notification_tap'] = {
          'conversationId': 'conv',
          'messageId': 'm1',
          'seq': 12,
        }
        ..answers['conversation.total_unread'] = {'totalUnread': 5};
      final host = CorePushHost(FlareCoreSdk.createClientWithBridge(native));

      final outcome = await host.handleRemoteMessage(
        provider: 'fcm',
        payload: const {'collapse_id': 'c:00', 'seq': '12'},
        budgetMs: 8000,
      );
      expect(outcome.action, PlatformPushAction.update);
      expect(outcome.presentation?.channel, PlatformNotificationChannel.quiet);
      expect(outcome.presentation?.count, 2);
      expect(native.calls.last.$2, {
        'provider': 'fcm',
        'payload': {'collapse_id': 'c:00', 'seq': '12'},
        'budgetMs': 8000,
      });

      final route = await host.resolveNotificationTap(
        payload: const {'collapse_id': 'c:00'},
      );
      expect(route, const PlatformTapRoute(
        conversationId: 'conv',
        messageId: 'm1',
        seq: 12,
      ));
      expect(await host.totalUnread(), 5);
    });

    test('清除与角标事件转成更正，取消监听即退掉', () async {
      final native = _Bridge();
      final client = FlareCoreSdk.createClientWithBridge(native);
      await client.events.subscribeEvents(const {});
      final subscribe = native.calls.last.$2! as Map;
      final deliver = subscribe['handler'] as void Function(int, Object?);
      final corrections = <PlatformNotificationCorrection>[];
      final listening = CorePushHost(client)
          .notificationCorrections()
          .listen(corrections.add);

      deliver(3504, {
        'collapseIds': ['c:1', 'c:2'],
        'all': false,
      });
      deliver(3505, {'count': 3});
      deliver(3504, {'collapseIds': <String>[], 'all': true});
      await Future<void>.delayed(Duration.zero);
      expect(corrections, const [
        PlatformNotificationClear(['c:1', 'c:2']),
        PlatformNotificationBadge(3),
        PlatformNotificationClearAll(),
      ]);

      await listening.cancel();
      deliver(3505, {'count': 4});
      await Future<void>.delayed(Duration.zero);
      expect(corrections, hasLength(3));
    });

    test('通知事件交给展示方，后台展示器的接上与断开走 notification 模块', () async {
      final native = _Bridge();
      final client = FlareCoreSdk.createClientWithBridge(native);
      await client.events.subscribeEvents(const {});
      final subscribe = native.calls.last.$2! as Map;
      final deliver = subscribe['handler'] as void Function(int, Object?);
      final host = CorePushHost(client);
      final presentations = <PlatformNotificationPresentation>[];
      final listening =
          host.notificationPresentations().listen(presentations.add);

      deliver(3503, {
        'collapseId': 'c:1',
        'threadId': '',
        'conversationId': 'conv',
        'messageId': 'm1',
        'seq': 4,
        'title': 'Ann',
        'body': 'hi',
        'count': 2,
        'sound': true,
        'channel': 'mentions',
        'surface': 'system',
      });
      await Future<void>.delayed(Duration.zero);
      expect(presentations, const [
        PlatformNotificationPresentation(
          collapseId: 'c:1',
          threadId: 'c:1',
          conversationId: 'conv',
          messageId: 'm1',
          seq: 4,
          title: 'Ann',
          body: 'hi',
          count: 2,
          sound: true,
          channel: PlatformNotificationChannel.mentions,
        ),
      ]);
      await listening.cancel();

      await host.setBackgroundPresenter(attached: true);
      expect(native.calls.last.$1, 'notification.set_background_presenter');
      expect(native.calls.last.$2, {'attached': true});
    });

    test('载荷不属于当前账号时点击没有去向', () async {
      final native = _Bridge()
        ..answers['sdk.resolve_notification_tap'] = const <String, Object?>{};
      final host = CorePushHost(FlareCoreSdk.createClientWithBridge(native));
      expect(
        await host.resolveNotificationTap(payload: const {'uid': 'other'}),
        isNull,
      );
    });
  });
}

Map<String, Object?> _status() => {
      'state': 'registered',
      'configuredProviders': 1,
      'registeredProviders': 1,
      'pendingRevocations': 0,
      'lastError': null,
    };

final class _Bridge implements NativeBridge {
  final calls = <(String, Object?)>[];
  final answers = <String, Object?>{};

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    calls.add((descriptor.operation, request));
    if (answers.containsKey(descriptor.operation)) {
      return answers[descriptor.operation] as T;
    }
    return _status() as T;
  }
}
