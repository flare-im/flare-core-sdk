import '../../api/api.dart';
import '../../contract/bridge_contract.dart';
import '../../listener/listener.dart';
import '../../model/model.dart';
import '../codec/wire_codec.dart';

typedef _UntypedHandler = void Function(Object event);

/// Local event fan-out for object listeners and typed `on*` registrations.
final class DefaultEventsApi implements EventsApi {
  DefaultEventsApi(this._bridge);

  final NativeBridge _bridge;
  final _subscriptions = <Object, _DefaultEventSubscription>{};
  int _nextId = 1;

  @override
  Future<Map<String, Object?>> subscribeEvents(Map<String, Object?> request) {
    return _bridge.invoke<Map<String, Object?>>(NativeCallMap.eventSubscribe, {
      'handler': _handleNativeEvent,
    });
  }

  @override
  Future<Map<String, Object?>> subscribeEventsBatch(
      Map<String, Object?> request) {
    return _bridge
        .invoke<Map<String, Object?>>(NativeCallMap.eventSubscribeBatch, {
      'handler': _handleNativeEvent,
    });
  }

  @override
  Future<void> unsubscribe(Map<String, Object?> request) {
    return _bridge.invoke<void>(NativeCallMap.eventUnsubscribe, request);
  }

  @override
  Future<void> unsubscribeAll() {
    _subscriptions.clear();
    return _bridge.invoke<void>(NativeCallMap.eventUnsubscribeAll);
  }

  @override
  EventSubscription addEventListener(FlareImEventListener listener) {
    return _add(_ListenerHandler(listener));
  }

  @override
  void removeEventListener(EventSubscription subscription) {
    subscription.unsubscribe();
  }

  EventSubscription _add(Object handler) {
    final id = _nextId++;
    final sub = _DefaultEventSubscription(id, () => _subscriptions.remove(id));
    sub.handler = handler;
    _subscriptions[id] = sub;
    return sub;
  }

  void emitLifecycle(LifecycleEvent event) => _emit(event);
  void emitMessageSendAck(MessageSendAckEvent event) => _emit(event);
  void emitMessageSendFailed(MessageSendFailedEvent event) => _emit(event);

  void _handleNativeEvent(int eventType, Object? payload) {
    final eventPayload = payload is Map ? payload : const <Object?, Object?>{};
    switch (eventType) {
      case EventCode.connectionStatus:
        _emit(connectionStatusFromJson(eventPayload));
      case EventCode.connectionSyncStateChanged:
        _emit(connectionSyncStateEventFromJson(eventPayload));
      case EventCode.accessSwitched:
        _emit(accessSwitchedEventFromJson(eventPayload));
      case EventCode.accessChanged:
        _emit(accessChangedEventFromJson(eventPayload));
      case EventCode.updateState:
        _emit(updateStatusFromJson(eventPayload));
      case EventCode.messageSendAck:
        final rawAck = eventPayload['ack'];
        _emit(MessageSendAckEvent(
          ack: sendAckFromJson(
            rawAck is Map ? _requiredEventMap(rawAck, 'ack') : eventPayload,
          ),
        ));
      case EventCode.messageSendFailed:
        _emit(MessageSendFailedEvent(
          clientMsgId:
              _requiredEventString(eventPayload['clientMsgId'], 'clientMsgId'),
          reason: _requiredEventString(eventPayload['reason'], 'reason'),
          error: sdkErrorPayloadFromJson(eventPayload['error']),
        ));
      case EventCode.messageReceived:
        _emit(
          MessageReceivedEvent(
            message: messageFromJson(
              _messagePayloadFromReceivedEvent(eventPayload),
            ),
          ),
        );
      case EventCode.messageReceivedBatch:
        _emit(
          MessageReceivedBatchEvent(
            messages: _requiredEventListOfMaps(
              eventPayload['messages'],
              'messages',
            ).map(messageFromJson).toList(growable: false),
          ),
        );
      case EventCode.messageTyping:
        _emit(TypingEvent(
          conversationId: _requiredEventString(
            eventPayload['conversationId'],
            'conversationId',
          ),
          userId: _requiredEventString(eventPayload['userId'], 'userId'),
          typing: _requiredEventBool(eventPayload['typing'], 'typing'),
        ));
      case EventCode.messageTypingAggregate:
        _emit(TypingAggregateEvent(
          conversationId: _requiredEventString(
            eventPayload['conversationId'],
            'conversationId',
          ),
          typingUserIds: _requiredEventStringList(
            eventPayload['typingUserIds'],
            'typingUserIds',
          ),
          typingCount:
              _requiredEventInt(eventPayload['typingCount'], 'typingCount'),
        ));
      case EventCode.messageReadReceipt:
        _emit(ReadReceiptEvent(
          conversationId: _requiredEventString(
            eventPayload['conversationId'],
            'conversationId',
          ),
          userId: _requiredEventString(eventPayload['userId'], 'userId'),
          readSeq:
              _requiredPositiveEventInt(eventPayload['readSeq'], 'readSeq'),
        ));
      case EventCode.messageReactionChanged:
        _emit(ReactionChangedEvent(
          conversationId: _requiredEventString(
            eventPayload['conversationId'],
            'conversationId',
          ),
          serverMsgId:
              _requiredEventString(eventPayload['serverMsgId'], 'serverMsgId'),
          userId: _requiredEventString(eventPayload['userId'], 'userId'),
          emoji: _requiredEventString(eventPayload['emoji'], 'emoji'),
          action: _requiredEventInt(eventPayload['action'], 'action'),
        ));
      case EventCode.messageRecalled:
        _emit(messageMutationFromPayload(
          MessageEventName.recalled,
          eventPayload,
        ));
      case EventCode.messageEdited:
        _emit(messageMutationFromPayload(
          MessageEventName.edited,
          eventPayload,
        ));
      case EventCode.messageDeleted:
        _emit(messageMutationFromPayload(
          MessageEventName.deleted,
          eventPayload,
        ));
      case EventCode.messagePinned:
        _emit(messageMutationFromPayload(
          MessageEventName.pinned,
          eventPayload,
        ));
      case EventCode.messageUnpinned:
        _emit(messageMutationFromPayload(
          MessageEventName.unpinned,
          eventPayload,
        ));
      case EventCode.messageMarked:
        _emit(messageMutationFromPayload(
          MessageEventName.marked,
          eventPayload,
        ));
      case EventCode.messageUnmarked:
        _emit(messageMutationFromPayload(
          MessageEventName.unmarked,
          eventPayload,
        ));
      case EventCode.messagePluginStateChanged:
        _emit(messageMutationFromPayload(
          MessageEventName.pluginStateChanged,
          eventPayload,
        ));
      case EventCode.messageRetentionScheduled:
        _emit(messageMutationFromPayload(
          MessageEventName.retentionScheduled,
          eventPayload,
        ));
      case EventCode.messageRetentionExpired:
        _emit(messageMutationFromPayload(
          MessageEventName.retentionExpired,
          eventPayload,
        ));
      case EventCode.messageRetentionPurged:
        _emit(messageMutationFromPayload(
          MessageEventName.retentionPurged,
          eventPayload,
        ));
      case EventCode.conversationSynced:
      case EventCode.conversationCreated:
      case EventCode.conversationUpdated:
      case EventCode.conversationUnreadCountChanged:
      case EventCode.conversationDeleted:
        _emit(conversationEventFromCode(eventType, eventPayload));
      case EventCode.syncStarted:
      case EventCode.syncFinished:
      case EventCode.syncFailed:
      case EventCode.syncProgress:
      case EventCode.syncTaskCompleted:
      case EventCode.syncStateChanged:
      case EventCode.syncResyncNeeded:
        _emit(syncEventFromCode(eventType, eventPayload));
      case EventCode.pluginRealtime:
        _emit(PluginRealtimeEvent(
          pluginId: _requiredEventString(eventPayload['pluginId'], 'pluginId'),
          packetType:
              _requiredEventString(eventPayload['packetType'], 'packetType'),
          conversationId: _requiredEventString(
            eventPayload['conversationId'],
            'conversationId',
          ),
          payload: _requiredEventObject(eventPayload['payload'], 'payload'),
          deliveryId:
              _requiredEventString(eventPayload['deliveryId'], 'deliveryId'),
          expiresAtMs:
              _requiredEventInt(eventPayload['expiresAtMs'], 'expiresAtMs'),
        ));
      case EventCode.pluginCatalogChanged:
        _emit(PluginCatalogChangedEvent(
          version: _requiredEventString(eventPayload['version'], 'version'),
        ));
      case EventCode.notificationPresent:
        _emit(notificationPresentationFromJson(eventPayload));
      case EventCode.notificationClear:
        _emit(NotificationClearEvent(
          collapseIds: _requiredEventStringList(
            eventPayload['collapseIds'],
            'collapseIds',
          ),
          all: _requiredEventBool(eventPayload['all'], 'all'),
        ));
      case EventCode.notificationBadge:
        _emit(NotificationBadgeEvent(
          count: _requiredEventInt(eventPayload['count'], 'count'),
        ));
      case EventCode.viewUpdated:
        _emit(viewUpdateFromJson(eventPayload));
      default:
        _emit(<String, Object?>{
          'type': 'unknown',
          'name': 'unknown',
          'event': 'unknown',
          'eventType': eventType,
          'payload': eventPayload,
        });
    }
  }

  void _emit(Object event) {
    final current = List<_DefaultEventSubscription>.of(_subscriptions.values);
    for (final sub in current) {
      try {
        sub.dispatch(event);
      } catch (error, stackTrace) {
        _reportListenerError(error, stackTrace);
      }
    }
  }

  @override
  EventSubscription onInitializing(EventCallback<LifecycleEvent> listener) =>
      _addWhere(
          listener, (event) => event.name == LifecycleEventName.initializing);
  @override
  EventSubscription onInitialized(EventCallback<LifecycleEvent> listener) =>
      _addWhere(
          listener, (event) => event.name == LifecycleEventName.initialized);
  @override
  EventSubscription onInitFailed(EventCallback<LifecycleEvent> listener) =>
      _addWhere(
          listener, (event) => event.name == LifecycleEventName.initFailed);
  @override
  EventSubscription onLoginSucceeded(EventCallback<LifecycleEvent> listener) =>
      _addWhere(
          listener, (event) => event.name == LifecycleEventName.loginSucceeded);
  @override
  EventSubscription onLoginFailed(EventCallback<LifecycleEvent> listener) =>
      _addWhere(
          listener, (event) => event.name == LifecycleEventName.loginFailed);
  @override
  EventSubscription onLoggedOut(EventCallback<LifecycleEvent> listener) =>
      _addWhere(
          listener, (event) => event.name == LifecycleEventName.loggedOut);
  @override
  EventSubscription onDisposed(EventCallback<LifecycleEvent> listener) =>
      _addWhere(listener, (event) => event.name == LifecycleEventName.disposed);
  @override
  EventSubscription onConnectionStatusChanged(
    EventCallback<ConnectionStatus> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onAccessSwitched(
    EventCallback<AccessSwitchedEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onAccessChanged(
    EventCallback<AccessChangedEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onUpdateState(
    EventCallback<UpdateStatus> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onMessageReceived(
    EventCallback<MessageReceivedEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onMessageReceivedBatch(
    EventCallback<MessageReceivedBatchEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onMessageSendAck(
    EventCallback<MessageSendAckEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onMessageSendFailed(
    EventCallback<MessageSendFailedEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onMessageRecalled(
    EventCallback<MessageMutationEvent> listener,
  ) =>
      _addWhere(listener, (event) => event.name == MessageEventName.recalled);
  @override
  EventSubscription onMessageEdited(
    EventCallback<MessageMutationEvent> listener,
  ) =>
      _addWhere(listener, (event) => event.name == MessageEventName.edited);
  @override
  EventSubscription onMessageDeleted(
    EventCallback<MessageMutationEvent> listener,
  ) =>
      _addWhere(listener, (event) => event.name == MessageEventName.deleted);
  @override
  EventSubscription onMessageReadReceipt(
    EventCallback<ReadReceiptEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onMessageReactionChanged(
    EventCallback<ReactionChangedEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onInputStatusChanged(EventCallback<TypingEvent> listener) =>
      _addTyped(listener);
  @override
  EventSubscription onTypingAggregateChanged(
    EventCallback<TypingAggregateEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onMessageBurned(
    EventCallback<MessageMutationEvent> listener,
  ) =>
      _addWhere(listener, (event) => event.name == MessageEventName.burned);
  @override
  EventSubscription onMessagePinned(
    EventCallback<MessageMutationEvent> listener,
  ) =>
      _addWhere(listener, (event) => event.name == MessageEventName.pinned);
  @override
  EventSubscription onMessageUnpinned(
    EventCallback<MessageMutationEvent> listener,
  ) =>
      _addWhere(listener, (event) => event.name == MessageEventName.unpinned);
  @override
  EventSubscription onMessagePluginStateChanged(
    EventCallback<MessageMutationEvent> listener,
  ) =>
      _addWhere(
        listener,
        (event) => event.name == MessageEventName.pluginStateChanged,
      );
  @override
  EventSubscription onViewUpdated(EventCallback<ViewUpdate> listener) =>
      _addTyped(listener);
  @override
  EventSubscription onNewConversation(
    EventCallback<ConversationEvent> listener,
  ) =>
      _addWhere(
          listener, (event) => event.name == ConversationEventName.created);
  @override
  EventSubscription onConversationChanged(
    EventCallback<ConversationEvent> listener,
  ) =>
      _addWhere(
          listener, (event) => event.name == ConversationEventName.updated);
  @override
  EventSubscription onTotalUnreadMessageCountChanged(
    EventCallback<ConversationEvent> listener,
  ) =>
      _addWhere(listener,
          (event) => event.name == ConversationEventName.unreadCountChanged);
  @override
  EventSubscription onConversationDeleted(
    EventCallback<ConversationEvent> listener,
  ) =>
      _addWhere(
          listener, (event) => event.name == ConversationEventName.deleted);
  @override
  EventSubscription onSyncServerStart(EventCallback<SyncEvent> listener) =>
      _addWhere(listener, (event) => event.name == SyncEventName.started);
  @override
  EventSubscription onSyncServerFinish(EventCallback<SyncEvent> listener) =>
      _addWhere(listener, (event) => event.name == SyncEventName.finished);
  @override
  EventSubscription onSyncServerFailed(EventCallback<SyncEvent> listener) =>
      _addWhere(listener, (event) => event.name == SyncEventName.failed);
  @override
  EventSubscription onSyncProgress(EventCallback<ProgressEvent> listener) =>
      _add((Object event) {
        if (event is ProgressEvent &&
            event.name == ProgressEventName.syncProgress) {
          listener(event);
          return;
        }
        if (event is SyncEvent && event.name == SyncEventName.progress) {
          listener(
            ProgressEvent(
              name: ProgressEventName.syncProgress,
              operation: event.task ?? event.phase ?? 'sync',
              current: event.progress ?? 0,
              total: 100,
            ),
          );
        }
      });
  @override
  EventSubscription onUploadProgress(EventCallback<ProgressEvent> listener) =>
      _addWhere(
          listener, (event) => event.name == ProgressEventName.uploadProgress);
  @override
  EventSubscription onDownloadProgress(EventCallback<ProgressEvent> listener) =>
      _addWhere(listener,
          (event) => event.name == ProgressEventName.downloadProgress);
  @override
  EventSubscription onPluginRealtime(
    EventCallback<PluginRealtimeEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onPluginCatalogChanged(
    EventCallback<PluginCatalogChangedEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onNotificationPresent(
    EventCallback<NotificationPresentation> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onNotificationClear(
    EventCallback<NotificationClearEvent> listener,
  ) =>
      _addTyped(listener);
  @override
  EventSubscription onNotificationBadge(
    EventCallback<NotificationBadgeEvent> listener,
  ) =>
      _addTyped(listener);

  EventSubscription _addTyped<T>(EventCallback<T> callback) {
    return _addWhere(callback, (_) => true);
  }

  EventSubscription _addWhere<T>(
    EventCallback<T> callback,
    bool Function(dynamic event) test,
  ) {
    return _add((Object event) {
      if (event is T && test(event)) {
        callback(event as T);
      }
    });
  }
}

void _reportListenerError(Object error, StackTrace stackTrace) {
  // Generated SDK code must isolate listener failures while still surfacing them.
  // ignore: avoid_print
  print('flare-core event listener failed: $error\n$stackTrace');
}

final class _DefaultEventSubscription implements EventSubscription {
  _DefaultEventSubscription(this.id, this._unsubscribe);

  @override
  final Object id;
  final void Function() _unsubscribe;
  Object? handler;
  bool _active = true;

  void dispatch(Object event) {
    if (!_active) {
      return;
    }
    final current = handler;
    if (current is _UntypedHandler) {
      current(event);
    } else if (current is _ListenerHandler) {
      current.dispatch(event);
    }
  }

  @override
  void unsubscribe() {
    if (_active) {
      _active = false;
      _unsubscribe();
    }
  }
}

final class _ListenerHandler {
  const _ListenerHandler(this.listener);

  final FlareImEventListener listener;

  void dispatch(Object event) {
    switch (event) {
      case LifecycleEvent():
        _dispatchLifecycle(event);
      case ConnectionStatus():
        listener.onConnectionStatusChanged(event);
      case AccessSwitchedEvent():
        listener.onAccessSwitched(event);
      case AccessChangedEvent():
        listener.onAccessChanged(event);
      case UpdateStatus():
        listener.onUpdateState(event);
      case MessageReceivedEvent():
        listener.onMessageReceived(event);
      case MessageReceivedBatchEvent():
        listener.onMessageReceivedBatch(event);
      case MessageSendAckEvent():
        listener.onMessageSendAck(event);
      case MessageSendFailedEvent():
        listener.onMessageSendFailed(event);
      case MessageMutationEvent():
        _dispatchMessageMutation(event);
      case ReadReceiptEvent():
        listener.onMessageReadReceipt(event);
      case ReactionChangedEvent():
        listener.onMessageReactionChanged(event);
      case TypingEvent():
        listener.onInputStatusChanged(event);
      case TypingAggregateEvent():
        listener.onTypingAggregateChanged(event);
      case ConversationEvent():
        _dispatchConversation(event);
      case ViewUpdate():
        listener.onViewUpdated(event);
      case SyncEvent():
        switch (event.name) {
          case SyncEventName.started:
            listener.onSyncServerStart(event);
          case SyncEventName.finished:
            listener.onSyncServerFinish(event);
          case SyncEventName.failed:
            listener.onSyncServerFailed(event);
          case SyncEventName.progress:
            listener.onSyncProgress(
              ProgressEvent(
                name: ProgressEventName.syncProgress,
                operation: event.task ?? event.phase ?? 'sync',
                current: event.progress ?? 0,
                total: 100,
              ),
            );
          case SyncEventName.stateChanged:
          case SyncEventName.taskCompleted:
          case SyncEventName.resyncNeeded:
          case SyncEventName.readiness:
            break;
        }
      case ProgressEvent():
        listener.onSyncProgress(event);
      case PluginRealtimeEvent():
        listener.onPluginRealtime(event);
      case PluginCatalogChangedEvent():
        listener.onPluginCatalogChanged(event);
      case NotificationPresentation():
        listener.onNotificationPresent(event);
      case NotificationClearEvent():
        listener.onNotificationClear(event);
      case NotificationBadgeEvent():
        listener.onNotificationBadge(event);
    }
  }

  void _dispatchLifecycle(LifecycleEvent event) {
    switch (event.name) {
      case LifecycleEventName.initializing:
        listener.onInitializing(event);
      case LifecycleEventName.initialized:
        listener.onInitialized(event);
      case LifecycleEventName.initFailed:
        listener.onInitFailed(event);
      case LifecycleEventName.loginSucceeded:
        listener.onLoginSucceeded(event);
      case LifecycleEventName.loginFailed:
        listener.onLoginFailed(event);
      case LifecycleEventName.loggedOut:
        listener.onLoggedOut(event);
      case LifecycleEventName.disposed:
        listener.onDisposed(event);
    }
  }

  void _dispatchConversation(ConversationEvent event) {
    switch (event.name) {
      case ConversationEventName.created:
        listener.onNewConversation(event);
      case ConversationEventName.updated:
        listener.onConversationChanged(event);
      case ConversationEventName.unreadCountChanged:
        listener.onTotalUnreadMessageCountChanged(event);
      case ConversationEventName.deleted:
        listener.onConversationDeleted(event);
      case ConversationEventName.synced:
        listener.onConversationChanged(event);
    }
  }

  void _dispatchMessageMutation(MessageMutationEvent event) {
    switch (event.name) {
      case MessageEventName.recalled:
        listener.onMessageRecalled(event);
      case MessageEventName.edited:
        listener.onMessageEdited(event);
      case MessageEventName.deleted:
        listener.onMessageDeleted(event);
      case MessageEventName.burned:
      case MessageEventName.retentionExpired:
      case MessageEventName.retentionPurged:
        listener.onMessageBurned(event);
      case MessageEventName.pinned:
        listener.onMessagePinned(event);
      case MessageEventName.unpinned:
        listener.onMessageUnpinned(event);
      case MessageEventName.pluginStateChanged:
        listener.onMessagePluginStateChanged(event);
      case MessageEventName.received:
      case MessageEventName.receivedBatch:
      case MessageEventName.sendAck:
      case MessageEventName.sendFailed:
      case MessageEventName.typing:
      case MessageEventName.typingAggregate:
      case MessageEventName.reactionChanged:
      case MessageEventName.readReceipt:
      case MessageEventName.burnScheduled:
      case MessageEventName.hardDeleted:
      case MessageEventName.marked:
      case MessageEventName.unmarked:
      case MessageEventName.retentionScheduled:
      case MessageEventName.presenceChanged:
      case MessageEventName.custom:
      case MessageEventName.readSummariesChanged:
        break;
    }
  }
}

Map<dynamic, dynamic> _messagePayloadFromReceivedEvent(
  Map<dynamic, dynamic> payload,
) {
  final wrapped = payload['message'];
  return wrapped is Map ? _requiredEventMap(wrapped, 'message') : payload;
}

MessageMutationEvent messageMutationFromPayload(
  MessageEventName name,
  Map<dynamic, dynamic> json,
) {
  return MessageMutationEvent(
    name: name,
    conversationId:
        _requiredEventString(json['conversationId'], 'conversationId'),
    messageId: _optionalEventString(json['messageId'], 'messageId'),
    serverMsgId: _optionalEventString(json['serverMsgId'], 'serverMsgId'),
    userId: _optionalEventString(json['userId'], 'userId'),
    reason: _optionalEventString(json['reason'], 'reason'),
  );
}

ConversationEvent conversationEventFromCode(
  int eventType,
  Map<dynamic, dynamic> json,
) {
  return ConversationEvent(
    name: switch (eventType) {
      EventCode.conversationSynced => ConversationEventName.synced,
      EventCode.conversationCreated => ConversationEventName.created,
      EventCode.conversationUpdated => ConversationEventName.updated,
      EventCode.conversationUnreadCountChanged =>
        ConversationEventName.unreadCountChanged,
      EventCode.conversationDeleted => ConversationEventName.deleted,
      _ => throw FormatException('invalid conversation event type: $eventType'),
    },
    conversationId:
        _optionalEventString(json['conversationId'], 'conversationId'),
    conversationIds:
        _optionalEventStringList(json['conversationIds'], 'conversationIds'),
    unreadCount: _optionalEventInt(json['unreadCount'], 'unreadCount'),
  );
}

SyncEvent syncEventFromCode(int eventType, Map<dynamic, dynamic> json) {
  final name = switch (eventType) {
    EventCode.syncStateChanged => SyncEventName.stateChanged,
    EventCode.syncStarted => SyncEventName.started,
    EventCode.syncFinished => SyncEventName.finished,
    EventCode.syncFailed => SyncEventName.failed,
    EventCode.syncProgress => SyncEventName.progress,
    EventCode.syncTaskCompleted => SyncEventName.taskCompleted,
    EventCode.syncResyncNeeded => SyncEventName.resyncNeeded,
    _ => throw FormatException('invalid sync event type: $eventType'),
  };
  return SyncEvent(
    name: name,
    trigger: _optionalEventString(json['trigger'], 'trigger'),
    phase: _optionalEventString(json['phase'], 'phase'),
    task: _optionalEventString(json['task'], 'task'),
    progress: _optionalProgressPercent(json['progress']),
    error: name == SyncEventName.failed
        ? sdkErrorPayloadFromJson(json['error'])
        : null,
  );
}

Never _invalidEventField(String field, String expected) {
  throw FormatException(
    'invalid event payload field: $field',
    {'field': field, 'expected': expected},
  );
}

Map<dynamic, dynamic> _requiredEventMap(Object? value, String field) {
  if (value is Map) return value;
  _invalidEventField(field, 'object');
}

Map<String, Object?> _requiredEventObject(Object? value, String field) {
  return _requiredEventMap(value, field)
      .map((key, item) => MapEntry(key.toString(), item));
}

String _requiredEventString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  _invalidEventField(field, 'non-empty string');
}

String? _optionalEventString(Object? value, String field) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  _invalidEventField(field, 'non-empty string');
}

int _requiredEventInt(Object? value, String field) {
  if (value is int && value >= 0) return value;
  if (value is double &&
      value.isFinite &&
      value >= 0 &&
      value.truncateToDouble() == value) {
    return value.toInt();
  }
  _invalidEventField(field, 'unsigned integer');
}

int _requiredPositiveEventInt(Object? value, String field) {
  final parsed = _requiredEventInt(value, field);
  if (parsed > 0) return parsed;
  _invalidEventField(field, 'positive integer');
}

int? _optionalEventInt(Object? value, String field) {
  if (value == null) return null;
  return _requiredEventInt(value, field);
}

/// 同步进度是纯展示字段（0–100 百分比）：任何有限数字都四舍五入并钳到 [0,100]，
/// null/NaN/非数字回退 null。**绝不抛异常**——进度值格式绝不能崩掉整个事件流
/// （历史 bug：core 曾发 0–1 浮点比例，强类型整数解码在 0.5 上抛 FormatException
/// 冒泡到 go_router redirect 崩 app）。
int? _optionalProgressPercent(Object? value) {
  if (value is int) return value.clamp(0, 100);
  if (value is double) {
    if (!value.isFinite) return null;
    return value.round().clamp(0, 100);
  }
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite) return parsed.round().clamp(0, 100);
  }
  return null;
}

bool _requiredEventBool(Object? value, String field) {
  if (value is bool) return value;
  _invalidEventField(field, 'boolean');
}

List<Map<dynamic, dynamic>> _requiredEventListOfMaps(
  Object? value,
  String field,
) {
  if (value is! Iterable) {
    _invalidEventField(field, 'array');
  }
  var index = 0;
  final out = <Map<dynamic, dynamic>>[];
  for (final item in value) {
    if (item is! Map<dynamic, dynamic>) {
      _invalidEventField('$field.$index', 'object');
    }
    out.add(item);
    index += 1;
  }
  return out;
}

List<String> _optionalEventStringList(Object? value, String field) {
  if (value == null) return const [];
  if (value is! Iterable) {
    _invalidEventField(field, 'array');
  }
  var index = 0;
  final out = <String>[];
  for (final item in value) {
    out.add(_requiredEventString(item, '$field.$index'));
    index += 1;
  }
  return out;
}

List<String> _requiredEventStringList(Object? value, String field) {
  if (value is! Iterable) {
    _invalidEventField(field, 'array');
  }
  var index = 0;
  final out = <String>[];
  for (final item in value) {
    out.add(_requiredEventString(item, '$field.$index'));
    index += 1;
  }
  return out;
}
