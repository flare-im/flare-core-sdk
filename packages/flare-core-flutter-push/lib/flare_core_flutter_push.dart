/// 系统推送的 Flutter 桥：通知权限、系统令牌、远程推送、点击、角标与登出清理都由原生的平台推送模块处理
/// （iOS 的 `FlarePlatformPush`、Android 的 `flare-core-android-push`），这里只把它们的宿主调用
/// 转给 Dart 侧接上的 [FlarePushHost]，把宿主报来的通知更正转给原生模块，再把点击去向和权限状态交回 Dart。
/// Android 上另桥接个推的启用与后台限制引导。
///
/// 链路在线时引擎自己出的系统通知由 [FlareNotificationPresenter] 交给原生展示方：Android 的后台展示器，
/// macOS、Linux、Windows 的桌面系统通知。
///
/// 没有 Dart 后台入口：进程被推送拉起、还没有引擎或宿主时，原生模块按载荷原样展示。
library;

export 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart'
    show
        CorePushHost,
        FlarePushHost,
        PlatformNotificationBadge,
        PlatformNotificationChannel,
        PlatformNotificationClear,
        PlatformNotificationClearAll,
        PlatformNotificationCorrection,
        PlatformNotificationPresentation,
        PlatformNotificationSurface,
        PlatformPushAction,
        PlatformPushOutcome,
        PlatformPushToken,
        PlatformTapRoute;

export 'src/background_status.dart';
export 'src/flare_push.dart';
export 'src/notification_presenter.dart';
