import 'package:flare_core_flutter_update/flare_core_flutter_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a host can use a separate Flutter release platform on each OS', () {
    const options = {
      TargetPlatform.android: 'flutter-direct',
      TargetPlatform.iOS: 'flutter-appstore',
      TargetPlatform.windows: 'flutter-windows',
      TargetPlatform.macOS: 'flutter-macos',
    };
    for (final entry in options.entries) {
      final app = flutterAppConfig(
        platform: entry.key,
        separateReleasePlatform: true,
      );
      expect(app['distribution'], entry.value);
    }
    expect(
      flutterAppConfig(
        platform: TargetPlatform.android,
        distribution: 'flutter-play',
        separateReleasePlatform: true,
      )['distribution'],
      'flutter-play',
    );
  });

  test('an Android host is a direct install unless the build says otherwise',
      () {
    expect(
      flutterAppConfig(platform: TargetPlatform.android),
      {'distribution': 'direct'},
    );
    expect(
      flutterAppConfig(
        platform: TargetPlatform.android,
        distribution: 'play',
      ),
      {'distribution': 'play'},
    );
  });

  test('other platforms leave the distribution to the install', () {
    expect(flutterAppConfig(platform: TargetPlatform.iOS), isEmpty);
    expect(flutterAppConfig(platform: TargetPlatform.macOS), isEmpty);
  });

  test('gives the channel and the language the app shows', () {
    expect(
      flutterAppConfig(
        platform: TargetPlatform.iOS,
        channel: ' beta ',
        locale: 'zh-CN',
      ),
      {'channel': 'beta', 'locale': 'zh-CN'},
    );
  });

  test('a desktop build with no package to read says what it is', () {
    expect(
      flutterAppConfig(
        platform: TargetPlatform.linux,
        version: ' 2.4.0 ',
        build: ' 20400 ',
      ),
      {'version': '2.4.0', 'build': 20400},
    );
  });

  test('a build that is no integer stays out', () {
    for (final build in ['2.4.0', '-1', 'abc']) {
      expect(
        flutterAppConfig(platform: TargetPlatform.windows, build: build),
        isEmpty,
      );
    }
  });

  test('blank values stay out, so the platform source can fill them', () {
    expect(
      flutterAppConfig(
        platform: TargetPlatform.iOS,
        channel: ' ',
        distribution: ' ',
        locale: ' ',
        version: ' ',
        build: ' ',
      ),
      isEmpty,
    );
  });
}
