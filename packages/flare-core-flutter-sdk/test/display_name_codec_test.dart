import 'dart:convert';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flare_core_flutter_sdk/src/adapter/codec/wire_codec.dart';
import 'package:test/test.dart';

void main() {
  group('displayNameFromJson', () {
    test('decodes every projected name in display-name-projection.json', () {
      for (final vector in _projectedNames()) {
        final expected = vector['expected'] as Map<String, Object?>;
        expect(
          _wire(displayNameFromJson(expected)),
          expected,
          reason: vector['name'] as String,
        );
      }
    });

    test('reads title, lastSender, sender and participant names', () {
      for (final vector in _projectedNames()) {
        final expected = vector['expected'] as Map<String, Object?>;
        final reason = vector['name'] as String;
        final conversation = conversationFromJson({
          ..._golden('responses/conversation_get_one.json'),
          'title': expected,
          'lastSender': expected,
          'memberPreview': [_participant('u2', expected)],
          'participants': [_participant('u3', expected)],
        });
        expect(_wire(conversation.title), expected, reason: reason);
        expect(_wire(conversation.lastSender), expected, reason: reason);
        expect(_wire(conversation.memberPreview.single.name), expected,
            reason: reason);
        expect(_wire(conversation.participants.single.name), expected,
            reason: reason);

        final message = messageFromJson({
          ..._golden('responses/build_thread_reply_message.json'),
          'sender': expected,
        });
        expect(_wire(message.sender), expected, reason: reason);
      }
    });

    test(
        'requires the names every value carries and leaves lastSender out '
        'without a latest message', () {
      final isRequired = (String field) => throwsA(isA<ArgumentError>()
          .having((error) => error.message, 'message', '$field is required'));
      expect(
        () => conversationFromJson(
            _golden('responses/conversation_get_one.json')..remove('title')),
        isRequired('Conversation.title'),
      );
      final conversation =
          conversationFromJson(_golden('responses/conversation_get_one.json'));
      expect(_wire(conversation.title),
          {'kind': 'named', 'text': 'User Two', 'source': 'profile'});
      expect(conversation.lastSender, isNull);

      expect(
        () => messageFromJson(
            _golden('responses/build_thread_reply_message.json')
              ..remove('sender')),
        isRequired('Message.sender'),
      );
      expect(
        () => conversationParticipantFromJson(_participant('u2')),
        isRequired('ConversationParticipant.name'),
      );
      expect(displayNameFromJson(null), isNull);
    });

    test('reads a kind it does not know as an unnamed person without id tail',
        () {
      expect(_wire(displayNameFromJson({'kind': 'nickname', 'text': 'Alice'})),
          _unknownPerson);
      expect(_wire(displayNameFromJson({'text': 'Alice'})), _unknownPerson);
      final conversation = conversationFromJson({
        ..._golden('responses/conversation_get_one.json'),
        'title': {'kind': 'emoji', 'value': ':)'},
      });
      expect(_wire(conversation.title), _unknownPerson);
    });

    test('reads an entity it does not know as a person and keeps the id tail',
        () {
      expect(
        _wire(displayNameFromJson(
            {'kind': 'unnamed', 'entity': 'robot', 'idTail': '9876'})),
        {'kind': 'unnamed', 'entity': 'person', 'idTail': '9876'},
      );
      expect(_wire(displayNameFromJson({'kind': 'unnamed'})), _unknownPerson);
      final message = messageFromJson({
        ..._golden('responses/build_thread_reply_message.json'),
        'sender': {'kind': 'unnamed', 'entity': 'bot', 'idTail': '0401'},
      });
      expect(_wire(message.sender),
          {'kind': 'unnamed', 'entity': 'person', 'idTail': '0401'});
    });

    test('reads malformed names without failing the value that carries them',
        () {
      expect(_wire(displayNameFromJson('Alice')), _unknownPerson);
      expect(_wire(displayNameFromJson(['Alice'])), _unknownPerson);
      expect(_wire(displayNameFromJson({'kind': 'named'})), _unknownPerson);
      expect(
        _wire(displayNameFromJson(
            {'kind': 'named', 'text': 'Alice', 'source': 'nickname'})),
        {'kind': 'named', 'text': 'Alice'},
      );
      expect(
        _wire(displayNameFromJson({
          'kind': 'members',
          'names': ['Ann', 3, 'Ben'],
          'total': 4.7,
        })),
        {
          'kind': 'members',
          'names': ['Ann', 'Ben'],
          'total': 4,
        },
      );
      expect(
        _wire(displayNameFromJson({'kind': 'members', 'total': -1})),
        {'kind': 'members', 'names': <String>[], 'total': 0},
      );
      expect(
        _wire(displayNameFromJson(
            {'kind': 'unnamed', 'entity': 'group', 'idTail': 12})),
        {'kind': 'unnamed', 'entity': 'group', 'idTail': ''},
      );
    });
  });

  group('send failed error', () {
    test('decodes the server rejection golden with its typed reason', () {
      final golden = _golden('events/send_failed_with_error.json');
      final error = sdkErrorPayloadFromJson(golden['error']);
      expect(_errorWire(error), golden['error']);
      expect(error?.machineReason, 'SOCIAL_CARD_SCOPE_FRIENDS');
    });

    test('delivers the golden through the event decoder', () async {
      final bridge = _EventBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final failed = <MessageSendFailedEvent>[];
      client.events.onMessageSendFailed(failed.add);
      await client.events.subscribeEvents(const {});

      final golden = _golden('events/send_failed_with_error.json');
      bridge.emit(EventCode.messageSendFailed, golden);

      expect(failed, hasLength(1));
      expect(failed.single.clientMsgId, golden['clientMsgId']);
      expect(failed.single.reason, golden['reason']);
      expect(_errorWire(failed.single.error), golden['error']);
    });

    test('reads the empty typed reason of a local failure as no reason', () {
      final error = sdkErrorPayloadFromJson({
        'code': 'OPERATION_TIMEOUT',
        'machineReason': '',
        'message': 'send timed out',
        'operation': 'message.send',
        'retryable': false,
        'details': <String, Object?>{},
      });
      expect(error?.code, 'OPERATION_TIMEOUT');
      expect(error?.machineReason, isNull);
      expect(
        () => sdkErrorPayloadFromJson({
          'code': 'OPERATION_TIMEOUT',
          'machineReason': 21,
          'message': 'send timed out',
        }),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          'invalid SDK error payload field: error.machineReason',
        )),
      );
    });
  });
}

const Map<String, Object?> _unknownPerson = {
  'kind': 'unnamed',
  'entity': 'person',
  'idTail': '',
};

List<Map<String, Object?>> _projectedNames() {
  final vectors = _golden('display-name-projection.json');
  final cases = [
    ...(vectors['people'] as List).cast<Map<String, Object?>>(),
    ...(vectors['conversations'] as List).cast<Map<String, Object?>>(),
  ];
  expect(cases, isNotEmpty);
  return cases;
}

Map<String, Object?> _golden(String relative) {
  final file = File('../../sdk-spec/golden/$relative');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Map<String, Object?> _participant(String userId, [Object? name]) => {
      'userId': userId,
      'roles': <String>[],
      'muted': false,
      'pinned': false,
      'attributes': <String, String>{},
      'joinedAt': 0,
      'nickname': '',
      if (name != null) 'name': name,
    };

/// The wire form of a decoded name, the fields it carries and nothing else.
Map<String, Object?>? _wire(DisplayName? name) {
  if (name == null) return null;
  return {
    'kind': name.kind.name,
    if (name.text != null) 'text': name.text,
    if (name.source != null) 'source': name.source!.name,
    if (name.names != null) 'names': name.names,
    if (name.total != null) 'total': name.total,
    if (name.entity != null) 'entity': name.entity!.name,
    if (name.idTail != null) 'idTail': name.idTail,
  };
}

Map<String, Object?>? _errorWire(SdkErrorPayload? error) {
  if (error == null) return null;
  return {
    'code': error.code,
    if (error.machineReason != null) 'machineReason': error.machineReason,
    'message': error.message,
    if (error.operation != null) 'operation': error.operation,
    if (error.retryable != null) 'retryable': error.retryable,
    'details': error.details,
  };
}

/// A bridge that accepts the event subscription and keeps the handler the SDK
/// registers, so a test can hand it native events.
final class _EventBridge implements NativeBridge {
  void Function(int eventType, Object? payload)? _handler;

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    switch (descriptor.operation) {
      case 'event.subscribe':
        _handler = (request as Map)['handler'] as void Function(int, Object?);
        return {'subscriptionId': 'test-subscription'} as T;
      case 'event.subscribe_batch':
        _handler = (request as Map)['handler'] as void Function(int, Object?);
        return {'subscription': 7, 'context': 8} as T;
      default:
        throw UnimplementedError(descriptor.operation);
    }
  }

  void emit(int eventType, Map<String, Object?> payload) {
    final handler = _handler;
    if (handler == null) throw StateError('event handler not subscribed');
    handler(eventType, payload);
  }
}
