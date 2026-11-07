import 'dart:convert';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

/// The engine's link status vectors (`flare-core-sdk-engine/tests/vectors/link_status.json`): each
/// case's `expected` is a `connection://status` payload exactly as the core puts it on the wire.
/// Every platform package decodes the same file.
void main() {
  final table = jsonDecode(
    File('../../../flare-core-sdk-engine/tests/vectors/link_status.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (table['cases'] as List).cast<Map<String, dynamic>>();

  const fields = [
    'phase',
    'quality',
    'accessPointId',
    'cellId',
    'regionId',
    'protocol',
    'rttMs',
    'attempt',
    'nextRetryAt',
    'reason',
    'developmentMode',
  ];

  /// The decoded status back as wire values, to compare with `expected` field by field.
  Map<String, Object?> asWire(ConnectionStatus status) => {
        'phase': status.phase.name,
        'quality': status.quality?.name,
        'accessPointId': status.accessPointId,
        'cellId': status.cellId,
        'regionId': status.regionId,
        'protocol': status.protocol,
        'rttMs': status.rttMs,
        'attempt': status.attempt,
        'nextRetryAt': status.nextRetryAt,
        'reason': status.reason,
        'developmentMode': status.developmentMode,
      };

  test('the vectors cover every public phase', () {
    expect(cases.length, greaterThanOrEqualTo(22));
    expect(
      cases.map((vector) => (vector['expected'] as Map)['phase']).toSet(),
      ConnectionPhase.values.map((phase) => phase.name).toSet(),
    );
    for (final vector in cases) {
      expect((vector['expected'] as Map).keys.toSet(), fields.toSet());
    }
  });

  for (final vector in cases) {
    final name = vector['name'] as String;
    final expected = (vector['expected'] as Map).cast<String, Object?>();

    test('decodes $name', () async {
      expect(asWire(connectionStatusFromJson(expected)), expected);

      final bridge = _EventBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      await client.events.subscribeEvents(const {});
      final delivered = <ConnectionStatus>[];
      client.events.onConnectionStatusChanged(delivered.add);

      bridge.emit(
        EventCode.connectionStatus,
        {'type': 'connection', 'event': 'status', ...expected},
      );

      expect(delivered.map(asWire), [expected]);
    });
  }

  test('a phase it does not know is rejected, not guessed', () async {
    final unknown = {
      ...(cases.first['expected'] as Map).cast<String, Object?>(),
      'phase': 'halfOpen',
    };

    expect(
      () => connectionStatusFromJson(unknown),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        'invalid connection phase: halfOpen',
      )),
    );

    final bridge = _EventBridge();
    final client = FlareCoreSdk.createClientWithBridge(bridge);
    await client.events.subscribeEvents(const {});
    final delivered = <ConnectionStatus>[];
    client.events.onConnectionStatusChanged(delivered.add);

    expect(
      () => bridge.emit(EventCode.connectionStatus, unknown),
      throwsA(isA<FormatException>()),
    );
    expect(delivered, isEmpty);
  });
}

/// Hands events to the subscribed handler as the FFI bridge does: decoded JSON maps.
final class _EventBridge implements NativeBridge {
  void Function(int eventType, Object? payload)? _handler;

  void emit(int eventType, Map<String, Object?> payload) {
    final handler = _handler;
    if (handler == null) throw StateError('event handler not subscribed');
    handler(eventType, jsonDecode(jsonEncode(payload)));
  }

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    switch (descriptor.operation) {
      case 'event.subscribe':
      case 'event.subscribe_batch':
        _handler = (request as Map)['handler'] as void Function(int, Object?);
        return {'subscriptionId': 'vectors'} as T;
      default:
        return null as T;
    }
  }
}
