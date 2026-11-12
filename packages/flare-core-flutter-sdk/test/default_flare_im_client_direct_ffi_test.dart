import 'dart:convert';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultFlareImClient direct FFI request shape', () {
    test('plugin UI catalog dispatches through the Rust capability API',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final request = {'pluginId': 'red-packet'};

      final response = await client.capabilities.pluginUiCatalog(request);

      expect(bridge.lastOperation, 'capability.plugin_ui_catalog');
      expect(bridge.lastTransport, 'capability-dispatch-json');
      expect(bridge.lastCApi, 'flare_capability_dispatch_json');
      expect(bridge.lastRequest, request);
      expect(response, {'items': <Object>[]});
    });

    test('plugin UI actions and message resolution use typed payload envelope',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      const request = PluginUiEvaluationRequest(payload: {'messageId': 'm1'});

      await client.capabilities.presentPluginMessage(request);
      expect(bridge.lastOperation, 'capability.plugin_ui_present');
      expect(bridge.lastTransport, 'capability-dispatch-json');
      expect(bridge.lastCApi, 'flare_capability_dispatch_json');
      expect(bridge.lastRequest, {
        'payload': {'messageId': 'm1'}
      });
      await client.capabilities.invokePluginAction(request);
      expect(bridge.lastOperation, 'capability.plugin_ui_invoke');
      expect(bridge.lastTransport, 'capability-dispatch-json');
      expect(bridge.lastCApi, 'flare_capability_dispatch_json');
      expect(bridge.lastRequest, {
        'payload': {'messageId': 'm1'}
      });

      await client.capabilities.pluginUiAction(request);
      expect(bridge.lastOperation, 'capability.plugin_ui_action');
      expect(bridge.lastRequest, {
        'payload': {'messageId': 'm1'}
      });

      await client.capabilities.resolvePluginMessage(request);
      expect(bridge.lastOperation, 'capability.plugin_ui_resolve');
      expect(bridge.lastRequest, {
        'payload': {'messageId': 'm1'}
      });

      await client.capabilities.pluginDetail(request);
      expect(bridge.lastOperation, 'capability.plugin_detail');
      expect(bridge.lastTransport, 'capability-dispatch-json');
      expect(bridge.lastCApi, 'flare_capability_dispatch_json');
      expect(bridge.lastRequest, {
        'payload': {'messageId': 'm1'}
      });
    });

    test(
        'plugin file upload forwards the typed envelope and completed reference',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      const request = PluginUiEvaluationRequest(payload: {
        'page': {'pluginId': 'example.plugin', 'page': 'example.plugin.form'},
        'inputId': 'attachment',
        'platform': 'flutter',
        'commandId': 'upload-1',
        'fileName': 'receipt.png',
        'contentType': 'image/png',
        'bytes': [137, 255],
      });
      final result = await client.capabilities.pluginFileUpload(request);
      expect(bridge.lastOperation, 'capability.plugin_file_upload');
      expect(bridge.lastTransport, 'capability-dispatch-json');
      expect(bridge.lastCApi, 'flare_capability_dispatch_json');
      expect(bridge.lastRequest, {'payload': request.payload});
      expect(result, {'fileId': 'file:fixture'});
    });

    test('createTextMessage uses platform camelCase fields', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final message = await client.messages.createTextMessage(
        const CreateTextMessageRequest(conversationId: 'c1', text: 'hello'),
      );

      expect(bridge.lastOperation, 'message.create_text');
      expect(bridge.lastRequest, {
        'conversationId': 'c1',
        'text': 'hello',
      });
      expect(message.serverId, 'm1');
      expect(message.clientMsgId, 'cm1');
      expect(message.conversationId, 'c1');
      expect(message.channelId, 'ch1');
      expect(message.senderId, 'u1');
      expect(message.conversationSeq, 7);
      expect(message.createdAt, 1000);
      expect(message.clientCreatedAt, 900);
      expect(message.content?.data['text'], 'hello');
      expect(message.mentionUsers, ['u2']);
      expect(message.attributes, {'scope': 'test'});
      expect(message.localState?.isLocal, isTrue);
    });

    test('messageBuilder.buildText sends default mention fields', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.messageBuilder.buildText(
        const BuildTextMessageRequest(conversationId: 'c1', text: 'hello'),
      );

      expect(bridge.lastOperation, 'message_builder.dispatch');
      expect(bridge.lastRequest, {
        'op': 'create_text',
        'conversationId': 'c1',
        'text': 'hello',
        'mentionUsers': <String>[],
        'mentionAll': false,
      });
    });

    test('message contentType follows core string contract only', () async {
      final bridge = _RecordingBridge(
        createTextResponse: {
          ..._messageResponse(),
          'content': {
            'contentType': 0,
            'text': 'hello',
          },
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await expectLater(
        client.messages.createTextMessage(
          const CreateTextMessageRequest(conversationId: 'c1', text: 'hello'),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid message content type: 0',
          ),
        ),
      );
    });

    test('sendMessage serializes content as Rust IMMessage elem JSON',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final ack = await client.messages.sendMessage(
        const SendMessageRequest(
          message: Message(
            clientMsgId: 'cm1',
            conversationId: 'c1',
            conversationType: 1,
            channelId: 'ch1',
            senderId: 'u1',
            source: 2,
            createdAt: 1000,
            clientCreatedAt: 1000,
            messageType: 1,
            content: MessageContent(
              contentType: MessageContentType.text,
              data: {'text': 'hello'},
            ),
            sender: DisplayName(
              kind: DisplayNameKind.unnamed,
              entity: NameEntity.person,
              idTail: 'u1',
            ),
          ),
        ),
      );

      expect(bridge.lastOperation, 'message.send');
      final request = bridge.lastRequest as Map<String, Object?>;
      final message = request['message'] as Map<String, Object?>;
      expect(message['conversationSeq'], 0);
      expect(message['createdAt'], 1000);
      expect(message['clientCreatedAt'], 1000);
      expect(message['attributes'], <String, Object?>{});
      expect(message.containsKey('conversation_seq'), isFalse);
      expect(message.containsKey('created_at'), isFalse);
      expect(message.containsKey('client_created_at'), isFalse);
      expect(message.containsKey('extra'), isFalse);
      expect(message.containsKey('sender'), isFalse,
          reason: 'the sender name is projected when read, never sent back');
      expect(message['content'], {
        'contentType': 'text',
        'text': 'hello',
        'mentions': <Object?>[],
      });
      expect(ack.clientMsgId, 'cm1');
    });

    test('listMessages uses platform camelCase fields', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.messages.listMessages(
        const ListMessagesRequest(
          conversationId: 'c1',
          beforeSeq: 42,
          limit: 20,
        ),
      );

      expect(bridge.lastOperation, 'message.list');
      expect(bridge.lastRequest, {
        'conversationId': 'c1',
        'beforeSeq': 42,
        'limit': 20,
      });
    });

    test('setTyping forwards the public platform shape unchanged', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.messages.setTyping({
        'conversationId': 'c1',
        'isTyping': true,
      });

      expect(bridge.lastOperation, 'message.typing');
      expect(bridge.lastRequest, {
        'conversationId': 'c1',
        'isTyping': true,
      });
    });

    test('getOneConversation decodes string conversationType from Rust JSON',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final conversation = await client.conversations.getOneConversation({
        'sourceId': 'u2',
        'conversationType': 'single',
      });

      expect(bridge.lastOperation, 'conversation.get_one');
      expect(bridge.lastRequest, {
        'sourceId': 'u2',
        'conversationType': 'single',
      });
      expect(conversation.conversationId, 'single-u2');
      expect(conversation.conversationType, ConversationType.single);
      expect(conversation.displayName, 'User Two');
    });

    test('getOneConversation accepts empty local display asset fields',
        () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          ..._goldenMap('conversation_get_one.json'),
          'avatarUrl': '',
          'lastSenderNickname': '',
          'lastSenderAvatarUrl': '',
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final conversation = await client.conversations.getOneConversation({
        'sourceId': 'u2',
        'conversationType': 'single',
      });

      expect(conversation.conversationId, 'single-u2');
      expect(conversation.avatarUrl, '');
      expect(conversation.lastSenderNickname, '');
      expect(conversation.lastSenderAvatarUrl, '');
    });

    test('getOneConversation accepts empty local businessType', () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          ..._goldenMap('conversation_get_one.json'),
          'businessType': '',
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final conversation = await client.conversations.getOneConversation({
        'sourceId': 'u2',
        'conversationType': 'single',
      });

      expect(conversation.conversationId, 'single-u2');
      expect(conversation.businessType, '');
    });

    test('getOneConversation accepts empty local displayName', () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          ..._goldenMap('conversation_get_one.json'),
          'displayName': '',
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final conversation = await client.conversations.getOneConversation({
        'sourceId': 'u2',
        'conversationType': 'single',
      });

      expect(conversation.conversationId, 'single-u2');
      expect(conversation.displayName, '');
    });

    test('getOneConversation does not decode legacy numeric conversationType',
        () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          ..._goldenMap('conversation_get_one.json'),
          'conversationType': 1,
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await expectLater(
        client.conversations.getOneConversation({
          'sourceId': 'u2',
          'conversationType': 'single',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid conversation type: 1',
          ),
        ),
      );
    });

    test('getOneConversation rejects SDK response without conversationId',
        () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          'conversationType': 'single',
          'channelId': 'u2',
          'displayName': 'User Two',
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await expectLater(
        () => client.conversations.getOneConversation({
          'sourceId': 'u2',
          'conversationType': 'single',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('conversationId'),
          ),
        ),
      );
    });

    test('getOneConversation unwraps conversation envelope', () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          'conversation': _goldenMap('conversation_get_one.json'),
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final conversation = await client.conversations.getOneConversation({
        'sourceId': 'u2',
        'conversationType': 'single',
      });

      expect(conversation.conversationId, 'single-u2');
      expect(conversation.conversationType, ConversationType.single);
    });

    test('getOneConversation unwraps value envelope', () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          'value': _goldenMap('conversation_get_one.json'),
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final conversation = await client.conversations.getOneConversation({
        'sourceId': 'u2',
        'conversationType': 'single',
      });

      expect(conversation.conversationId, 'single-u2');
      expect(conversation.conversationType, ConversationType.single);
    });

    test('getOneConversation unwraps conversations envelope', () async {
      final bridge = _RecordingBridge(
        getOneResponse: {
          'conversations': [_goldenMap('conversation_get_one.json')],
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final conversation = await client.conversations.getOneConversation({
        'sourceId': 'u2',
        'conversationType': 'single',
      });

      expect(conversation.conversationId, 'single-u2');
      expect(conversation.conversationType, ConversationType.single);
    });

    test('bootstrapHomeTimeline decodes string syncState from Rust JSON',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final snapshot = await client.conversations.bootstrapHomeTimeline(
        const BootstrapHomeTimelineRequest(conversationLimit: 20),
      );

      expect(bridge.lastOperation, 'conversation.bootstrap_home');
      expect(bridge.lastRequest, {'conversationLimit': 20});
      expect(snapshot.syncState, TimelineSyncState.synced);
      expect(snapshot.conversations.single.conversationType,
          ConversationType.group);
    });

    test('bootstrapHomeTimeline does not decode legacy numeric syncState',
        () async {
      final bridge = _RecordingBridge(
        bootstrapResponse: {
          ..._goldenMap('home_timeline_snapshot.json'),
          'syncState': 1,
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await expectLater(
        client.conversations.bootstrapHomeTimeline(
          const BootstrapHomeTimelineRequest(conversationLimit: 20),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid timeline sync state: 1',
          ),
        ),
      );
    });

    test('bootstrapHomeTimeline rejects invalid conversations', () async {
      final bridge = _RecordingBridge(
        bootstrapResponse: {
          'conversations': [
            {'conversationType': 'single', 'displayName': 'Bad'},
            {..._goldenMap('conversation_get_one.json'), 'unreadCount': 3},
          ],
          'totalUnread': 99,
          'syncState': 'synced',
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await expectLater(
        client.conversations.bootstrapHomeTimeline(
          const BootstrapHomeTimelineRequest(conversationLimit: 20),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('conversationId'),
          ),
        ),
      );
    });

    test('listConversationsByQuery encodes conversationTypes as strings',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.conversations.listConversationsByQuery(
        const ConversationListQuery(
          conversationTypes: [ConversationType.single, ConversationType.group],
          unreadOnly: true,
          limit: 20,
        ),
      );

      expect(bridge.lastOperation, 'conversation.list_by_query');
      expect(bridge.lastRequest, {
        'includeArchived': false,
        'unreadOnly': true,
        'mentionMeOnly': false,
        'pinnedOnly': false,
        'hasDraftOnly': false,
        'hasMarkedMessages': false,
        'conversationTypes': ['single', 'group'],
        'limit': 20,
      });
    });

    test('listConversationsByQuery accepts empty local businessType', () async {
      final bridge = _RecordingBridge(
        listResponse: {
          'conversations': [
            {
              ..._goldenMap('conversation_get_one.json'),
              'businessType': '',
            },
          ],
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final response = await client.conversations.listConversationsByQuery(
        const ConversationListQuery(mentionMeOnly: true),
      );

      expect(bridge.lastOperation, 'conversation.list_by_query');
      expect(response.conversations.single.conversationId, 'single-u2');
      expect(response.conversations.single.businessType, '');
    });

    test('listConversationsByQuery accepts empty local displayName', () async {
      final bridge = _RecordingBridge(
        listResponse: {
          'conversations': [
            {
              ..._goldenMap('conversation_get_one.json'),
              'displayName': '',
            },
          ],
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final response = await client.conversations.listConversationsByQuery(
        const ConversationListQuery(mentionMeOnly: true),
      );

      expect(bridge.lastOperation, 'conversation.list_by_query');
      expect(response.conversations.single.conversationId, 'single-u2');
      expect(response.conversations.single.displayName, '');
    });

    test('listConversations uses unified contract invoke transport', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final response = await client.conversations.listConversations();

      expect(bridge.lastOperation, 'conversation.list');
      expect(bridge.lastTransport, 'contract-invoke-json');
      expect(bridge.lastCApi, 'flare_sdk_invoke_json');
      expect(response.conversations.single.conversationId, 'single-u2');
      expect(response.conversations.single.displayName, 'User Two');
    });

    test('listConversations rejects invalid conversations', () async {
      final bridge = _RecordingBridge(
        listResponse: {
          'conversations': [
            {'conversationType': 'single', 'displayName': 'Bad'},
            _goldenMap('conversation_get_one.json'),
          ],
        },
      );
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await expectLater(
        client.conversations.listConversations(),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('conversationId'),
          ),
        ),
      );
    });

    test('plugin card state change is delivered as a message update', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final changed = <MessageMutationEvent>[];
      final edited = <MessageMutationEvent>[];
      client.events.onMessagePluginStateChanged(changed.add);
      client.events.onMessageEdited(edited.add);

      await client.events.subscribeEvents(const {});
      bridge.emitEvent(EventCode.messagePluginStateChanged, {
        'type': 'message',
        'event': 'plugin_state_changed',
        'conversationId': 'c1',
        'messageId': 'm1',
        'version': 3,
      });

      expect(changed, hasLength(1));
      expect(changed.single.name, MessageEventName.pluginStateChanged);
      expect(changed.single.conversationId, 'c1');
      expect(changed.single.messageId, 'm1');
      expect(edited, isEmpty);
    });

    test('plugin realtime and catalog events reach their typed listeners',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final realtime = <PluginRealtimeEvent>[];
      final catalog = <PluginCatalogChangedEvent>[];
      client.events.onPluginRealtime(realtime.add);
      client.events.onPluginCatalogChanged(catalog.add);

      await client.events.subscribeEvents(const {});
      bridge.emitEvent(EventCode.pluginRealtime, {
        'pluginId': 'flare.call',
        'packetType': 'call.snapshot',
        'conversationId': 'c1',
        'payload': {'callId': 'call-1', 'version': 3},
        'deliveryId': 'd1',
        'expiresAtMs': 1730000060000,
      });
      bridge.emitEvent(EventCode.pluginCatalogChanged, {'version': '42'});

      expect(realtime, hasLength(1));
      expect(realtime.single.pluginId, 'flare.call');
      expect(realtime.single.packetType, 'call.snapshot');
      expect(realtime.single.conversationId, 'c1');
      expect(realtime.single.payload, {'callId': 'call-1', 'version': 3});
      expect(realtime.single.deliveryId, 'd1');
      expect(realtime.single.expiresAtMs, 1730000060000);
      expect(catalog.single.version, '42');
      expect(
        () => bridge.emitEvent(EventCode.pluginRealtime, {
          'pluginId': 'flare.call',
          'packetType': 'call.snapshot',
          'conversationId': 'c1',
          'payload': [1, 2],
          'deliveryId': 'd1',
          'expiresAtMs': 1730000060000,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid event payload field: payload',
          ),
        ),
      );
    });

    test('notification present, clear and badge reach their typed listeners',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final presented = <NotificationPresentation>[];
      final cleared = <NotificationClearEvent>[];
      final badges = <NotificationBadgeEvent>[];
      client.events.onNotificationPresent(presented.add);
      client.events.onNotificationClear(cleared.add);
      client.events.onNotificationBadge(badges.add);

      await client.events.subscribeEvents(const {});
      bridge.emitEvent(EventCode.notificationPresent, {
        'collapseId': 'c:1',
        'threadId': 'c:1',
        'conversationId': '',
        'messageId': '',
        'seq': 0,
        'title': 'Flare',
        'body': '3 conversations',
        'count': 3,
        'sound': false,
        'channel': 'messages',
        'surface': 'system',
      });
      bridge.emitEvent(EventCode.notificationClear, {
        'collapseIds': ['c:1'],
        'all': false,
      });
      bridge.emitEvent(EventCode.notificationBadge, {'count': 7});

      expect(presented.single.collapseId, 'c:1');
      expect(presented.single.conversationId, isEmpty,
          reason: 'the digest belongs to no conversation');
      expect(presented.single.surface, 'system');
      expect(cleared.single.collapseIds, ['c:1']);
      expect(cleared.single.all, isFalse);
      expect(badges.single.count, 7);
    });

    test('read receipt event rejects malformed payloads', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final receipts = <ReadReceiptEvent>[];
      client.events.onMessageReadReceipt(receipts.add);

      await client.events.subscribeEvents(const {});

      expect(
        () => bridge.emitEvent(EventCode.messageReadReceipt, {
          'type': 'message',
          'event': 'read_receipt',
          'conversationId': 'c1',
          'userId': 'u2',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid event payload field: readSeq',
          ),
        ),
      );
      expect(
        () => bridge.emitEvent(EventCode.messageReadReceipt, {
          'type': 'message',
          'event': 'read_receipt',
          'conversationId': 'c1',
          'userId': 'u2',
          'readSeq': 0,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid event payload field: readSeq',
          ),
        ),
      );
      expect(
        () => bridge.emitEvent(EventCode.messageReadReceipt, {
          'type': 'message',
          'event': 'read_receipt',
          'conversationId': 'c1',
          'userId': 'u2',
          'readSeq': '42',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid event payload field: readSeq',
          ),
        ),
      );
      bridge.emitEvent(EventCode.messageReadReceipt, {
        'type': 'message',
        'event': 'read_receipt',
        'conversationId': 'c1',
        'userId': 'u2',
        'readSeq': 42,
      });

      expect(receipts, hasLength(1));
      expect(receipts.single.conversationId, 'c1');
      expect(receipts.single.userId, 'u2');
      expect(receipts.single.readSeq, 42);
    });

    test('event decoder rejects malformed batch and typing payloads', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.events.subscribeEventsBatch(const {});

      expect(
        () => bridge.emitEvent(EventCode.messageReceivedBatch, const {}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid event payload field: messages',
          ),
        ),
      );

      expect(
        () => bridge.emitEvent(EventCode.messageTyping, {
          'conversationId': 'c1',
          'userId': 'u2',
          'typing': 'true',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid event payload field: typing',
          ),
        ),
      );
    });

    test('event decoder accepts wrapped and direct received payloads',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final messages = <MessageReceivedEvent>[];
      client.events.onMessageReceived(messages.add);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.messageReceived, {
        'message': _messageResponse(),
      });
      bridge.emitEvent(EventCode.messageReceived, _messageResponse());

      expect(messages, hasLength(2));
      expect(messages.map((event) => event.message.serverId), ['m1', 'm1']);
      expect(messages.every((event) => event.message.conversationId == 'c1'),
          isTrue);
    });

    test('event decoder accepts SDK error payloads', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final failed = <MessageSendFailedEvent>[];
      client.events.onMessageSendFailed(failed.add);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.messageSendFailed, {
        'clientMsgId': 'cm1',
        'reason': 'timeout',
        'error': {
          'code': 'timeout',
          'message': 'send timed out',
          'operation': 'message.send',
          'retryable': true,
          'details': {'phase': 'flush'},
        },
      });

      expect(failed, hasLength(1));
      expect(failed.single.error?.code, 'timeout');
      expect(failed.single.error?.message, 'send timed out');
      expect(failed.single.error?.details, {'phase': 'flush'});

      expect(
        () => bridge.emitEvent(EventCode.messageSendFailed, {
          'clientMsgId': 'cm1',
          'reason': 'timeout',
          'error': {'code': 'timeout'},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid SDK error payload field: error.message',
          ),
        ),
      );

      bridge.emitEvent(EventCode.messageSendFailed, {
        'clientMsgId': 'cm1',
        'reason': 'timeout',
        'error': 'timeout',
      });

      expect(failed, hasLength(2));
      expect(failed.last.error?.code, 'native_error');
      expect(failed.last.error?.message, 'timeout');

      expect(
        () => bridge.emitEvent(EventCode.messageSendFailed, {
          'clientMsgId': 'cm1',
          'reason': 'timeout',
          'error': {
            'code': 'timeout',
            'message': 'send timed out',
            'details': {'retryAfter': 3},
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid SDK error payload field: error.details.retryAfter',
          ),
        ),
      );
    });

    test('sync decoder ignores error placeholders on non-failed events',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final started = <SyncEvent>[];
      client.events.onSyncServerStart(started.add);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.syncStarted, {
        'trigger': null,
        'phase': null,
        'task': null,
        'progress': null,
        'error': 'timeout',
      });

      expect(started, hasLength(1));
      expect(started.single.error, isNull);
    });

    test('event decoder accepts nested and flat send ack payloads', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final acks = <MessageSendAckEvent>[];
      client.events.onMessageSendAck(acks.add);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.messageSendAck, {
        'ack': {
          'ackId': 'ack1',
          'serverId': 's1',
          'clientMsgId': 'cm1',
          'conversationId': 'c1',
          'seq': 1,
          'timestamp': 1000,
          'success': true,
        },
      });
      bridge.emitEvent(EventCode.messageSendAck, {
        'success': false,
        'clientMsgId': 'cm2',
        'reason': 'timeout',
      });

      expect(acks, hasLength(2));
      expect(acks.first.ack.serverId, 's1');
      expect(acks.last.ack.success, isFalse);
      expect(acks.last.ack.clientMsgId, 'cm2');
    });

    test('event decoder dispatches typing aggregate callbacks', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final typed = <TypingAggregateEvent>[];
      final objectListener = _TypingAggregateListener();
      client.events.onTypingAggregateChanged(typed.add);
      client.events.addEventListener(objectListener);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.messageTypingAggregate, {
        'conversationId': 'group-100',
        'typingUserIds': ['user-a', 'user-b'],
        'typingCount': 2,
      });

      expect(typed, hasLength(1));
      expect(typed.single.conversationId, 'group-100');
      expect(typed.single.typingUserIds, ['user-a', 'user-b']);
      expect(typed.single.typingCount, 2);
      expect(objectListener.latest?.conversationId, 'group-100');
      expect(objectListener.latest?.typingCount, 2);
    });

    test('event decoder keeps unknown native event codes forward-compatible',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.events.subscribeEvents(const {});

      expect(() => bridge.emitEvent(999999, {'value': 1}), returnsNormally);
    });

    test('event fan-out isolates listener failures', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final statuses = <ConnectionStatus>[];

      client.events
          .onConnectionStatusChanged((_) => throw StateError('listener broke'));
      client.events.onConnectionStatusChanged(statuses.add);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.connectionStatus, _statusPayload('online'));

      expect(statuses, hasLength(1));
      expect(statuses.single.phase, ConnectionPhase.online);
    });

    test('connection status decodes every field and replaces the held copy',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final statuses = <ConnectionStatus>[];
      final objectListener = _ConnectionListener();
      client.events.onConnectionStatusChanged(statuses.add);
      client.events.addEventListener(objectListener);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.connectionStatus, {
        // The C ABI adds its own envelope keys; the decoder ignores them.
        'type': 'connection',
        'event': 'status',
        'phase': 'reconnecting',
        'quality': null,
        'accessPointId': 'ap-sg-1',
        'cellId': 'cell-sg-a',
        'regionId': 'sg',
        'protocol': 'quic',
        'rttMs': null,
        'attempt': 2,
        'nextRetryAt': 1762250000000,
        'reason': null,
        'developmentMode': false,
      });
      bridge.emitEvent(EventCode.connectionStatus, {
        ..._statusPayload('online'),
        'quality': 'poor',
        'rttMs': 420,
        'developmentMode': true,
      });

      expect(statuses, hasLength(2));
      final reconnecting = statuses.first;
      expect(reconnecting.phase, ConnectionPhase.reconnecting);
      expect(reconnecting.quality, isNull);
      expect(reconnecting.accessPointId, 'ap-sg-1');
      expect(reconnecting.cellId, 'cell-sg-a');
      expect(reconnecting.regionId, 'sg');
      expect(reconnecting.protocol, 'quic');
      expect(reconnecting.rttMs, isNull);
      expect(reconnecting.attempt, 2);
      expect(reconnecting.nextRetryAt, 1762250000000);
      expect(reconnecting.reason, isNull);
      expect(reconnecting.developmentMode, isFalse);
      final online = statuses.last;
      expect(online.phase, ConnectionPhase.online);
      expect(online.quality, ConnectionQuality.poor);
      expect(online.rttMs, 420);
      expect(online.developmentMode, isTrue);
      expect(objectListener.statuses.map((status) => status.phase),
          [ConnectionPhase.reconnecting, ConnectionPhase.online]);
    });

    test('connection status carries the action required reason', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final statuses = <ConnectionStatus>[];
      client.events.onConnectionStatusChanged(statuses.add);

      await client.events.subscribeEvents(const {});

      for (final reason in [
        'kicked',
        'expired',
        'upgradeRequired',
        'tenantUnavailable',
      ]) {
        bridge.emitEvent(EventCode.connectionStatus, {
          ..._statusPayload('actionRequired'),
          'reason': reason,
        });
      }

      expect(statuses.map((status) => status.phase).toSet(),
          {ConnectionPhase.actionRequired});
      expect(statuses.map((status) => status.reason),
          ['kicked', 'expired', 'upgradeRequired', 'tenantUnavailable']);
    });

    test('connection status rejects an unknown phase', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      await client.events.subscribeEvents(const {});

      expect(
        () => bridge.emitEvent(
          EventCode.connectionStatus,
          _statusPayload('half_open'),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid connection phase: half_open',
          ),
        ),
      );
    });

    test('access switched and changed reach typed and object listeners',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final switched = <AccessSwitchedEvent>[];
      final changed = <AccessChangedEvent>[];
      final objectListener = _ConnectionListener();
      client.events.onAccessSwitched(switched.add);
      client.events.onAccessChanged(changed.add);
      client.events.addEventListener(objectListener);

      await client.events.subscribeEvents(const {});

      bridge.emitEvent(EventCode.accessSwitched, {
        'from': {'ap': 'ap-sg-1', 'protocol': 'quic'},
        'to': {'ap': 'ap-sg-2', 'protocol': 'ws'},
        'reason': 'failure',
      });
      bridge.emitEvent(EventCode.accessChanged, {
        'serial': 42,
        'source': 'lkg',
        'stale': false,
        'developmentMode': false,
        'changes': {
          'accessPointsAdded': ['ap-sg-3'],
          'accessPointsRemoved': <String>[],
          'policyChanged': true,
        },
      });
      // The coarse sync state hint has no listener and reaches none of these.
      bridge.emitEvent(EventCode.connectionSyncStateChanged, {'state': 'idle'});

      expect(switched.single.from.ap, 'ap-sg-1');
      expect(switched.single.from.protocol, 'quic');
      expect(switched.single.to.ap, 'ap-sg-2');
      expect(switched.single.to.protocol, 'ws');
      expect(switched.single.reason, 'failure');
      expect(changed.single.serial, 42);
      expect(changed.single.source, 'lkg');
      expect(changed.single.changes.accessPointsAdded, ['ap-sg-3']);
      expect(changed.single.changes.accessPointsRemoved, isEmpty);
      expect(changed.single.changes.policyChanged, isTrue);
      expect(objectListener.switched, hasLength(1));
      expect(objectListener.changed, hasLength(1));
      expect(objectListener.statuses, isEmpty);
    });

    test('connection getStatus and reconnectNow use the unified invoke route',
        () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);

      final status = await client.connection.getStatus();
      expect(bridge.lastOperation, 'connection.get_status');
      expect(bridge.lastTransport, 'contract-invoke-json');
      expect(status.phase, ConnectionPhase.idle);

      await client.connection.reconnectNow();
      expect(bridge.lastOperation, 'connection.reconnect_now');

      await client.connection.notifyNetworkChange(const NetworkChangeRequest(
        available: true,
        interface: NetworkInterfaceKind.wifi,
        fingerprintHint: '192.168.1',
      ));
      expect(bridge.lastOperation, 'connection.notify_network_change');
      expect(bridge.lastRequest, {
        'available': true,
        'interface': 'wifi',
        'fingerprintHint': '192.168.1',
      });

      await client.lifecycle
          .setAppState(const SetAppStateRequest(appState: AppState.background));
      expect(bridge.lastOperation, 'lifecycle.set_app_state');
      expect(bridge.lastRequest, {'appState': 'background'});
    });

    test('subscribeEventsBatch dispatches received batch events', () async {
      final bridge = _RecordingBridge();
      final client = FlareCoreSdk.createClientWithBridge(bridge);
      final batches = <MessageReceivedBatchEvent>[];
      client.events.onMessageReceivedBatch(batches.add);

      await client.events.subscribeEventsBatch(const {});

      expect(bridge.lastOperation, 'event.subscribe_batch');
      bridge.emitEvent(EventCode.messageReceivedBatch, {
        'messages': [_messageResponse()],
      });

      expect(batches, hasLength(1));
      expect(batches.single.messages, hasLength(1));
      expect(batches.single.messages.single.conversationId, 'c1');
      expect(batches.single.messages.single.conversationSeq, 7);
    });
  });
}

final class _RecordingBridge implements NativeBridge {
  _RecordingBridge({
    this.createTextResponse,
    this.getOneResponse,
    this.bootstrapResponse,
    this.listResponse,
  });

  final Object? createTextResponse;
  final Object? getOneResponse;
  final Object? bootstrapResponse;
  final Object? listResponse;

  String? lastOperation;
  String? lastTransport;
  String? lastCApi;
  Object? lastRequest;
  void Function(int eventType, Object? payload)? eventHandler;

  void emitEvent(int eventType, Map<String, Object?> payload) {
    final handler = eventHandler;
    if (handler == null) {
      throw StateError('event handler not subscribed');
    }
    handler(eventType, payload);
  }

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    lastOperation = descriptor.operation;
    lastTransport = descriptor.transport;
    lastCApi = descriptor.cApi;
    lastRequest = request;

    switch (descriptor.operation) {
      case 'capability.plugin_ui_catalog':
        return {'items': <Object>[]} as T;
      case 'capability.plugin_file_upload':
        return {'fileId': 'file:fixture'} as T;
      case 'capability.plugin_ui_action':
      case 'capability.plugin_ui_resolve':
      case 'capability.plugin_ui_present':
      case 'capability.plugin_ui_invoke':
      case 'capability.plugin_detail':
        return {'accepted': true} as T;
      case 'message.create_text':
        return (createTextResponse ?? _messageResponse()) as T;
      case 'message_builder.dispatch':
        return (createTextResponse ?? _messageResponse()) as T;
      case 'message.send':
        return {
          'ackId': 'ack1',
          'serverId': 's1',
          'clientMsgId': 'cm1',
          'conversationId': 'c1',
          'seq': 12,
          'timestamp': 2000,
          'success': true,
          'errorCode': 0,
          'errorMessage': '',
        } as T;
      case 'message.list':
        return {'messages': <Object>[]} as T;
      case 'message.typing':
        return null as T;
      case 'conversation.get_one':
        return (getOneResponse ?? _goldenMap('conversation_get_one.json')) as T;
      case 'conversation.bootstrap_home':
        return (bootstrapResponse ?? _goldenMap('home_timeline_snapshot.json'))
            as T;
      case 'conversation.list':
        return (listResponse ??
            {
              'conversations': [_goldenMap('conversation_get_one.json')],
            }) as T;
      case 'conversation.list_by_query':
        return (listResponse ?? {'conversations': <Object>[]}) as T;
      case 'event.subscribe':
        final req = request as Map;
        eventHandler = req['handler'] as void Function(int, Object?);
        return {'subscriptionId': 'test-subscription'} as T;
      case 'event.subscribe_batch':
        final req = request as Map;
        eventHandler = req['handler'] as void Function(int, Object?);
        return {
          'subscription': 7,
          'context': 8,
        } as T;
      case 'event.unsubscribe':
        return null as T;
      case 'connection.get_status':
        return _statusPayload('idle') as T;
      case 'connection.reconnect_now':
      case 'connection.notify_network_change':
      case 'lifecycle.set_app_state':
        return null as T;
      default:
        throw UnimplementedError(descriptor.operation);
    }
  }
}

final class _TypingAggregateListener extends FlareImEventListener {
  TypingAggregateEvent? latest;

  @override
  void onTypingAggregateChanged(TypingAggregateEvent event) {
    latest = event;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _ConnectionListener extends FlareImEventListener {
  final statuses = <ConnectionStatus>[];
  final switched = <AccessSwitchedEvent>[];
  final changed = <AccessChangedEvent>[];

  @override
  void onConnectionStatusChanged(ConnectionStatus event) => statuses.add(event);

  @override
  void onAccessSwitched(AccessSwitchedEvent event) => switched.add(event);

  @override
  void onAccessChanged(AccessChangedEvent event) => changed.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, Object?> _statusPayload(String phase) => {
      'phase': phase,
      'quality': phase == 'online' ? 'good' : null,
      'accessPointId': null,
      'cellId': null,
      'regionId': null,
      'protocol': null,
      'rttMs': null,
      'attempt': 0,
      'nextRetryAt': null,
      'reason': null,
      'developmentMode': false,
    };

Map<String, Object?> _goldenMap(String name) {
  final file = File('../../sdk-spec/golden/responses/$name');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Map<String, Object?> _messageResponse() {
  return {
    'serverId': 'm1',
    'clientMsgId': 'cm1',
    'conversationId': 'c1',
    'conversationType': 1,
    'channelId': 'ch1',
    'senderId': 'u1',
    'source': 2,
    'conversationSeq': 7,
    'createdAt': 1000,
    'clientCreatedAt': 900,
    'messageType': 1,
    'content': {
      'contentType': 'text',
      'text': 'hello',
      'mentions': <Object>[],
    },
    'senderName': 'User One',
    'senderAvatar': 'https://example.com/u1.png',
    'senderDisplayName': 'User One',
    'sender': {'kind': 'named', 'text': 'User One', 'source': 'snapshot'},
    'status': 2,
    'isRead': false,
    'isRecalled': false,
    'isEdited': false,
    'mentionUsers': ['u2'],
    'mentionAll': false,
    'attributes': {'scope': 'test'},
    'extensions': <String, Object?>{},
    'reactions': <Object?>[],
    'textPreview': 'hello',
    'version': 1,
    'updatedAt': 1000,
    'localState': {
      'sending': false,
      'failed': false,
      'isLocal': true,
      'sortTs': 900,
    },
    'timelineKey': 'c1:7',
    'timelineSortTs': 1000,
  };
}
