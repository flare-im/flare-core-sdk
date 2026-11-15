import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart'
    show
        FlarePushHost,
        PlatformNotificationBadge,
        PlatformNotificationClear,
        PlatformNotificationClearAll,
        PlatformNotificationCorrection,
        PlatformNotificationPresentation,
        PlatformNotificationSurface,
        PlatformPushToken,
        PlatformTapRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'background_status.dart';

/// 系统通知权限，三态由原生模块判定：iOS 读系统的授权状态（临时授权与短期授权算允许），Android 由模块
/// 记下自己弹过授权框，分得清「还没问过」与「拒绝过」。
enum FlarePushPermissionStatus {
  /// 还没决定：可以弹系统授权框。
  notDetermined('notDetermined'),

  /// 允许，含 iOS 的临时授权。
  granted('granted'),

  /// 拒绝，或在系统设置里关掉了：只能引导去系统设置。
  denied('denied');

  const FlarePushPermissionStatus(this.wire);

  final String wire;

  /// 认不出的当作 [denied]：不弹框，只引导去设置。
  static FlarePushPermissionStatus fromWire(Object? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return denied;
  }
}

/// [FlarePush.start] 的选项。只有 Android 用得上：iOS 的通知外观由系统决定。
@immutable
final class FlarePushOptions {
  const FlarePushOptions({this.fcm = true, this.smallIcon, this.color});

  /// 登记 FCM 令牌。只出国内渠道的构建可以关掉；关掉后收到的 FCM 消息照样展示。
  final bool fcm;

  /// 状态栏小图标：应用 `res/drawable` 里的资源名（单色、透明底）。null 用模块自带的。
  final String? smallIcon;

  /// 通知的强调色，ARGB。
  final int? color;

  Map<String, Object?> toWire() => {
        'fcm': fcm,
        if (smallIcon != null) 'smallIcon': smallIcon,
        if (color != null) 'color': color,
      };
}

/// 系统推送的 Flutter 入口，对应原生的 `PlatformPush`（iOS）与 `FlarePush`（Android）。
///
/// - 启动时 [start]（iOS 上原生模块在应用启动时已经开始，这一步只是确认）。
/// - 登录或会话恢复后 [attach] 一个宿主（核心客户端的 `CorePushHost`、社交 SDK 的
///   `FlareSocialPushHost`）：原生模块补报令牌与权限，并解析接上之前留下的那次点击。接着宿主期间，
///   宿主报来的通知更正（会话读了撤掉、会话结束全撤、iOS 的角标）转给原生模块照办，应用不用接线。
/// - 登出时 [signOut]：摘下宿主，清掉本 SDK 的通知（iOS 还把角标归零），丢掉留着的点击，下一个账号重新登记令牌。
/// - 在用户能理解的时机：[canRequestPermission] 为 true 时 [requestPermission]，否则（系统不会再弹框）
///   [openNotificationSettings] 去系统设置；[permissionStatus] 与 [permissionChanges] 给界面显示状态。
/// - 应用内切语言时 [setLocale]：令牌登记带应用的语言。
/// - 从 [routes] 读点击要去的会话。冷启动的点击早于登录：原生模块先留着，接上宿主后才从这里出来。
/// - Android 上另有个推（[installGetui]）与后台限制引导（[backgroundStatus]、[backgroundChanges] 等）。
/// - Android 上链路在线时引擎自己出的系统通知也经这里的宿主转给原生模块；要不要由原生的后台展示器发，由
///   `FlareNotificationPresenter` 决定。
///
/// 只有 Android 与 iOS 有系统推送；其余平台上每个方法都什么也不做（桌面的系统通知见 `FlareNotificationPresenter`）。
final class FlarePush {
  FlarePush._(this._methods, this._routeEvents);

  /// 换成自己的通道，测试用。
  @visibleForTesting
  factory FlarePush.withChannels({
    required MethodChannel methods,
    required EventChannel routes,
  }) =>
      FlarePush._(methods, routes);

  static final FlarePush instance = FlarePush._(
    const MethodChannel(methodChannelName),
    const EventChannel(routesChannelName),
  );

  /// Dart 调原生（启停、宿主、权限、语言、登出、通知更正的落地、Android 的个推与后台限制，以及 Android 上
  /// 链路在线时的通知 `presentNotification`），原生调 Dart（宿主的方法，含 Android 后台展示器的
  /// `setBackgroundPresenter`；`permissionChanged` 与 Android 的 `backgroundChanged`）。
  static const methodChannelName = 'im.flare.push';

  /// 点击去向：`{conversationId, messageId?, seq?}`。
  static const routesChannelName = 'im.flare.push/routes';

  final MethodChannel _methods;
  final EventChannel _routeEvents;
  final Set<MultiStreamController<FlarePushPermissionStatus>>
      _permissionListeners = {};
  final Set<MultiStreamController<FlarePushBackgroundStatus>>
      _backgroundListeners = {};
  FlarePushHost? _host;
  StreamSubscription<PlatformNotificationCorrection>? _corrections;
  StreamSubscription<PlatformNotificationPresentation>? _presentations;
  Stream<PlatformTapRoute>? _routes;
  FlarePushPermissionStatus? _permission;
  FlarePushBackgroundStatus? _background;
  bool _listening = false;
  bool _started = false;

  /// 这个平台有没有系统推送。
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isAndroid =>
      isSupported && defaultTargetPlatform == TargetPlatform.android;

  /// [start] 已经完成。
  bool get isStarted => _started;

  /// 开始：Android 上装上原生模块（通知渠道、FCM 令牌、回前台重读重报权限、重读后台档位）；iOS 上原生模块已在
  /// `didFinishLaunching` 里开始。读一次权限交给 [permissionChanges]，Android 上再读一次后台限制交给
  /// [backgroundChanges]。从不弹权限框。再调一次什么也不做。
  Future<void> start({
    FlarePushOptions options = const FlarePushOptions(),
  }) async {
    if (!isSupported) return;
    _listenToNative();
    await _methods.invokeMethod<void>('start', options.toWire());
    _started = true;
    // 原生在 Dart 开始监听之前发出的变化落空了：主动读一次当前值
    await permissionStatus();
    await backgroundStatus();
  }

  /// 接上宿主，并开始把它报来的通知更正转给原生模块。换宿主（重新登录）时令牌会重新登记，
  /// 上一个宿主的更正不再转。
  ///
  /// Android 上另把链路在线时引擎出的系统通知（`notification.present`，展示面 `system`）转给原生模块：后台展示器
  /// （[FlareNotificationPresenter]）接上时由它发出，没接上时原生不发。
  Future<void> attach(FlarePushHost host) async {
    _host = host;
    await _stopCorrections();
    if (!isSupported) return;
    _listenToNative();
    _corrections = host.notificationCorrections().listen(
          (correction) => unawaited(_applyCorrection(correction)),
          // 更正尽力而为：宿主的流出错不影响推送的其余部分
          onError: (Object _) {},
        );
    if (_isAndroid) {
      _presentations = host.notificationPresentations().listen(
            (presentation) => unawaited(_forwardPresentation(presentation)),
            onError: (Object _) {},
          );
    }
    await _methods.invokeMethod<void>('attach');
  }

  /// 摘下宿主（客户端释放、但账号没有退出时）。之后到的推送按载荷原样提示，点击留到下次接上，更正不再转。
  Future<void> detach() async {
    _host = null;
    await _stopCorrections();
    if (!isSupported) return;
    await _methods.invokeMethod<void>('detach');
  }

  /// 登出：摘下宿主，清掉本 SDK 留在通知中心的通知（iOS 还把角标归零），丢掉留着的点击，
  /// 忘掉已登记的令牌，下一个账号接上时重新登记。
  Future<void> signOut() async {
    _host = null;
    await _stopCorrections();
    if (!isSupported) return;
    await _methods.invokeMethod<void>('signOut');
  }

  /// 撤掉这些合并键的通知（iOS 按通知标识与载荷里的合并键找，Android 按通知的 tag）。宿主报来的更正
  /// 这里自己转，应用不用调。不支持的平台上什么也不做。
  Future<void> clearNotifications(List<String> collapseIds) async {
    if (!isSupported || collapseIds.isEmpty) return;
    await _methods.invokeMethod<void>('clearNotifications', {
      'collapseIds': List<String>.of(collapseIds),
    });
  }

  /// 撤掉本 SDK 的全部通知，应用自己的通知不动。不支持的平台上什么也不做。
  Future<void> clearAllNotifications() async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('clearAllNotifications');
  }

  /// 把应用角标写成 [count]（只有 iOS；Android 桌面图标上的计数来自通知本身）。宿主报来的角标这里自己转，
  /// 应用不用调。
  Future<void> setBadge(int count) async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('setBadge', {
      'count': count < 0 ? 0 : count,
    });
  }

  Future<void> _stopCorrections() async {
    // 先发起取消、再置空、最后等：等待期间新挂的订阅不会被这里取消掉。
    final cancelling = <Future<void>?>[
      _corrections?.cancel(),
      _presentations?.cancel(),
    ];
    _corrections = null;
    _presentations = null;
    await Future.wait(cancelling.whereType<Future<void>>());
  }

  /// 只转系统展示面（应用内的归 Kit 的横幅）。原生模块不在时丢掉：链路上的提示不补发。
  Future<void> _forwardPresentation(
    PlatformNotificationPresentation presentation,
  ) async {
    if (presentation.surface != PlatformNotificationSurface.system) return;
    try {
      await _methods.invokeMethod<void>(
        'presentNotification',
        presentation.toWire(),
      );
    } on PlatformException {
      // 尽力而为。
    } on MissingPluginException {
      // 尽力而为。
    }
  }

  /// 原生模块不在（插件已卸下）时丢掉这条更正：下一条或回到前台的对账会补上。
  Future<void> _applyCorrection(
      PlatformNotificationCorrection correction) async {
    try {
      switch (correction) {
        case PlatformNotificationClear(:final collapseIds):
          await clearNotifications(collapseIds);
        case PlatformNotificationClearAll():
          await clearAllNotifications();
        case PlatformNotificationBadge(:final count):
          await setBadge(count);
      }
    } on PlatformException {
      // 尽力而为。
    } on MissingPluginException {
      // 尽力而为。
    }
  }

  /// 应用内选的语言（BCP 47，例如 `zh-CN`），令牌登记用它代替系统语言：服务端兜底文案要和界面一致。
  /// 变了原生模块立刻重新登记；null 回到系统语言。
  Future<void> setLocale(String? languageTag) async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('setLocale', languageTag);
  }

  /// 当前的系统通知权限，读到的值也交给 [permissionChanges]。不支持的平台报 [FlarePushPermissionStatus.denied]。
  Future<FlarePushPermissionStatus> permissionStatus() async {
    if (!isSupported) return FlarePushPermissionStatus.denied;
    final status = FlarePushPermissionStatus.fromWire(
      await _methods.invokeMethod<String>('permissionStatus'),
    );
    _publishPermission(status);
    return status;
  }

  /// 权限的变化。监听时先给已知的当前值，之后原生模块在启动、申请之后与每次回到前台重读，变了才发。
  /// 不支持的平台上什么也不发。
  Stream<FlarePushPermissionStatus> get permissionChanges =>
      Stream<FlarePushPermissionStatus>.multi((controller) {
        final current = _permission;
        if (current != null) controller.add(current);
        _permissionListeners.add(controller);
        controller.onCancel = () {
          _permissionListeners.remove(controller);
        };
      });

  /// 现在申请会不会弹出系统授权框。Android：还没问过、或只拒绝过一次（系统建议先解释），而且有页面可弹；
  /// iOS：还没决定。为 false 而权限不是允许时，系统不会再问，只能 [openNotificationSettings]。不支持的平台为 false。
  Future<bool> canRequestPermission() async {
    if (!isSupported) return false;
    return await _methods.invokeMethod<bool>('canRequestPermission') ?? false;
  }

  /// 系统会弹授权框时弹出来，返回之后的权限；结果（包括拒绝）原生模块自己报给宿主，[permissionChanges] 也会收到。
  /// 系统不会弹框时（Android 上拒绝到不再弹框、iOS 上已经决定过）不申请，直接返回现状，由应用决定是否
  /// [openNotificationSettings]。模块自己从不弹框：在用户能理解的时机调用。不支持的平台返回
  /// [FlarePushPermissionStatus.denied]。
  Future<FlarePushPermissionStatus> requestPermission() async {
    if (!isSupported) return FlarePushPermissionStatus.denied;
    final status = FlarePushPermissionStatus.fromWire(
      await _methods.invokeMethod<String>('requestPermission'),
    );
    _publishPermission(status);
    return status;
  }

  /// 打开本应用的系统通知设置，打不开时返回 false。
  Future<bool> openNotificationSettings() async {
    if (!isSupported) return false;
    return await _methods.invokeMethod<bool>('openNotificationSettings') ??
        false;
  }

  /// 启用个推（只有 Android）：应用把 `flare-core-android-push-getui` 加进 Android 依赖、配好个推参数，
  /// 在 [start] 之后、用户同意隐私政策之后调用。没加那个模块或不是 Android 时返回 false。再调一次无害。
  Future<bool> installGetui() async {
    if (!_isAndroid) return false;
    return await _methods.invokeMethod<bool>('installGetui') ?? false;
  }

  /// 后台限制的现状（只有 Android），给「后台接收消息」的引导用，读到的值也交给 [backgroundChanges]；
  /// 其余平台为 null。
  Future<FlarePushBackgroundStatus?> backgroundStatus() async {
    if (!_isAndroid) return null;
    final status = FlarePushBackgroundStatus.fromWire(
      await _methods.invokeMethod<Object>('backgroundStatus'),
    );
    if (status != null) _publishBackground(status);
    return status;
  }

  /// 后台限制的变化（只有 Android）。监听时先给已知的当前值，之后原生模块在启动、接上宿主、申请权限之后与每次
  /// 回到前台重读（用户从电池设置回来就能看到），电池设置的档位变了才发，每次带完整的现状。iOS 与其余平台上什么也不发。
  Stream<FlarePushBackgroundStatus> get backgroundChanges =>
      Stream<FlarePushBackgroundStatus>.multi((controller) {
        final current = _background;
        if (current != null) controller.add(current);
        _backgroundListeners.add(controller);
        controller.onCancel = () {
          _backgroundListeners.remove(controller);
        };
      });

  /// 打开电池优化设置（只有 Android），打不开就退到应用详情页；都打不开返回 false。
  Future<bool> openBatterySettings() async {
    if (!_isAndroid) return false;
    return await _methods.invokeMethod<bool>('openBatterySettings') ?? false;
  }

  /// 打开厂商的自启动管理页（只有 Android），打不开就退到应用详情页；都打不开返回 false。
  Future<bool> openAutoStartSettings() async {
    if (!_isAndroid) return false;
    return await _methods.invokeMethod<bool>('openAutoStartSettings') ?? false;
  }

  /// 点击通知要去的会话。已经过引擎核对，属于当前账号。没有监听者时原生模块留着最近一条。
  Stream<PlatformTapRoute> get routes => _routes ??= isSupported
      ? _routeEvents.receiveBroadcastStream().expand<PlatformTapRoute>((
          Object? event,
        ) {
          final route = PlatformTapRoute.fromWire(event);
          return route == null ? const <PlatformTapRoute>[] : [route];
        })
      : const Stream<PlatformTapRoute>.empty();

  void _listenToNative() {
    if (_listening) return;
    _listening = true;
    _methods.setMethodCallHandler(_onNativeCall);
  }

  void _publishPermission(FlarePushPermissionStatus status) {
    if (_permission == status) return;
    _permission = status;
    for (final listener in List.of(_permissionListeners)) {
      listener.add(status);
    }
  }

  void _publishBackground(FlarePushBackgroundStatus status) {
    if (_background == status) return;
    _background = status;
    for (final listener in List.of(_backgroundListeners)) {
      listener.add(status);
    }
  }

  /// 原生模块调 Dart：权限与后台限制的变化，或宿主的方法（`totalUnread` 与 `setBackgroundPresenter` 只有 Android 调）。
  /// 没有宿主时宿主调用报错，原生模块按载荷原样处理、后台展示器按没接上处理。
  Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method == 'permissionChanged') {
      _publishPermission(FlarePushPermissionStatus.fromWire(call.arguments));
      return null;
    }
    if (call.method == 'backgroundChanged') {
      final status = FlarePushBackgroundStatus.fromWire(call.arguments);
      if (status != null) _publishBackground(status);
      return null;
    }
    final host = _host;
    if (host == null) {
      throw PlatformException(code: 'detached', message: 'no push host');
    }
    final arguments = call.arguments is Map
        ? call.arguments as Map<Object?, Object?>
        : const <Object?, Object?>{};
    switch (call.method) {
      case 'updatePushToken':
        final token = PlatformPushToken.fromWire(arguments);
        if (token == null) {
          throw PlatformException(code: 'malformed', message: 'push token');
        }
        await host.updatePushToken(token);
        return null;
      case 'setPushPermission':
        await host.setPushPermission(allowed: arguments['allowed'] == true);
        return null;
      case 'reconcilePush':
        await host.reconcilePush();
        return null;
      case 'handleRemoteMessage':
        final budget = arguments['budgetMs'];
        final outcome = await host.handleRemoteMessage(
          provider: '${arguments['provider'] ?? ''}',
          payload: _payload(arguments['payload']),
          budgetMs: budget is num ? budget.toInt() : 0,
        );
        return outcome.toWire();
      case 'resolveNotificationTap':
        final route = await host.resolveNotificationTap(
          payload: _payload(arguments['payload']),
        );
        return route?.toWire();
      case 'totalUnread':
        return await host.totalUnread();
      case 'setBackgroundPresenter':
        // 原生的后台展示器在要、有宿主、通知权限也允许时报 true，缺一样报 false
        await host.setBackgroundPresenter(
          attached: arguments['attached'] == true,
        );
        return null;
      default:
        throw MissingPluginException('push host has no ${call.method}');
    }
  }
}

/// 推送载荷：全部取值为字符串的平面字典。
Map<String, String> _payload(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key != null && entry.value != null)
        '${entry.key}': '${entry.value}',
  };
}
