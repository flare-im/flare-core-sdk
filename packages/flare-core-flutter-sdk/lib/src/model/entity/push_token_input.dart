// GENERATED. Do not edit by hand.

/// PushTokenInput
final class PushTokenInput {
  /// wire: `appBundle`. iOS bundle id or Android applicationId. The server sends APNs to this topic.
  final String? appBundle;
  /// wire: `appVersion`. App version string.
  final String? appVersion;
  /// wire: `capabilities`. What the app can do with a push: dataMessages (Android FCM data messages) and serviceExtension (iOS notification service extension). Unknown values are rejected.
  final List<String>? capabilities;
  /// wire: `environment`. APNs only: sandbox or production, the APNs host the token belongs to.
  final String? environment;
  /// wire: `locale`. BCP 47 language tag the server renders notification text in, e.g. zh-CN.
  final String? locale;
  /// wire: `platform`. Native platform: android, ios or harmony.
  final String platform;
  /// wire: `provider`. OS delivery provider: fcm, apns or getui.
  final String provider;
  /// wire: `timeZone`. IANA time zone, e.g. Asia/Shanghai.
  final String? timeZone;
  /// wire: `token`. OS-issued token. Never log or persist outside protected native storage.
  final String token;

  const PushTokenInput({
    this.appBundle,
    this.appVersion,
    this.capabilities,
    this.environment,
    this.locale,
    this.platform = '',
    this.provider = '',
    this.timeZone,
    this.token = '',
  });
}
