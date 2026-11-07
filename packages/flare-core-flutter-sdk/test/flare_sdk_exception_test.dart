import 'package:flare_core_flutter_sdk/src/flare_core_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('a native error takes the structured error the SDK wrote in details_json', () {
    final error = FlareSdkException.fromNative(
      nativeCode: 8,
      message: '错误 [OPERATION_FAILED] sdk.plugin.rejected',
      operation: 'capability.dispatch',
      details: {
        'code': 'OPERATION_FAILED',
        'reason': 'sdk.plugin.rejected',
        'retryable': false,
        'httpStatus': 422,
        'machineReason': 'CALL_FULL',
      },
    );
    expect(error.code, 'OPERATION_FAILED');
    expect(error.reason, 'sdk.plugin.rejected');
    expect(error.machineReason, 'CALL_FULL');
    expect(error.httpStatus, 422);
    expect(error.retryable, isFalse);
    expect(error.operation, 'capability.dispatch');
  });

  test('a refusal names the refused messages as a typed list', () {
    final error = FlareSdkException.fromNative(
      nativeCode: 2,
      message: '错误 [INVALID_PARAMETER] sdk.message.forward.not_forwardable: s-2, s-3',
      operation: 'message_builder.create_forward',
      details: {
        'code': 'INVALID_PARAMETER',
        'reason': 'sdk.message.forward.not_forwardable: s-2, s-3',
        'retryable': false,
        'refusedMessageIds': ['s-2', 's-3'],
      },
    );
    expect(error.code, 'INVALID_PARAMETER');
    expect(error.refusedMessageIds, ['s-2', 's-3']);
    for (final odd in [
      <Object?>[],
      ['s-2', 3],
      's-2,s-3',
      null,
    ]) {
      final other = FlareSdkException.fromNative(
        nativeCode: 2,
        message: 'x',
        operation: null,
        details: {'code': 'INVALID_PARAMETER', 'refusedMessageIds': odd},
      );
      expect(other.refusedMessageIds, isNull, reason: '$odd');
    }
  });

  test('a native error without details keeps the C ABI code', () {
    final error = FlareSdkException.fromNative(
      nativeCode: 5,
      message: 'network down',
      operation: 'sdk.login',
      details: null,
    );
    expect(error.code, 'native_error_5');
    expect(error.reason, isNull);
    expect(error.machineReason, isNull);
  });

  group('typed errors by C ABI code', () {
    test('code 12 is an OverloadedException with the server wait', () {
      final error = FlareSdkException.fromNative(
        nativeCode: 12,
        message: 'overloaded',
        operation: 'sdk.connect',
        details: {
          'code': 'OVERLOADED',
          'reason': 'sdk.link.overloaded',
          'retryable': true,
          'retryAfterMs': 1500,
        },
      );
      expect(error, isA<OverloadedException>());
      final overloaded = error as OverloadedException;
      expect(overloaded.code, 'OVERLOADED');
      expect(overloaded.retryAfterMs, 1500);
      expect(overloaded.retryable, isTrue);
      expect(overloaded.reason, 'sdk.link.overloaded');
      expect(overloaded.operation, 'sdk.connect');
    });

    test('code 13 is an UpgradeRequiredException', () {
      final error = FlareSdkException.fromNative(
        nativeCode: 13,
        message: 'upgrade required',
        operation: 'sdk.login',
        details: {'code': 'UPGRADE_REQUIRED', 'retryable': false},
      );
      expect(error, isA<UpgradeRequiredException>());
      expect(error.code, 'UPGRADE_REQUIRED');
      expect(error.retryable, isFalse);
    });

    test('code 14 is a NetworkUncertainException', () {
      final error = FlareSdkException.fromNative(
        nativeCode: 14,
        message: 'uncertain',
        operation: 'message.send',
        details: {
          'code': 'NETWORK_UNCERTAIN',
          'retryable': false,
          'httpStatus': 504,
        },
      );
      expect(error, isA<NetworkUncertainException>());
      expect(error.code, 'NETWORK_UNCERTAIN');
      expect(error.httpStatus, 504);
    });

    test('the structured code alone picks the typed error', () {
      expect(
        FlareSdkException.fromNative(
          nativeCode: 8,
          message: 'x',
          operation: null,
          details: {'code': 'OVERLOADED'},
        ),
        isA<OverloadedException>()
            .having((error) => error.retryAfterMs, 'retryAfterMs', isNull),
      );
      expect(
        FlareSdkException.fromNative(
          nativeCode: 13,
          message: 'x',
          operation: null,
          details: null,
        ),
        isA<UpgradeRequiredException>(),
      );
      expect(
        FlareSdkException.fromNative(
          nativeCode: 8,
          message: 'x',
          operation: null,
          details: {'code': 'networkUncertain'},
        ),
        isA<NetworkUncertainException>(),
      );
    });

    test('other codes stay plain FlareSdkException', () {
      final error = FlareSdkException.fromNative(
        nativeCode: 5,
        message: 'network down',
        operation: 'sdk.connect',
        details: {'code': 'NETWORK_ERROR', 'retryable': true},
      );
      expect(error.runtimeType, FlareSdkException);
      expect(error.code, 'NETWORK_ERROR');
    });
  });
}
