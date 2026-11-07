import 'dart:async';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flare_core_flutter_sdk/src/bridge/ffi_native_bridge.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectTokenRefresh', () {
    test('hands the host token to the core', () async {
      final answers = <(int, String?)>[];
      final refresh = ConnectTokenRefresh(
        refresher: () async => 'token-2',
        complete: (requestId, token) {
          answers.add((requestId, token));
          return true;
        },
      );

      expect(await refresh.answer(7), isTrue);
      expect(answers, [(7, 'token-2')]);
    });

    test('a host that throws or has nothing answers with no token', () async {
      final answers = <(int, String?)>[];
      bool complete(int requestId, String? token) {
        answers.add((requestId, token));
        return true;
      }

      await ConnectTokenRefresh(
        refresher: () async => throw StateError('refresh endpoint down'),
        complete: complete,
      ).answer(1);
      await ConnectTokenRefresh(
        refresher: () async => null,
        complete: complete,
      ).answer(2);

      expect(answers, [(1, null), (2, null)]);
    });

    test('a host slower than the core waits answers with no token', () async {
      final answers = <(int, String?)>[];
      final never = Completer<String?>();
      final refresh = ConnectTokenRefresh(
        refresher: () => never.future,
        complete: (requestId, token) {
          answers.add((requestId, token));
          return false;
        },
        timeout: const Duration(milliseconds: 20),
      );

      // The core gave up on it too: the answer reports that.
      expect(await refresh.answer(3), isFalse);
      expect(answers, [(3, null)]);
    });
  });

  group('client setConnectTokenRefresher', () {
    test('hands the host function to the bridge hook, null removes it',
        () async {
      final bridge = _HookBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      Future<String?> refresher() async => 'token-2';

      await client.setConnectTokenRefresher(refresher);
      expect(bridge.installed, [refresher]);
      expect(await bridge.installed.single!(), 'token-2');

      await client.setConnectTokenRefresher(null);
      expect(bridge.installed, [refresher, null]);
    });

    test('a bridge without the hook reports capabilityUnavailable', () async {
      final client = FlareCoreSdk.createClientWithBridge(_PlainBridge());

      await expectLater(
        client.setConnectTokenRefresher(() async => 'token'),
        throwsA(isA<FlareSdkException>().having(
          (error) => error.code,
          'code',
          SdkErrorCodes.capabilityUnavailable,
        )),
      );
    });
  });

  // Needs a built `libflare_im_core_sdk_ffi` speaking flare-im-ffi/v2.
  final library = Platform.environment['FLARE_FFI_TEST_LIBRARY'];
  test('the C ABI installs, answers and removes a refresher', () async {
    final bridge = FfiNativeBridge(libraryPath: library);
    try {
      // No refresher yet: the core has nothing to answer.
      expect(bridge.completeConnectTokenRefresh(1, 'token'), isFalse);

      await bridge.setConnectTokenRefresher(() async => 'token');
      // Installed, but request 1 was never asked: it is not waited for.
      expect(bridge.completeConnectTokenRefresh(1, 'token'), isFalse);

      await bridge.setConnectTokenRefresher(null);
      expect(bridge.completeConnectTokenRefresh(1, null), isFalse);
    } finally {
      await bridge.invoke<void>(NativeCallMap.sdkDispose);
    }
  },
      skip: library == null
          ? 'set FLARE_FFI_TEST_LIBRARY to a built native library'
          : false);
}

final class _PlainBridge implements NativeBridge {
  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
          [Object? request]) async =>
      null as T;
}

final class _HookBridge implements NativeBridge, ConnectTokenRefresherBridge {
  final installed = <ConnectTokenRefresher?>[];

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
          [Object? request]) async =>
      null as T;

  @override
  Future<void> setConnectTokenRefresher(
    ConnectTokenRefresher? refresher,
  ) async {
    installed.add(refresher);
  }
}
