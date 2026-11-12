/// 平台推送模块对引擎的全部要求，以及两边之间传递的值。
///
/// 平台推送模块（Flutter 上是 `flare_core_flutter_push` 插件，背后是 iOS 的 `FlarePlatformPush` 与
/// Android 的 `flare-core-android-push`）不依赖任何引擎包，经 [FlarePushHost] 调引擎：核心客户端给
/// `CorePushHost`，社交 SDK 给 `FlareSocialPushHost`。登记、去重、合并、提示决策都在引擎里，模块只搬运。
///
/// 接口和值类型放在这个纯 Dart 包里：核心适配器要实现它，而这个包不能依赖 Flutter 插件。
///
/// 每个值都有 `toWire` / `fromWire`，形状就是引擎契约里的 JSON（驼峰键）：插件的方法通道与社交 SDK 的
/// IM 透传都按这个形状传，不各写一份。
library;

/// 平台推送模块经它调引擎。所有方法都可能抛错，模块按尽力而为处理：令牌与权限下次回前台重报，
/// 远程推送改按载荷原样展示。引擎对已经发出的通知的更正经 [notificationCorrections] 交给模块，应用不用接线。
abstract interface class FlarePushHost {
  /// 登记或更新系统推送令牌及其绑定信息（`sdk.update_push_token`）。
  Future<void> updatePushToken(PlatformPushToken token);

  /// 当前的系统通知权限，拒绝也要报（`sdk.set_push_permission`）：引擎每次进程启动都从未授权开始。
  Future<void> setPushPermission({required bool allowed});

  /// 对账：补做没有结果的登记与吊销（`sdk.reconcile_push`）。
  Future<void> reconcilePush();

  /// 远程推送的无界面入口（`sdk.handle_remote_message`）。引擎在 150ms 内给出提示意图，不等网络；
  /// [budgetMs] 大于 0 时另起一次有界的后台唤醒，不拖住这次返回。
  Future<PlatformPushOutcome> handleRemoteMessage({
    required String provider,
    required Map<String, String> payload,
    required int budgetMs,
  });

  /// 点击通知要去的会话（`sdk.resolve_notification_tap`）；载荷不属于当前账号时为 null。
  Future<PlatformTapRoute?> resolveNotificationTap({
    required Map<String, String> payload,
  });

  /// 角标口径的未读总数（`conversation.total_unread`）：归档不计，免打扰会话只计 @我。
  Future<int> totalUnread();

  /// 引擎对已经发出的通知的更正（`notification.clear`、`notification.badge`）。
  ///
  /// 平台模块接上宿主时监听一次，摘下、换宿主或登出时取消监听；实现在取消监听时退掉对引擎事件的订阅。
  /// 没有更正可报的宿主返回空流。
  Stream<PlatformNotificationCorrection> notificationCorrections();

  /// 链路在线时引擎决定并渲染好的通知（`notification.present`），各个展示面都在内。
  ///
  /// 系统通知的展示方（`flare_core_flutter_push` 的 `FlareNotificationPresenter`：Android 的后台展示器、
  /// 桌面的系统通知）接上宿主时监听，只取系统展示面；应用内横幅由应用自己接 Kit。实现在取消监听时退掉对引擎
  /// 事件的订阅；没有可报的宿主返回空流。
  Stream<PlatformNotificationPresentation> notificationPresentations();

  /// 平台模块是否在后台替引擎发系统通知（`notification.set_background_presenter`）。只有 Android 的后台展示器
  /// 调：接上为 true，摘下或通知权限被关为 false。桌面与 Web 自己提示，不调。
  Future<void> setBackgroundPresenter({required bool attached});
}

/// 引擎对已经发出的通知的一条更正，平台模块照办，应用什么都不用做。
sealed class PlatformNotificationCorrection {
  const PlatformNotificationCorrection();

  /// `notification.clear` 的载荷 `{collapseIds, all}`；既不是全部、也没有合并键时为 null。
  static PlatformNotificationCorrection? fromClearWire(Object? value) {
    final json = _object(value);
    if (json == null) return null;
    if (_bool(json['all']) == true) return const PlatformNotificationClearAll();
    final collapseIds = _texts(json['collapseIds']);
    return collapseIds.isEmpty ? null : PlatformNotificationClear(collapseIds);
  }

  /// `notification.badge` 的载荷 `{count}`；没有可读的角标数时为 null。
  static PlatformNotificationCorrection? fromBadgeWire(Object? value) {
    final count = _int(_object(value)?['count']);
    return count == null || count < 0 ? null : PlatformNotificationBadge(count);
  }
}

/// 撤掉这些合并键的通知：会话读了或删了。
final class PlatformNotificationClear extends PlatformNotificationCorrection {
  const PlatformNotificationClear(this.collapseIds);

  final List<String> collapseIds;

  @override
  bool operator ==(Object other) =>
      other is PlatformNotificationClear &&
      _sameTexts(other.collapseIds, collapseIds);

  @override
  int get hashCode => Object.hashAll(collapseIds);

  @override
  String toString() => 'PlatformNotificationClear($collapseIds)';
}

/// 撤掉本 SDK 的全部通知：会话结束（登出、换账号）。
final class PlatformNotificationClearAll
    extends PlatformNotificationCorrection {
  const PlatformNotificationClearAll();

  @override
  bool operator ==(Object other) => other is PlatformNotificationClearAll;

  @override
  int get hashCode => (PlatformNotificationClearAll).hashCode;

  @override
  String toString() => 'PlatformNotificationClearAll()';
}

/// 角标写成这个绝对值：未读总数变了、登录之后、回到前台。Android 没有系统角标接口，模块收到后不做事。
final class PlatformNotificationBadge extends PlatformNotificationCorrection {
  const PlatformNotificationBadge(this.count);

  final int count;

  @override
  bool operator ==(Object other) =>
      other is PlatformNotificationBadge && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'PlatformNotificationBadge($count)';
}

/// 一次令牌登记，对应引擎的 `PushTokenInput`：系统令牌，加上服务端选择通道和渲染兜底文案要用的应用信息。
final class PlatformPushToken {
  const PlatformPushToken({
    required this.provider,
    required this.platform,
    required this.token,
    this.appBundle,
    this.environment,
    this.locale,
    this.timeZone,
    this.appVersion,
    this.capabilities = const [],
  });

  /// `apns`、`fcm` 或 `getui`。
  final String provider;

  /// `ios`、`android` 或 `harmony`。
  final String platform;

  /// 系统发的令牌。不写日志，不落盘。
  final String token;

  /// iOS 包名或 Android 的 applicationId；服务端拿 iOS 包名当 APNs topic。
  final String? appBundle;

  /// 仅 APNs：`sandbox` 或 `production`。
  final String? environment;

  /// BCP 47，例如 `zh-CN`；服务端按它渲染兜底文案。
  final String? locale;

  /// IANA 时区名，例如 `Asia/Shanghai`。
  final String? timeZone;

  final String? appVersion;

  /// 已知取值 `dataMessages`（Android FCM）、`serviceExtension`（iOS 通知扩展）。
  final List<String> capabilities;

  /// `PushTokenInput` 的请求体；为 null 的可选字段不带。
  Map<String, Object?> toWire() => {
        'provider': provider,
        'platform': platform,
        'token': token,
        if (appBundle != null) 'appBundle': appBundle,
        if (environment != null) 'environment': environment,
        if (locale != null) 'locale': locale,
        if (timeZone != null) 'timeZone': timeZone,
        if (appVersion != null) 'appVersion': appVersion,
        if (capabilities.isNotEmpty)
          'capabilities': List<String>.of(capabilities),
      };

  /// [toWire] 的反向；没有通道或令牌时为 null。
  static PlatformPushToken? fromWire(Object? value) {
    final json = _object(value);
    if (json == null) return null;
    final provider = _text(json['provider']);
    final token = _text(json['token']);
    if (provider == null || token == null) return null;
    return PlatformPushToken(
      provider: provider,
      platform: _text(json['platform']) ?? '',
      token: token,
      appBundle: _text(json['appBundle']),
      environment: _text(json['environment']),
      locale: _text(json['locale']),
      timeZone: _text(json['timeZone']),
      appVersion: _text(json['appVersion']),
      capabilities: _texts(json['capabilities']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlatformPushToken &&
      other.provider == provider &&
      other.platform == platform &&
      other.token == token &&
      other.appBundle == appBundle &&
      other.environment == environment &&
      other.locale == locale &&
      other.timeZone == timeZone &&
      other.appVersion == appVersion &&
      _sameTexts(other.capabilities, capabilities);

  @override
  int get hashCode => Object.hash(
        provider,
        platform,
        token,
        appBundle,
        environment,
        locale,
        timeZone,
        appVersion,
        Object.hashAll(capabilities),
      );

  /// 打印时不带令牌本身。
  @override
  String toString() =>
      'PlatformPushToken(provider: $provider, platform: $platform, '
      'appBundle: ${appBundle ?? '-'}, environment: ${environment ?? '-'}, '
      'locale: ${locale ?? '-'}, timeZone: ${timeZone ?? '-'}, '
      'appVersion: ${appVersion ?? '-'}, capabilities: $capabilities)';
}

/// 引擎对一条远程推送的处理结果里要做的事。
enum PlatformPushAction {
  /// 新通知，可以响铃。
  present('present'),

  /// 静默替换同一合并键的通知。
  update('update'),

  /// 移除 `clearCollapseIds` 里的通知。
  clear('clear'),

  /// 只更新角标。
  badgeOnly('badgeOnly'),

  /// 什么都不做，原因见 [PlatformPushOutcome.reason]。
  ignore('ignore');

  const PlatformPushAction(this.wire);

  /// 契约里的写法。
  final String wire;

  /// 认 `badgeOnly`、`badge_only`、`BADGE_ONLY` 几种写法，字符串与生成的枚举都行；认不出的当作
  /// [ignore]：宁可不提示，也不按猜测提示。
  static PlatformPushAction fromWire(Object? value) {
    final key = _wireKey(value);
    for (final action in values) {
      if (_wireKey(action.wire) == key) return action;
    }
    return ignore;
  }
}

/// 系统通知渠道。Android 的渠道标识（`flare.messages` 等）由平台模块创建，服务端的厂商参数引用同一组。
enum PlatformNotificationChannel {
  messages('messages'),
  quiet('quiet'),
  mentions('mentions'),
  urgent('urgent');

  const PlatformNotificationChannel(this.wire);

  final String wire;

  /// 认不出的当作 [messages]。
  static PlatformNotificationChannel fromWire(Object? value) {
    final key = _wireKey(value);
    for (final channel in values) {
      if (_wireKey(channel.wire) == key) return channel;
    }
    return messages;
  }
}

/// 提示出在哪里。
enum PlatformNotificationSurface {
  /// 系统通知。
  system('system'),

  /// 应用在前台，提示在应用内，不出系统横幅。
  inApp('inApp');

  const PlatformNotificationSurface(this.wire);

  final String wire;

  /// 认不出的当作 [system]：宁可多一条系统通知，也不漏提示。
  static PlatformNotificationSurface fromWire(Object? value) {
    final key = _wireKey(value);
    for (final surface in values) {
      if (_wireKey(surface.wire) == key) return surface;
    }
    return system;
  }
}

/// 要展示的那条通知，对应引擎的 `NotificationPresentation`。
final class PlatformNotificationPresentation {
  const PlatformNotificationPresentation({
    required this.collapseId,
    required this.threadId,
    required this.conversationId,
    this.messageId = '',
    this.seq = 0,
    required this.title,
    required this.body,
    this.count = 1,
    required this.sound,
    this.channel = PlatformNotificationChannel.messages,
    this.surface = PlatformNotificationSurface.system,
  });

  /// `c:` 加 32 位十六进制：一个会话一条通知，也是通知的标识。
  final String collapseId;

  /// 分组键。
  final String threadId;

  final String conversationId;
  final String messageId;
  final int seq;
  final String title;
  final String body;

  /// 这条通知代表的未读条数，至少为 1。
  final int count;

  final bool sound;
  final PlatformNotificationChannel channel;
  final PlatformNotificationSurface surface;

  Map<String, Object?> toWire() => {
        'collapseId': collapseId,
        'threadId': threadId,
        'conversationId': conversationId,
        'messageId': messageId,
        'seq': seq,
        'title': title,
        'body': body,
        'count': count,
        'sound': sound,
        'channel': channel.wire,
        'surface': surface.wire,
      };

  /// 没有合并键的展示意图落不成通知，按缺失处理（null）。
  static PlatformNotificationPresentation? fromWire(Object? value) {
    final json = _object(value);
    if (json == null) return null;
    final collapseId = _text(json['collapseId']);
    if (collapseId == null) return null;
    final count = _int(json['count']) ?? 1;
    return PlatformNotificationPresentation(
      collapseId: collapseId,
      threadId: _text(json['threadId']) ?? collapseId,
      conversationId: _string(json['conversationId']),
      messageId: _string(json['messageId']),
      seq: _int(json['seq']) ?? 0,
      title: _string(json['title']),
      body: _string(json['body']),
      count: count < 1 ? 1 : count,
      sound: _bool(json['sound']) ?? false,
      channel: PlatformNotificationChannel.fromWire(json['channel']),
      surface: PlatformNotificationSurface.fromWire(json['surface']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlatformNotificationPresentation &&
      other.collapseId == collapseId &&
      other.threadId == threadId &&
      other.conversationId == conversationId &&
      other.messageId == messageId &&
      other.seq == seq &&
      other.title == title &&
      other.body == body &&
      other.count == count &&
      other.sound == sound &&
      other.channel == channel &&
      other.surface == surface;

  @override
  int get hashCode => Object.hash(
        collapseId,
        threadId,
        conversationId,
        messageId,
        seq,
        title,
        body,
        count,
        sound,
        channel,
        surface,
      );
}

/// 引擎对一条远程推送的处理结果，对应 `RemoteMessageOutcome`。
final class PlatformPushOutcome {
  const PlatformPushOutcome({
    required this.action,
    this.presentation,
    this.clearCollapseIds = const [],
    this.badge,
    this.reason,
  });

  final PlatformPushAction action;
  final PlatformNotificationPresentation? presentation;

  /// 无论 [action] 是什么都要移除的通知。
  final List<String> clearCollapseIds;

  /// 角标绝对值，只在已知时给出。
  final int? badge;

  /// 诊断用，`ignore` 时给出：`otherAccount`、`notLoggedIn`、`stale`、`alreadyAlerted`、`malformed`。
  final String? reason;

  Map<String, Object?> toWire() => {
        'action': action.wire,
        if (presentation != null) 'presentation': presentation!.toWire(),
        'clearCollapseIds': List<String>.of(clearCollapseIds),
        if (badge != null) 'badge': badge,
        if (reason != null) 'reason': reason,
      };

  /// 不是对象时按什么都不做处理。
  static PlatformPushOutcome fromWire(Object? value) {
    final json = _object(value) ?? const <String, Object?>{};
    final badge = _int(json['badge']);
    return PlatformPushOutcome(
      action: PlatformPushAction.fromWire(json['action']),
      presentation: PlatformNotificationPresentation.fromWire(
        json['presentation'],
      ),
      clearCollapseIds: _texts(json['clearCollapseIds']),
      badge: badge == null || badge < 0 ? null : badge,
      reason: _text(json['reason']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlatformPushOutcome &&
      other.action == action &&
      other.presentation == presentation &&
      _sameTexts(other.clearCollapseIds, clearCollapseIds) &&
      other.badge == badge &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(
        action,
        presentation,
        Object.hashAll(clearCollapseIds),
        badge,
        reason,
      );

  @override
  String toString() => 'PlatformPushOutcome(action: ${action.wire}, '
      'collapseId: ${presentation?.collapseId ?? '-'}, '
      'clear: $clearCollapseIds, badge: ${badge ?? '-'}, '
      'reason: ${reason ?? '-'})';
}

/// 点击通知要打开的位置，对应 `NotificationTapResult`。
final class PlatformTapRoute {
  const PlatformTapRoute({
    required this.conversationId,
    this.messageId,
    this.seq,
  });

  final String conversationId;
  final String? messageId;
  final int? seq;

  Map<String, Object?> toWire() => {
        'conversationId': conversationId,
        if (messageId != null) 'messageId': messageId,
        if (seq != null) 'seq': seq,
      };

  /// 没有会话（载荷不属于当前账号）时为 null。
  static PlatformTapRoute? fromWire(Object? value) {
    final json = _object(value);
    if (json == null) return null;
    final conversationId = _text(json['conversationId']);
    if (conversationId == null) return null;
    return PlatformTapRoute(
      conversationId: conversationId,
      messageId: _text(json['messageId']),
      seq: _int(json['seq']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlatformTapRoute &&
      other.conversationId == conversationId &&
      other.messageId == messageId &&
      other.seq == seq;

  @override
  int get hashCode => Object.hash(conversationId, messageId, seq);

  @override
  String toString() => 'PlatformTapRoute(conversationId: $conversationId, '
      'messageId: ${messageId ?? '-'}, seq: ${seq ?? '-'})';
}

/// 把 `badgeOnly`、`badge_only`、`BADGE_ONLY` 归成同一个键；生成的枚举按名字比。
String _wireKey(Object? value) {
  final text = value is Enum ? value.name : (value?.toString() ?? '');
  return text.replaceAll('_', '').toLowerCase();
}

/// 方法通道给的是 `Map<Object?, Object?>`，JSON 解码给的是 `Map<String, dynamic>`：一律按字符串键读。
Map<String, Object?>? _object(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key != null) '${entry.key}': entry.value,
  };
}

/// 非空白的字符串；枚举取名字，其余标量转成字符串。
String? _text(Object? value) {
  if (value == null) return null;
  final text = value is Enum ? value.name : '$value';
  return text.trim().isEmpty ? null : text;
}

String _string(Object? value) => value == null ? '' : '$value';

List<String> _texts(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (_text(item) case final text?) text,
  ];
}

/// 64 位整数可能以数字或字符串到达。
int? _int(Object? value) => switch (value) {
      final int number => number,
      final num number => number.toInt(),
      final String text => int.tryParse(text.trim()),
      _ => null,
    };

bool? _bool(Object? value) => switch (value) {
      final bool flag => flag,
      final num number => number != 0,
      final String text => switch (text.trim().toLowerCase()) {
          'true' || '1' => true,
          'false' || '0' => false,
          _ => null,
        },
      _ => null,
    };

bool _sameTexts(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
