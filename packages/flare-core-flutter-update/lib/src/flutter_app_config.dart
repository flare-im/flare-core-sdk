import 'package:flutter/foundation.dart';

/// The `app` keys a Flutter build decides for itself. The platform source of the
/// SDK fills the rest (`version`, `build`, `target`) and never overrides these.
///
/// [channel] and [distribution] come from the build:
/// `--dart-define=FLARE_APP_CHANNEL=beta`,
/// `--dart-define=FLARE_APP_DISTRIBUTION=play`. Without a channel the core uses
/// `stable`.
///
/// Windows and Linux have no plugin to read the installed package, so their
/// builds say what they are: `--dart-define=FLARE_APP_VERSION=2.4.0`,
/// `--dart-define=FLARE_APP_BUILD=20400`. [build] has to be a plain integer, the
/// server compares builds as integers; anything else stays out. Without these
/// two the update center cannot pick a release there.
///
/// A Flutter Android host ships as a direct install, and an installer the
/// platform source does not know (a phone maker's own package installer) would
/// leave the distribution out, so Android says `direct` unless the build names
/// another one. Other platforms read it from the install.
///
/// [locale] is the language the app itself shows: update notes follow it, not
/// the system language.
Map<String, Object?> flutterAppConfig({
  String? locale,
  String channel = const String.fromEnvironment('FLARE_APP_CHANNEL'),
  String distribution = const String.fromEnvironment('FLARE_APP_DISTRIBUTION'),
  String version = const String.fromEnvironment('FLARE_APP_VERSION'),
  String build = const String.fromEnvironment('FLARE_APP_BUILD'),
  TargetPlatform? platform,
}) {
  final android =
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  final chosen = distribution.trim().isNotEmpty
      ? distribution.trim()
      : android
          ? 'direct'
          : null;
  final language = locale?.trim() ?? '';
  final number = int.tryParse(build.trim());
  return {
    if (version.trim().isNotEmpty) 'version': version.trim(),
    if (number != null && number >= 0) 'build': number,
    if (channel.trim().isNotEmpty) 'channel': channel.trim(),
    if (chosen != null) 'distribution': chosen,
    if (language.isNotEmpty) 'locale': language,
  };
}
