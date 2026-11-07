import 'dart:convert';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

Map<String, Object?> _status({
  Object? connectAck,
  Object? refresh,
  Object? recovering,
}) =>
    {
      'loaded': true,
      'serial': 42,
      'source': 'seed',
      'stale': false,
      'developmentMode': false,
      'issuedAtMs': null,
      'expiresAtMs': null,
      'fetchedAtMs': null,
      'regionId': 'sg',
      'cellId': 'cell-sg-a',
      'keystateSerial': null,
      'accessPointId': 'ap-sg-1',
      'protocol': 'quic',
      'pinned': null,
      'connectAck': connectAck,
      'refresh': refresh,
      'recovering': recovering,
    };

void main() {
  group('accessStatusFromJson', () {
    test('reads the CONNECT_ACK diagnostics of the current connection', () {
      final status = accessStatusFromJson(_status(connectAck: {
        'gatewayId': 'gw-7',
        'accessPointId': 'ap-sg-2',
        'accessSerial': 43,
        'heartbeatIntervalHintSec': 25,
        'accessPointMismatch': true,
      }));

      final ack = status.connectAck!;
      expect(ack.gatewayId, 'gw-7');
      expect(ack.accessPointId, 'ap-sg-2');
      expect(ack.accessSerial, 43);
      expect(ack.heartbeatIntervalHintSec, 25);
      expect(ack.accessPointMismatch, isTrue);
      expect(status.accessPointId, 'ap-sg-1');
    });

    test('keeps absent CONNECT_ACK fields null', () {
      final ack = accessStatusFromJson(_status(connectAck: {
        'gatewayId': null,
        'accessPointId': null,
        'accessSerial': null,
        'heartbeatIntervalHintSec': null,
        'accessPointMismatch': false,
      })).connectAck!;

      expect(ack.gatewayId, isNull);
      expect(ack.accessPointId, isNull);
      expect(ack.accessSerial, isNull);
      expect(ack.heartbeatIntervalHintSec, isNull);
      expect(ack.accessPointMismatch, isFalse);
    });

    test('has no CONNECT_ACK without a connection', () {
      expect(accessStatusFromJson(_status()).connectAck, isNull);
    });

    test('reads the manifest times, refresh progress and recovery', () {
      final status = accessStatusFromJson({
        ..._status(
          refresh: {
            'lastAttemptAtMs': 1793779260000,
            'lastSuccessAtMs': 1793779200000,
            'lastOutcome': 'adopted',
            'nextAtMs': 1793800860000,
          },
          recovering: {
            'sinceMs': 1793779000000,
            'rounds': 2,
            'nextRoundAtMs': 1793779090000,
          },
        ),
        'issuedAtMs': 1793779200000,
        'expiresAtMs': 1796371200000,
        'fetchedAtMs': 1793779260000,
      });

      expect(status.issuedAtMs, 1793779200000);
      expect(status.expiresAtMs, 1796371200000);
      expect(status.fetchedAtMs, 1793779260000);
      expect(status.refresh?.lastAttemptAtMs, 1793779260000);
      expect(status.refresh?.lastSuccessAtMs, 1793779200000);
      expect(status.refresh?.lastOutcome, 'adopted');
      expect(status.refresh?.nextAtMs, 1793800860000);
      expect(status.recovering?.sinceMs, 1793779000000);
      expect(status.recovering?.rounds, 2);
      expect(status.recovering?.nextRoundAtMs, 1793779090000);
    });

    test('keeps absent refresh and recovery fields null', () {
      final status = accessStatusFromJson(_status(
        refresh: {
          'lastAttemptAtMs': null,
          'lastSuccessAtMs': null,
          'lastOutcome': null,
          'nextAtMs': null,
        },
        recovering: {'sinceMs': 5, 'rounds': 0, 'nextRoundAtMs': null},
      ));

      expect(status.refresh?.lastOutcome, isNull);
      expect(status.refresh?.nextAtMs, isNull);
      expect(status.recovering?.nextRoundAtMs, isNull);
      expect(accessStatusFromJson(_status()).refresh, isNull);
      expect(accessStatusFromJson(_status()).recovering, isNull);
    });
  });

  group('access operations', () {
    test('refresh reports every source it tried', () async {
      final bridge = _AccessBridge({
        'access.refresh': {
          'outcome': 'adopted',
          'mode': 'background',
          'serial': 42,
          'source': 'https:https://cfg-b/',
          'keystateSerial': 3,
          'attempts': [
            {
              'source': 'https:https://cfg-a/',
              'tier': 'mirror',
              'document': 'access',
              'result': 'failed',
              'code': 'timeout',
              'serial': null,
            },
            {
              'source': 'https:https://cfg-b/',
              'tier': 'mirror',
              'document': 'access',
              'result': 'adopted',
              'code': null,
              'serial': 42,
            },
          ],
        },
      });

      final report = await DefaultFlareImClient(bridge).access.refresh();

      expect(bridge.operations, ['access.refresh']);
      expect(report.outcome, 'adopted');
      expect(report.mode, 'background');
      expect(report.serial, 42);
      expect(report.source, 'https:https://cfg-b/');
      expect(report.keystateSerial, 3);
      expect(report.attempts.map((attempt) => attempt.result),
          ['failed', 'adopted']);
      expect(report.attempts.first.code, 'timeout');
      expect(report.attempts.first.serial, isNull);
      expect(report.attempts.last.code, isNull);
      expect(report.attempts.last.serial, 42);
    });

    test('a refresh with nothing adopted has no source', () {
      final report = accessRefreshReportFromJson({
        'outcome': 'skipped',
        'mode': 'background',
        'serial': 0,
        'source': null,
        'keystateSerial': null,
        'attempts': <Object?>[],
      });

      expect(report.source, isNull);
      expect(report.keystateSerial, isNull);
      expect(report.attempts, isEmpty);
    });

    test('a refresh without an attempts array is refused', () {
      expect(
        () => accessRefreshReportFromJson({
          'outcome': 'failed',
          'mode': 'background',
          'serial': 0,
        }),
        throwsA(anything),
      );
    });

    test('a recovery link goes verbatim, a bad one is an answer', () async {
      const link = 'flare-recover://v1?p=abc&k=root-a&s=def';
      final bridge = _AccessBridge({
        'access.import_recovery': {
          'outcome': 'rejected',
          'code': 'rollback',
          'serial': 42,
        },
      });

      final imported = await DefaultFlareImClient(bridge)
          .access
          .importRecovery(const AccessImportRecoveryRequest(link: link));

      expect(bridge.operations, ['access.import_recovery']);
      expect(bridge.requests.single, {'link': link});
      expect(imported.outcome, 'rejected');
      expect(imported.code, 'rollback');
      expect(imported.serial, 42);
    });

    test('an adopted recovery link has no code', () {
      final imported = accessRecoveryImportFromJson(
          {'outcome': 'adopted', 'code': null, 'serial': 2000});

      expect(imported.outcome, 'adopted');
      expect(imported.code, isNull);
      expect(imported.serial, 2000);
    });
  });
}

/// Answers each operation with its JSON, decoded the way the FFI bridge hands it over.
final class _AccessBridge implements NativeBridge {
  _AccessBridge(this.answers);

  final Map<String, Object?> answers;
  final List<String> operations = [];
  final List<Object?> requests = [];

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    operations.add(descriptor.operation);
    requests.add(request);
    return jsonDecode(jsonEncode(answers[descriptor.operation])) as T;
  }
}
