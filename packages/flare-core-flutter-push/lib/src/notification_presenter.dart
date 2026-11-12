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
        PlatformTapRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'flare_push.dart';

/// 链路在线时，引擎决定、渲染好的系统通知在这个平台上由谁弹出来。
enum FlareNotificationPresenterKind {
  /// 没有：iOS（进后台即托管，后台提示走 APNs）、Web 与其余平台。
  none,

  /// Android：原生推送模块的后台展示器。接上后引擎在后台照常确认、自己出系统通知，服务端推送只兜底冻结或被杀的进程。
  androidBackground,

  /// macOS、Linux、Windows：桌面的系统通知。桌面本来就自己提示，不用告诉引擎。
  desktop,
}

/// [FlareNotificationPresenter.attach] 的选项。
@immutable
final class FlareNotificationPresenterOptions {
  const FlareNotificationPresenterOptions({this.windowsAppUserModelId});

  /// 只有 Windows：应用注册过的 AppUserModelID（安装时建的开始菜单快捷方式带着它，或写在
  /// `HKCU\Software\Classes\AppUserModelId\<id>` 下）。不给时用进程自己设的那个；打包（MSIX）的应用用包的身份，
  /// 不用给。都没有时退回托盘气泡（见 README 的已知限制）。
  final String? windowsAppUserModelId;

  Map<String, Object?> toWire() {
    final id = windowsAppUserModelId?.trim() ?? '';
    return {if (id.isNotEmpty) 'windowsAppUserModelId': id};
  }
}

/// 链路在线时的系统通知展示方。展示逻辑全在原生里，Dart 只搬运。
///
/// - Android：原生推送模块（`flare-core-android-push`）的后台展示器 `FlareBackgroundPresenter`。[attach] 告诉
///   原生「要」；原生在有宿主（[FlarePush.attach] 接上的那个）、通知权限也允许时经宿主告诉引擎
///   `setBackgroundPresenter(true)`，权限被关时告诉 false、重新授权后再接回。引擎交来的通知、清除与角标由
///   [FlarePush] 经方法通道转给原生，沿用推送的四个通知渠道与 tag（合并键），点击与推送的通知一样从
///   [FlarePush.routes] 出来。要先 [FlarePush.start] 与 [FlarePush.attach]。
/// - macOS（UNUserNotificationCenter）、Linux（`org.freedesktop.Notifications`）、Windows（toast，没有注册
///   AppUserModelID 时退回托盘气泡）：本类把宿主交来的系统展示面、清除与角标转给原生。一个会话一条通知，新的替换
///   旧的；点击把窗口带到前面，去向从 [routes] 出来。不告诉引擎：桌面本来就自己提示。
/// - iOS、Web 与其余平台：每个方法都什么也不做。
///
/// 登录或恢复会话之后 [attach] 宿主（与 [FlarePush.attach] 同一个），登出时 [signOut]。macOS 上系统通知要授权：
/// 在用户能理解的时机 [requestPermission]。
final class FlareNotificationPresenter {
  FlareNotificationPresenter._(this._methods, this._tapEvents, this._push);

  /// 换成自己的通道，测试用。
  @visibleForTesting
  factory FlareNotificationPresenter.withChannels({
    required MethodChannel methods,
    required EventChannel taps,
    FlarePush? push,
  }) =>
      FlareNotificationPresenter._(
        methods,
        taps,
        push ?? FlarePush.instance,
      );

  static final FlareNotificationPresenter instance =
      FlareNotificationPresenter._(
    const MethodChannel(methodChannelName),
    const EventChannel(tapsChannelName),
    FlarePush.instance,
  );

  /// Dart 调原生：`attach`（[FlareNotificationPresenterOptions.toWire]，答 `{attached, backend}`）、`detach`；桌面上另有
  /// `present`（`PlatformNotificationPresentation.toWire()`）、`clear`（`{collapseIds}`）、`clearAll`、`setBadge`（`{count}`）、
  /// `permissionStatus`、`requestPermission`。
  static const methodChannelName = 'im.flare.push/presenter';

  /// 桌面通知的点击：`{conversationId, messageId?, seq?}`。没人监听时原生留着最近一条，监听后补发。
  static const tapsChannelName = 'im.flare.push/presenter/taps';

  final MethodChannel _methods;
  final EventChannel _tapEvents;
  final FlarePush _push;
  FlarePushHost? _host;
  StreamSubscription<PlatformNotificationPresentation>? _presentations;
  StreamSubscription<PlatformNotificationCorrection>? _corrections;
  AppLifecycleListener? _lifecycle;
  Stream<PlatformTapRoute>? _routes;
  String? _backend;

  /// 这个平台用哪种展示方。
  FlareNotificationPresenterKind get kind {
    if (kIsWeb) return FlareNotificationPresenterKind.none;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        FlareNotificationPresenterKind.androidBackground,
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        FlareNotificationPresenterKind.desktop,
      _ => FlareNotificationPresenterKind.none,
    };
  }

  /// 这个平台有没有系统通知的展示方。
  bool get isSupported => kind != FlareNotificationPresenterKind.none;

  /// 接着宿主。
  bool get isAttached => _host != null;

  /// 原生用的展示方，诊断用：`android`、`userNotificationCenter`、`freedesktop`、`toast`、`tray`，不可用时为 `none`；
  /// 没接上过为 null。
  String? get backend => _backend;

  /// 接上宿主。Android 上告诉原生的后台展示器「要」（引擎由原生经 [FlarePush] 的宿主告知）；桌面上开始把宿主交来的
  /// 系统通知、清除与角标转给原生。再调一次等于重新接上。
  Future<void> attach(
    FlarePushHost host, {
    FlareNotificationPresenterOptions options =
        const FlareNotificationPresenterOptions(),
  }) async {
    await _stopForwarding();
    _host = host;
    if (!isSupported) return;
    final answer = await _methods.invokeMethod<Object?>(
      'attach',
      options.toWire(),
    );
    final wire = answer is Map ? answer : const <Object?, Object?>{};
    _backend = wire['backend'] is String ? wire['backend'] as String : null;
    // 宿主在等原生答复时可能已经换了或摘了
    if (!identical(_host, host)) return;
    if (kind == FlareNotificationPresenterKind.androidBackground) {
      _watchEngineTeardown();
      return;
    }
    _presentations = host.notificationPresentations().listen(
          (presentation) => unawaited(_present(presentation)),
          // 尽力而为：宿主的流出错不影响别的
          onError: (Object _) {},
        );
    _corrections = host.notificationCorrections().listen(
          (correction) => unawaited(_apply(correction)),
          onError: (Object _) {},
        );
  }

  /// 摘下宿主（客户端释放、但账号没有退出时）。已经出的通知留着。
  ///
  /// Android 上先直接告诉引擎不再替它出通知，再告诉原生「不要」：原生经宿主转一圈回到 Dart 才到引擎，Flutter 引擎
  /// 正在拆掉时那一圈走不完，引擎会一直以为有人替它提示。
  Future<void> detach() async {
    final host = _host;
    _host = null;
    await _stopForwarding();
    if (!isSupported) return;
    if (kind == FlareNotificationPresenterKind.androidBackground &&
        host != null) {
      try {
        await host.setBackgroundPresenter(attached: false);
      } on Object {
        // 尽力而为：原生接下来照样经宿主报一次。
      }
    }
    await _methods.invokeMethod<void>('detach');
  }

  /// 登出：摘下宿主，撤掉本展示方出的全部通知，角标归零。Android 上通知与角标由 [FlarePush.signOut] 清。
  Future<void> signOut() async {
    await detach();
    if (kind != FlareNotificationPresenterKind.desktop) return;
    await _methods.invokeMethod<void>('clearAll');
    await _methods.invokeMethod<void>('setBadge', {'count': 0});
  }

  /// 当前的系统通知权限。Android 是推送模块的那一个（[FlarePush.permissionStatus]）；Linux 与 Windows 没有授权
  /// 这一步，报允许（Windows 上用户在系统设置里关掉了报拒绝）；不支持的平台报拒绝。
  Future<FlarePushPermissionStatus> permissionStatus() async {
    switch (kind) {
      case FlareNotificationPresenterKind.none:
        return FlarePushPermissionStatus.denied;
      case FlareNotificationPresenterKind.androidBackground:
        return _push.permissionStatus();
      case FlareNotificationPresenterKind.desktop:
        return FlarePushPermissionStatus.fromWire(
          await _methods.invokeMethod<String>('permissionStatus'),
        );
    }
  }

  /// 系统会弹授权框时弹出来，返回之后的权限：macOS 只在还没决定时弹；Android 走推送模块
  /// （[FlarePush.requestPermission]）；Linux 与 Windows 不用授权，直接返回现状。模块自己从不弹框。
  Future<FlarePushPermissionStatus> requestPermission() async {
    switch (kind) {
      case FlareNotificationPresenterKind.none:
        return FlarePushPermissionStatus.denied;
      case FlareNotificationPresenterKind.androidBackground:
        return _push.requestPermission();
      case FlareNotificationPresenterKind.desktop:
        return FlarePushPermissionStatus.fromWire(
          await _methods.invokeMethod<String>('requestPermission'),
        );
    }
  }

  /// 点击桌面通知要去的会话（会话 id 与那条消息）。只有桌面有：Android 的点击从 [FlarePush.routes] 出来。
  /// 点通知把应用拉起来的那一下原生先留着，有人监听时补发；摘要通知不属于哪个会话，点了只把窗口带到前面。
  Stream<PlatformTapRoute> get routes =>
      _routes ??= kind == FlareNotificationPresenterKind.desktop
          ? _tapEvents.receiveBroadcastStream().expand<PlatformTapRoute>((
              Object? event,
            ) {
              final route = PlatformTapRoute.fromWire(event);
              return route == null ? const <PlatformTapRoute>[] : [route];
            })
          : const Stream<PlatformTapRoute>.empty();

  Future<void> _stopForwarding() async {
    // 先发起取消、再置空、最后等：等待期间新挂的订阅不会被这里取消掉。
    final cancelling = <Future<void>?>[
      _presentations?.cancel(),
      _corrections?.cancel(),
    ];
    _presentations = null;
    _corrections = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    await Future.wait(cancelling.whereType<Future<void>>());
  }

  /// Android：宿主页面没了（返回键退出、页面被回收），Flutter 引擎随后拆掉，Dart 不再能把通知转给原生。进程还在时
  /// 引擎照样确认消息，提示就丢了：趁还能调用时摘下，后台提示交回服务端推送。
  void _watchEngineTeardown() {
    _lifecycle = AppLifecycleListener(onDetach: () => unawaited(detach()));
  }

  /// 只出系统展示面；应用内的归 Kit 的横幅。标题与正文都空的落不成通知。
  Future<void> _present(PlatformNotificationPresentation presentation) async {
    if (presentation.surface != PlatformNotificationSurface.system) return;
    if (presentation.title.isEmpty && presentation.body.isEmpty) return;
    await _invoke('present', presentation.toWire());
  }

  Future<void> _apply(PlatformNotificationCorrection correction) async {
    switch (correction) {
      case PlatformNotificationClear(:final collapseIds):
        if (collapseIds.isEmpty) return;
        await _invoke('clear', {'collapseIds': List<String>.of(collapseIds)});
      case PlatformNotificationClearAll():
        await _invoke('clearAll', null);
      case PlatformNotificationBadge(:final count):
        await _invoke('setBadge', {'count': count < 0 ? 0 : count});
    }
  }

  /// 转交尽力而为：原生展示方不在（插件已卸下）时丢掉，下一条会补上。
  Future<void> _invoke(String method, Object? arguments) async {
    try {
      await _methods.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // 尽力而为。
    } on MissingPluginException {
      // 尽力而为。
    }
  }
}
