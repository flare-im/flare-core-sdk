import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_port.dart';

// Keep these in sync with Core's vendor presentation transport. IDs are stable:
// Android channel sound is user-owned/immutable once created, not per-message.
const messageChannelId = 'flare_messages_v1';
const quietMessageChannelId = 'flare_messages_quiet_v1';
const noBadgeMessageChannelId = 'flare_messages_no_badge_v1';
const quietNoBadgeMessageChannelId = 'flare_messages_quiet_no_badge_v1';

/// OS channel setup is a transport capability. User system settings win over
/// server hints; channels aren't deleted/recreated to override the user's choice.
List<AndroidNotificationChannel> messageChannels(
  String regularName,
  String quietName,
) => [
  AndroidNotificationChannel(
    messageChannelId,
    regularName,
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    quietMessageChannelId,
    quietName,
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  ),
  AndroidNotificationChannel(
    noBadgeMessageChannelId,
    regularName,
    importance: Importance.high,
    showBadge: false,
  ),
  AndroidNotificationChannel(
    quietNoBadgeMessageChannelId,
    quietName,
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  ),
];

/// Android invokes this in a separate isolate. The OS displays notification
/// payloads. Do NOT create an IM/FFI handle, touch the foreground journal, mark
/// read, navigate or manufacture a persisted message from this untrusted hint.
@pragma('vm:entry-point')
Future<void> flareFirebaseBackgroundMessage(RemoteMessage message) async {}

/// Optional FCM host for Android/iOS. No Firebase dependency is added to Rust or
/// the generated SDK. The host app supplies its own native Firebase config.
final class FirebasePushPort implements NativePushPort {
  FirebasePushPort({required this.channelName, required this.quietChannelName});
  final String channelName;
  final String quietChannelName;
  final _notifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;

  FirebaseMessaging get _instance =>
      _messaging ?? (throw StateError('Push not initialized'));

  @override
  String get provider => 'fcm';
  @override
  String get platform => Platform.isAndroid ? 'android' : 'ios';

  @override
  Future<void> initialize() async {
    // macOS isn't silently mislabeled ios. Direct APNs/macOS/Getui can be added
    // through NativePushPort without changing client IM lifecycle semantics.
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Native push host supports Android/iOS');
    }
    // Native resources also initialize a process started in the background by
    // the vendor. Dart-only options would leave that process unconfigured.
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(flareFirebaseBackgroundMessage);
    _messaging = FirebaseMessaging.instance;
    // No permission prompt here or in local-notification initialization.
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in messageChannels(channelName, quietChannelName)) {
      await android?.createNotificationChannel(channel);
    }
    // Foreground presentation belongs to the normal SDK/UI, never duplicate OS
    // + SDK bubbles. Background/terminated alerts are displayed by the OS.
    await _instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
  }

  @override
  Future<bool> permission({bool request = false}) async {
    final settings = request
        ? await _instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
        : await _instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    // Apple must have APNs registration before requesting an FCM token.
    if (Platform.isIOS && await _instance.getAPNSToken() == null) return null;
    return _instance.getToken();
  }

  @override
  Stream<void> get tokenChanges => _instance.onTokenRefresh.map((_) {});
  @override
  Stream<PushHint> get opened => FirebaseMessaging.onMessageOpenedApp
      .map((m) => PushHint.parse(m.data))
      .where((m) => m != null)
      .cast<PushHint>();
  @override
  Stream<PushHint> get foreground => FirebaseMessaging.onMessage
      .map((m) => PushHint.parse(m.data))
      .where((m) => m != null)
      .cast<PushHint>();
  @override
  Future<PushHint?> initialHint() async {
    final message = await _instance.getInitialMessage();
    return message == null ? null : PushHint.parse(message.data);
  }

  @override
  Future<void> setAutoInit(bool enabled) async {
    if (_messaging != null) await _instance.setAutoInitEnabled(enabled);
  }

  @override
  Future<void> clearNotifications() async {
    if (_messaging != null) await _notifications.cancelAll();
  }
}
