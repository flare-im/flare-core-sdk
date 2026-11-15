import 'dart:async';

import '../api/client.dart';
import '../listener/listener.dart';
import '../model/model.dart';
import 'platform_push.dart';

/// 核心客户端上的推送宿主：平台推送模块经它调 `session` 模块的推送接口与未读总数，客户端的
/// `notification.clear` 与 `notification.badge` 事件转成更正交给模块（[notificationCorrections]）。
/// 系统通知的展示方经它拿 `notification.present`（[notificationPresentations]），Android 的后台展示器经它报
/// `notification.set_background_presenter`（[setBackgroundPresenter]）。
///
/// 事件经客户端本地的监听者转来：应用照常打开的那一路原生事件订阅（`client.events.subscribeEvents`）要开着。
///
/// ```dart
/// // 登录或会话恢复之后
/// await FlarePush.instance.attach(CorePushHost(client));
/// ```
///
/// 生成的模型里，取值固定的几个字段可能是字符串，也可能是枚举：一律按线上的写法转换
/// （`PlatformPushAction.fromWire` 等），两种生成形态都能对上。
final class CorePushHost implements FlarePushHost {
  const CorePushHost(this._client);

  final FlareImClient _client;

  @override
  Future<void> updatePushToken(PlatformPushToken token) async {
    await _client.updatePushToken(
      PushTokenInput(
        platform: token.platform,
        provider: token.provider,
        token: token.token,
        appBundle: token.appBundle,
        environment: token.environment,
        locale: token.locale,
        timeZone: token.timeZone,
        appVersion: token.appVersion,
        capabilities: token.capabilities,
      ),
    );
  }

  @override
  Future<void> setPushPermission({required bool allowed}) async {
    await _client.setPushPermission(SetPushPermissionRequest(allowed: allowed));
  }

  @override
  Future<void> reconcilePush() async {
    await _client.reconcilePush();
  }

  @override
  Future<PlatformPushOutcome> handleRemoteMessage({
    required String provider,
    required Map<String, String> payload,
    required int budgetMs,
  }) async {
    final outcome = await _client.handleRemoteMessage(
      HandleRemoteMessageRequest(
        provider: provider,
        payload: payload,
        budgetMs: budgetMs,
      ),
    );
    final shown = outcome.presentation;
    final badge = outcome.badge;
    return PlatformPushOutcome(
      action: PlatformPushAction.fromWire(outcome.action),
      presentation: shown == null ? null : _presentationOf(shown),
      clearCollapseIds: [
        for (final id in outcome.clearCollapseIds)
          if (id.isNotEmpty) id,
      ],
      badge: badge == null || badge < 0 ? null : badge,
      reason: outcome.reason,
    );
  }

  @override
  Future<PlatformTapRoute?> resolveNotificationTap({
    required Map<String, String> payload,
  }) async {
    final result = await _client.resolveNotificationTap(
      ResolveNotificationTapRequest(payload: payload),
    );
    final conversationId = result.conversationId ?? '';
    if (conversationId.isEmpty) return null;
    final messageId = result.messageId ?? '';
    return PlatformTapRoute(
      conversationId: conversationId,
      messageId: messageId.isEmpty ? null : messageId,
      seq: result.seq,
    );
  }

  @override
  Future<int> totalUnread() async {
    final total = (await _client.conversations.getTotalUnread()).totalUnread;
    return total < 0 ? 0 : total;
  }

  /// 有人监听时监听客户端的清除与角标事件，取消监听时退掉。
  @override
  Stream<PlatformNotificationCorrection> notificationCorrections() {
    final listeners = <EventSubscription>[];
    late final StreamController<PlatformNotificationCorrection> controller;
    controller = StreamController<PlatformNotificationCorrection>(
      onListen: () {
        listeners
          ..add(_client.events.onNotificationClear((event) {
            controller.add(
              event.all
                  ? const PlatformNotificationClearAll()
                  : PlatformNotificationClear([
                      for (final id in event.collapseIds)
                        if (id.isNotEmpty) id,
                    ]),
            );
          }))
          ..add(_client.events.onNotificationBadge((event) {
            controller.add(
              PlatformNotificationBadge(event.count < 0 ? 0 : event.count),
            );
          }));
      },
      // 单订阅的流：退订后不会再有人监听，连同控制器一起关掉。
      onCancel: () {
        for (final listener in listeners) {
          listener.unsubscribe();
        }
        listeners.clear();
        return controller.close();
      },
    );
    return controller.stream;
  }

  /// 有人监听时监听客户端的 `notification.present`（各个展示面都给），取消监听时退掉。
  @override
  Stream<PlatformNotificationPresentation> notificationPresentations() {
    EventSubscription? listener;
    late final StreamController<PlatformNotificationPresentation> controller;
    controller = StreamController<PlatformNotificationPresentation>(
      onListen: () {
        listener = _client.events.onNotificationPresent((event) {
          final presentation = _presentationOf(event);
          if (presentation != null) controller.add(presentation);
        });
      },
      // 单订阅的流：退订后不会再有人监听，连同控制器一起关掉。
      onCancel: () {
        listener?.unsubscribe();
        listener = null;
        return controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> setBackgroundPresenter({required bool attached}) async {
    await _client.notification.setBackgroundPresenter(
      SetBackgroundPresenterRequest(attached: attached),
    );
  }

  /// 没有合并键的展示意图落不成通知（null）。
  static PlatformNotificationPresentation? _presentationOf(
    NotificationPresentation shown,
  ) {
    if (shown.collapseId.isEmpty) return null;
    return PlatformNotificationPresentation(
      collapseId: shown.collapseId,
      threadId: shown.threadId.isEmpty ? shown.collapseId : shown.threadId,
      conversationId: shown.conversationId,
      messageId: shown.messageId,
      seq: shown.seq,
      title: shown.title,
      body: shown.body,
      count: shown.count < 1 ? 1 : shown.count,
      sound: shown.sound,
      channel: PlatformNotificationChannel.fromWire(shown.channel),
      surface: PlatformNotificationSurface.fromWire(shown.surface),
    );
  }
}
