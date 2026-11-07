import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// Thin OS adapter. No plaintext fallback, iCloud sync, or automatic key reset.
class MobileCredentialStore implements CredentialStore {
  MobileCredentialStore({
    required this.preferences,
    required this.binding,
    required this.key,
    required this.legacyKey,
    FlutterSecureStorage? storage,
  }) : storage = storage ??
            FlutterSecureStorage(
              // Ad-hoc macOS debug builds have no provisioning identity for the
              // data-protection keychain. Keep credentials in the OS login
              // keychain, in a service scoped to this app and installation.
              mOptions: MacOsOptions(
                usesDataProtectionKeychain: !kDebugMode,
                accountName: kDebugMode
                    ? 'flare.debug.$key.$binding'
                    : AppleOptions.defaultAccountName,
              ),
              iOptions: const IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
                accountName: 'flare.session',
              ),
              aOptions: const AndroidOptions(
                resetOnError: false,
                sharedPreferencesName: 'flare_credentials',
              ),
            );

  final SharedPreferences preferences;
  final String binding;
  final String key;
  final String legacyKey;
  final FlutterSecureStorage storage;
  String get _blocked => '$key.blocked';
  String get _revision => '$key.revision';
  // One physical vault may be read by multiple app clients in this isolate.
  static final Map<String, Future<void>> _tails = {};
  Future<T> _serial<T>(Future<T> Function() body) {
    final result = (_tails[key] ?? Future<void>.value()).then((_) => body());
    _tails[key] = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _removeLegacy() async {
    if (!await preferences.remove(legacyKey))
      throw StateError('Credential cleanup failed');
  }

  Future<void> _block(bool value) async {
    if (!await preferences.setBool(_blocked, value))
      throw StateError('Credential state unavailable');
  }

  Future<void> _erase() async {
    await _block(true);
    await _removeLegacy();
    await storage.delete(key: key);
    if (!await preferences.remove(_revision)) {
      throw StateError('Credential cleanup failed');
    }
  }

  Future<void> _save(String value) async {
    // A crash at any stage prevents replay of an older one-time refresh token.
    await _block(true);
    final random = Random.secure();
    final revision = base64UrlEncode(
      List.generate(24, (_) => random.nextInt(256)),
    );
    try {
      await storage.write(
        key: key,
        value: jsonEncode({
          'version': 2,
          'binding': binding,
          'revision': revision,
          'value': value,
        }),
      );
      await _removeLegacy();
      // Android's plugin uses apply(). If its ciphertext did not reach disk, a
      // durable checkpoint for the new revision rejects the older vault value.
      if (!await preferences.setString(_revision, revision)) {
        throw StateError('Credential checkpoint unavailable');
      }
      await _block(false);
    } catch (_) {
      await _removeLegacy();
      rethrow;
    }
  }

  @override
  Future<String?> read() => _serial(() async {
        if (preferences.getBool(_blocked) == true) {
          await _erase();
          return null;
        }
        try {
          final raw = await storage.read(key: key);
          if (raw != null) {
            final record = jsonDecode(raw);
            if (record is! Map ||
                record['version'] != 2 ||
                record['binding'] != binding ||
                record['revision'] is! String ||
                record['revision'] != preferences.getString(_revision) ||
                record['value'] is! String) {
              await _erase();
              return null;
            }
            await _removeLegacy();
            return record['value'] as String;
          }
          if (preferences.containsKey(_revision)) {
            await _erase();
            return null;
          }
          final legacy = preferences.getString(legacyKey);
          if (legacy == null) return null;
          await _save(legacy);
          return legacy;
        } catch (_) {
          // Locked/unavailable secure storage never enables a plaintext fallback.
          await _block(true);
          await _removeLegacy();
          rethrow;
        }
      });
  @override
  Future<void> write(String value) => _serial(() => _save(value));
  @override
  Future<void> clear() => _serial(_erase);
}
