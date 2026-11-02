import 'dart:convert';
import 'dart:io';

import 'package:flare_core_flutter_sdk/src/adapter/codec/wire_codec.dart';
import 'package:flare_core_flutter_sdk/src/model/common/enums/message_content_type.dart';
import 'package:test/test.dart';

void main() {
  group('sdkErrorPayloadFromJson', () {
    test('treats native null sentinels as absent errors', () {
      expect(sdkErrorPayloadFromJson(null), isNull);
      expect(sdkErrorPayloadFromJson('null'), isNull);
      expect(sdkErrorPayloadFromJson('  '), isNull);
      expect(sdkErrorPayloadFromJson(_NativeNullSentinel()), isNull);
    });

    test('normalizes native string errors into SDK payloads', () {
      final error = sdkErrorPayloadFromJson('boom');

      expect(error?.code, 'native_error');
      expect(error?.message, 'boom');
    });
  });

  group('messageFromJson timeline contract', () {
    test('requires message identity and sequence fields', () {
      expect(
        () => messageFromJson(_completeMessage()..remove('clientMsgId')),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Message.clientMsgId is required'),
          ),
        ),
      );

      expect(
        () => messageFromJson(_completeMessage()..remove('conversationId')),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Message.conversationId is required'),
          ),
        ),
      );

      expect(
        () => messageFromJson(_completeMessage({'conversationSeq': '7'})),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Message.conversationSeq must be an unsigned integer'),
          ),
        ),
      );
    });

    test('requires the core timelineKey', () {
      expect(
        () => messageFromJson(_completeMessage()..remove('timelineKey')),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Message.timelineKey is required'),
          ),
        ),
      );
    });

    test('requires the core timelineSortTs', () {
      expect(
        () => messageFromJson(_completeMessage()..remove('timelineSortTs')),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Message.timelineSortTs is required'),
          ),
        ),
      );
    });

    test('parses core-provided timeline fields', () {
      final message = messageFromJson(_completeMessage());

      expect(message.timelineKey, 'c1:7');
      expect(message.timelineSortTs, 1000);
    });

    test('requires message arrays in list and timeline responses', () {
      expect(
        () => listMessagesResponseFromJson({}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'ListMessagesResponse response missing required `messages` array',
          ),
        ),
      );

      expect(
        () => listMessagesResponseFromJson({
          'messages': [null],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'ListMessagesResponse response `messages.0` must be an object',
          ),
        ),
      );

      expect(
        () => conversationTimelineSnapshotFromJson({'messages': 'bad'}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'ConversationTimelineSnapshot response missing required `messages` array',
          ),
        ),
      );
    });

    test('requires explicit canonical message contentType', () {
      expect(
        () => messageFromJson(_completeMessage({
          'content': {'text': 'hello'},
        })),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid message content type: <empty>',
          ),
        ),
      );
      expect(
        () => messageFromJson(_completeMessage({
          'content': {'contentType': 'link-card', 'text': 'hello'},
        })),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid message content type: link-card',
          ),
        ),
      );
    });

    test('defaults optional display fields for local/native partial messages',
        () {
      final message = messageFromJson(_completeMessage()
        ..remove('serverId')
        ..remove('senderName')
        ..remove('senderAvatar')
        ..remove('senderDisplayName')
        ..remove('textPreview'));

      expect(message.serverId, isEmpty);
      expect(message.senderName, isEmpty);
      expect(message.senderAvatar, isEmpty);
      expect(message.senderDisplayName, isEmpty);
      expect(message.textPreview, isEmpty);
    });

    test('requires the projected sender name', () {
      expect(
        () => messageFromJson(_completeMessage()..remove('sender')),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Message.sender is required',
          ),
        ),
      );
    });

    test('requires reaction arrays from core', () {
      expect(
        () => messageFromJson(_completeMessage()..remove('reactions')),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Message response missing required `reactions` array',
          ),
        ),
      );

      expect(
        () => messageFromJson(_completeMessage({
          'reactions': [null],
        })),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Message response `reactions.0` must be an object',
          ),
        ),
      );
    });

    test('defaults missing conversation preview text', () {
      final preview = messagePreviewFromJson({
        'messageId': 'm1',
        'senderId': 'u2',
        'type': 1,
        'time': 1000,
      });

      expect(preview?.text, isEmpty);
    });
  });

  group('viewUpdateFromJson delta contract', () {
    test('decodes shared core delta golden without snapshot fallback', () {
      final update =
          viewUpdateFromJson(_eventGoldenMap('view_update_delta.json'));

      expect(update.kind, 'delta');
      expect(update.revision, 4);
      expect(update.snapshot, isNull);
      expect(update.delta?.viewType, 'timeline');
      expect(update.delta?.append, hasLength(1));
      final message = update.delta!.append!.first;
      expect(message.clientMsgId, 'cm1');
      expect(message.content?.contentType, MessageContentType.text);
      expect(update.delta?.prepend, isEmpty);
      expect(update.delta?.upsert, isEmpty);
      expect(update.delta?.remove, isEmpty);
      expect(update.delta?.reorder, isNull);
      expect(update.delta?.hasOlder, isFalse);
      expect(update.delta?.hasNewer, isFalse);
      expect(update.delta?.attachedToLatest, isTrue);
    });

    test('reads timeline row keys strictly', () {
      final update = viewUpdateFromJson({
        'viewId': 'v1',
        'revision': 2,
        'kind': 'delta',
        'delta': {
          'viewType': 'timeline',
          'remove': ['cm-1'],
          'reorder': ['cm-2', 'cm-3'],
          'hasOlder': false,
          'hasNewer': true,
          'attachedToLatest': false,
        },
      });
      expect(update.delta?.remove, ['cm-1']);
      expect(update.delta?.reorder, ['cm-2', 'cm-3']);
      expect(update.delta?.append, isEmpty);
      expect(update.delta?.hasNewer, isTrue);
      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'delta',
          'delta': {
            'viewType': 'timeline',
            'remove': [1],
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('requires explicit snapshot or delta kind', () {
      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'snapshot': <String, Object?>{},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid view update kind: <empty>',
          ),
        ),
      );
      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'replace',
          'snapshot': <String, Object?>{},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid view update kind: replace',
          ),
        ),
      );
    });

    test('requires conversation-list delta ops as an object array', () {
      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'delta',
          'delta': {'viewType': 'conversationList'},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'ViewDelta response missing required `ops` array',
          ),
        ),
      );

      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'delta',
          'delta': {
            'viewType': 'conversationList',
            'ops': [null],
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'ViewDelta response `ops.0` must be an object',
          ),
        ),
      );
    });

    test('requires strict view identity, type, and delta op fields', () {
      expect(
        () => viewUpdateFromJson({
          'revision': 2,
          'kind': 'delta',
          'delta': {'viewType': 'conversationList', 'ops': <Object?>[]},
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('ViewUpdate.viewId is required'),
          ),
        ),
      );

      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'delta',
          'delta': {'viewType': 'feed', 'ops': <Object?>[]},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid view type: feed',
          ),
        ),
      );

      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'delta',
          'delta': {
            'viewType': 'conversationList',
            'ops': [
              {'op': 'append', 'key': 'k1', 'index': 0},
            ],
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid view delta op: append',
          ),
        ),
      );

      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'delta',
          'delta': {
            'viewType': 'conversationList',
            'ops': [
              {'op': 'insert', 'index': 0},
            ],
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('ViewDeltaOp.key is required'),
          ),
        ),
      );

      expect(
        () => viewUpdateFromJson({
          'viewId': 'v1',
          'revision': 2,
          'kind': 'delta',
          'delta': {
            'viewType': 'conversationList',
            'ops': [
              {'op': 'insert', 'key': 'k1', 'index': '0'},
            ],
          },
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('ViewDeltaOp.index must be an unsigned integer'),
          ),
        ),
      );
    });
  });

  group('sendAckFromJson and sync version contract', () {
    test('requires send ack identity and sequence fields', () {
      expect(
        () => sendAckFromJson({
          'success': true,
          'serverId': 's1',
          'clientMsgId': 'cm1',
          'conversationId': 'c1',
          'seq': 1,
          'timestamp': 1000,
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('SendMessageResponse.ackId is required'),
          ),
        ),
      );

      expect(
        () => sendAckFromJson({
          'success': true,
          'ackId': 'ack1',
          'serverId': 's1',
          'clientMsgId': 'cm1',
          'conversationId': 'c1',
          'seq': '1',
          'timestamp': 1000,
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('SendMessageResponse.seq must be an unsigned integer'),
          ),
        ),
      );
    });

    test('decodes failed send ack payloads without accepted ack fields', () {
      final ack = sendAckFromJson({
        'success': false,
        'clientMsgId': 'cm1',
        'reason': 'timeout',
      });

      expect(ack.success, isFalse);
      expect(ack.clientMsgId, 'cm1');
      expect(ack.serverId, isEmpty);
      expect(ack.seq, 0);
      expect(ack.errorCode, 0);
    });

    test('requires conversation version identity fields', () {
      expect(
        () => conversationVersionFromJson({'version': 1}),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('ConversationVersion.conversationId is required'),
          ),
        ),
      );

      expect(
        () => conversationVersionFromJson({
          'conversationId': 'c1',
          'version': '1',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('ConversationVersion.version must be an unsigned integer'),
          ),
        ),
      );

      expect(
        () => syncConversationSummariesResponseFromJson({
          'changedConversations': [null],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'SyncConversationSummariesResponse response `changedConversations.0` must be an object',
          ),
        ),
      );
    });
  });
}

final class _NativeNullSentinel {
  @override
  String toString() => 'null';
}

Map<String, Object?> _completeMessage(
    [Map<String, Object?> overrides = const {}]) {
  return {
    'serverId': 'server-msg-1',
    'clientMsgId': 'cm1',
    'conversationId': 'c1',
    'conversationType': 1,
    'channelId': 'u2',
    'senderId': 'u2',
    'source': 0,
    'conversationSeq': 7,
    'createdAt': 1000,
    'clientCreatedAt': 999,
    'messageType': 0,
    'content': {
      'contentType': 'text',
      'text': 'hello',
      'mentions': <Object?>[],
    },
    'senderName': 'User Two',
    'senderAvatar': 'https://example.com/u2.png',
    'senderDisplayName': 'User Two',
    'sender': {'kind': 'named', 'text': 'User Two', 'source': 'snapshot'},
    'status': 2,
    'isRead': false,
    'isRecalled': false,
    'isEdited': false,
    'mentionUsers': <String>[],
    'mentionAll': false,
    'attributes': <String, String>{},
    'extensions': <String, Object?>{},
    'reactions': <Object?>[],
    'textPreview': 'hello',
    'version': 1,
    'updatedAt': 1000,
    'timelineKey': 'c1:7',
    'timelineSortTs': 1000,
    ...overrides,
  };
}

Map<String, Object?> _eventGoldenMap(String name) {
  final file = File('../../sdk-spec/golden/events/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}
