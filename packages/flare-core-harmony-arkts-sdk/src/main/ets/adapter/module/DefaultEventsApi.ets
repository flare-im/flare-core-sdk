// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { EventsApi } from '../../api/modules/events';
import type { EventCallback, EventSubscription, FlareImEventListener } from '../../listener';
import { FfiNativeBridge } from '../../bridge/FfiNativeBridge';
import {
  AccessChangedEvent,
  AccessSwitchedEvent,
  ConnectionStatus,
  ConversationEvent,
  LifecycleEvent,
  LifecycleEventName,
  MessageMutationEvent,
  MessageReceivedBatchEvent,
  MessageReceivedEvent,
  MessageSendAckEvent,
  MessageSendFailedEvent,
  PluginCatalogChangedEvent,
  PluginRealtimeEvent,
  ProgressEvent,
  ReactionChangedEvent,
  ReadReceiptEvent,
  SyncEvent,
  TypingAggregateEvent,
  TypingEvent,
  ViewUpdate,
} from '../../model';
import { accessChangedEventFromJson, accessSwitchedEventFromJson, connectionStatusFromJson } from '../codec/WireCodec';

/** C ABI event codes (`FLARE_EVENT_*`) this module decodes from the native event stream. */
export class NativeEventCode {
  static readonly connectionStatus: number = 1010;
  static readonly accessSwitched: number = 1011;
  static readonly accessChanged: number = 1012;
}

/** Which typed callback an event goes to; one per `on*` registration. */
export enum EventRoute {
  Initializing = 'initializing',
  Initialized = 'initialized',
  InitFailed = 'initFailed',
  LoginSucceeded = 'loginSucceeded',
  LoginFailed = 'loginFailed',
  LoggedOut = 'loggedOut',
  Disposed = 'disposed',
  ConnectionStatusChanged = 'connectionStatusChanged',
  AccessSwitched = 'accessSwitched',
  AccessChanged = 'accessChanged',
  MessageReceived = 'messageReceived',
  MessageReceivedBatch = 'messageReceivedBatch',
  MessageSendAck = 'messageSendAck',
  MessageSendFailed = 'messageSendFailed',
  MessageRecalled = 'messageRecalled',
  MessageEdited = 'messageEdited',
  MessageDeleted = 'messageDeleted',
  MessageReadReceipt = 'messageReadReceipt',
  MessageReactionChanged = 'messageReactionChanged',
  InputStatusChanged = 'inputStatusChanged',
  TypingAggregateChanged = 'typingAggregateChanged',
  MessageBurned = 'messageBurned',
  MessagePinned = 'messagePinned',
  MessageUnpinned = 'messageUnpinned',
  MessagePluginStateChanged = 'messagePluginStateChanged',
  ViewUpdated = 'viewUpdated',
  NewConversation = 'newConversation',
  ConversationChanged = 'conversationChanged',
  TotalUnreadMessageCountChanged = 'totalUnreadMessageCountChanged',
  ConversationDeleted = 'conversationDeleted',
  SyncServerStart = 'syncServerStart',
  SyncServerFinish = 'syncServerFinish',
  SyncServerFailed = 'syncServerFailed',
  SyncProgress = 'syncProgress',
  UploadProgress = 'uploadProgress',
  DownloadProgress = 'downloadProgress',
  PluginRealtime = 'pluginRealtime',
  PluginCatalogChanged = 'pluginCatalogChanged',
}

/** A decoded native event and the callback it goes to. */
export class RoutedEvent {
  readonly route: EventRoute;
  readonly event: Object;

  constructor(route: EventRoute, event: Object) {
    this.route = route;
    this.event = event;
  }
}

/**
 * Decodes one native event (`FlareEventCallback`: C event code plus JSON payload). Undefined for
 * codes this module does not route and for payloads that break their contract (a status without
 * a known phase): a broken status is dropped, never shown.
 */
export function routeNativeEvent(eventType: number, eventJson: string): RoutedEvent | undefined {
  let payload: Object;
  try {
    payload = JSON.parse(eventJson) as Object;
  } catch (error) {
    return undefined;
  }
  try {
    switch (eventType) {
      case NativeEventCode.connectionStatus:
        return new RoutedEvent(EventRoute.ConnectionStatusChanged, connectionStatusFromJson(payload));
      case NativeEventCode.accessSwitched:
        return new RoutedEvent(EventRoute.AccessSwitched, accessSwitchedEventFromJson(payload));
      case NativeEventCode.accessChanged:
        return new RoutedEvent(EventRoute.AccessChanged, accessChangedEventFromJson(payload));
      default:
        return undefined;
    }
  } catch (error) {
    console.error(`flare-core dropped native event ${eventType}: ${error}`);
    return undefined;
  }
}

function lifecycleRoute(name: LifecycleEventName): EventRoute | undefined {
  switch (name) {
    case LifecycleEventName.Initializing:
      return EventRoute.Initializing;
    case LifecycleEventName.Initialized:
      return EventRoute.Initialized;
    case LifecycleEventName.InitFailed:
      return EventRoute.InitFailed;
    case LifecycleEventName.LoginSucceeded:
      return EventRoute.LoginSucceeded;
    case LifecycleEventName.LoginFailed:
      return EventRoute.LoginFailed;
    case LifecycleEventName.LoggedOut:
      return EventRoute.LoggedOut;
    case LifecycleEventName.Disposed:
      return EventRoute.Disposed;
    default:
      return undefined;
  }
}

class DefaultEventSubscription implements EventSubscription {
  readonly id: string;
  /** Set for typed `on*` registrations: the one route this callback receives. */
  readonly route?: EventRoute;
  readonly callback?: EventCallback<Object>;
  readonly listener?: FlareImEventListener;
  private readonly onDispose: () => void;

  constructor(
    id: string,
    onDispose: () => void,
    route?: EventRoute,
    callback?: EventCallback<Object>,
    listener?: FlareImEventListener,
  ) {
    this.id = id;
    this.onDispose = onDispose;
    this.route = route;
    this.callback = callback;
    this.listener = listener;
  }

  unsubscribe(): void {
    this.onDispose();
  }
}

export class DefaultEventsApi implements EventsApi {
  private subscriptions: Map<number, DefaultEventSubscription> = new Map<number, DefaultEventSubscription>();
  private nextId: number = 1;
  private readonly bridge: NativeBridge;

  constructor(bridge: NativeBridge) {
    this.bridge = bridge;
    if (bridge instanceof FfiNativeBridge) {
      bridge.registerEventSink((eventType: number, eventJson: string) => {
        this.emitNativeEvent(eventType, eventJson);
      });
    }
  }

  async subscribeEvents(request: Record<string, Object>): Promise<Record<string, Object>> {
    return this.bridge.invoke<Record<string, Object>>(NativeCallMap.eventSubscribe, request);
  }

  async subscribeEventsBatch(request: Record<string, Object>): Promise<Record<string, Object>> {
    return this.bridge.invoke<Record<string, Object>>(NativeCallMap.eventSubscribeBatch, request);
  }

  async unsubscribe(request: Record<string, Object>): Promise<void> {
    await this.bridge.invoke<void>(NativeCallMap.eventUnsubscribe, request);
  }

  async unsubscribeAll(): Promise<void> {
    this.subscriptions.clear();
    await this.bridge.invoke<void>(NativeCallMap.eventUnsubscribeAll);
  }

  /** Adapter-raised lifecycle events (`emitLifecycleEvent`); anything else is ignored. */
  emit(event: Object): void {
    const name = (event as LifecycleEvent).name;
    if (name === undefined) {
      return;
    }
    const route = lifecycleRoute(name);
    if (route !== undefined) {
      this.deliver(route, event);
    }
  }

  /** One event from the native stream, already on the ArkTS thread. */
  emitNativeEvent(eventType: number, eventJson: string): void {
    const routed = routeNativeEvent(eventType, eventJson);
    if (routed !== undefined) {
      this.deliver(routed.route, routed.event);
    }
  }

  addEventListener(listener: FlareImEventListener): EventSubscription {
    return this.register(undefined, undefined, listener);
  }

  removeEventListener(subscription: EventSubscription): void {
    subscription.unsubscribe();
  }

  onInitializing(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerTyped(EventRoute.Initializing, listener);
  }

  onInitialized(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerTyped(EventRoute.Initialized, listener);
  }

  onInitFailed(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerTyped(EventRoute.InitFailed, listener);
  }

  onLoginSucceeded(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerTyped(EventRoute.LoginSucceeded, listener);
  }

  onLoginFailed(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerTyped(EventRoute.LoginFailed, listener);
  }

  onLoggedOut(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerTyped(EventRoute.LoggedOut, listener);
  }

  onDisposed(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerTyped(EventRoute.Disposed, listener);
  }

  /** `connection://status`: replace the held status whole and hand it to the Kit ConnectionNotice unchanged. */
  onConnectionStatusChanged(listener: EventCallback<ConnectionStatus>): EventSubscription {
    return this.registerTyped(EventRoute.ConnectionStatusChanged, listener);
  }

  /** `access://switched`. */
  onAccessSwitched(listener: EventCallback<AccessSwitchedEvent>): EventSubscription {
    return this.registerTyped(EventRoute.AccessSwitched, listener);
  }

  /** `access://changed`. */
  onAccessChanged(listener: EventCallback<AccessChangedEvent>): EventSubscription {
    return this.registerTyped(EventRoute.AccessChanged, listener);
  }

  onMessageReceived(listener: EventCallback<MessageReceivedEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageReceived, listener);
  }

  onMessageReceivedBatch(listener: EventCallback<MessageReceivedBatchEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageReceivedBatch, listener);
  }

  onMessageSendAck(listener: EventCallback<MessageSendAckEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageSendAck, listener);
  }

  onMessageSendFailed(listener: EventCallback<MessageSendFailedEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageSendFailed, listener);
  }

  onMessageRecalled(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageRecalled, listener);
  }

  onMessageEdited(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageEdited, listener);
  }

  onMessageDeleted(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageDeleted, listener);
  }

  onMessageReadReceipt(listener: EventCallback<ReadReceiptEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageReadReceipt, listener);
  }

  onMessageReactionChanged(listener: EventCallback<ReactionChangedEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageReactionChanged, listener);
  }

  onInputStatusChanged(listener: EventCallback<TypingEvent>): EventSubscription {
    return this.registerTyped(EventRoute.InputStatusChanged, listener);
  }

  onTypingAggregateChanged(listener: EventCallback<TypingAggregateEvent>): EventSubscription {
    return this.registerTyped(EventRoute.TypingAggregateChanged, listener);
  }

  onMessageBurned(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageBurned, listener);
  }

  onMessagePinned(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessagePinned, listener);
  }

  onMessageUnpinned(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessageUnpinned, listener);
  }

  onMessagePluginStateChanged(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.MessagePluginStateChanged, listener);
  }

  onViewUpdated(listener: EventCallback<ViewUpdate>): EventSubscription {
    return this.registerTyped(EventRoute.ViewUpdated, listener);
  }

  onNewConversation(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.NewConversation, listener);
  }

  onConversationChanged(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.ConversationChanged, listener);
  }

  onTotalUnreadMessageCountChanged(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.TotalUnreadMessageCountChanged, listener);
  }

  onConversationDeleted(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerTyped(EventRoute.ConversationDeleted, listener);
  }

  onSyncServerStart(listener: EventCallback<SyncEvent>): EventSubscription {
    return this.registerTyped(EventRoute.SyncServerStart, listener);
  }

  onSyncServerFinish(listener: EventCallback<SyncEvent>): EventSubscription {
    return this.registerTyped(EventRoute.SyncServerFinish, listener);
  }

  onSyncServerFailed(listener: EventCallback<SyncEvent>): EventSubscription {
    return this.registerTyped(EventRoute.SyncServerFailed, listener);
  }

  onSyncProgress(listener: EventCallback<ProgressEvent>): EventSubscription {
    return this.registerTyped(EventRoute.SyncProgress, listener);
  }

  onUploadProgress(listener: EventCallback<ProgressEvent>): EventSubscription {
    return this.registerTyped(EventRoute.UploadProgress, listener);
  }

  onDownloadProgress(listener: EventCallback<ProgressEvent>): EventSubscription {
    return this.registerTyped(EventRoute.DownloadProgress, listener);
  }

  onPluginRealtime(listener: EventCallback<PluginRealtimeEvent>): EventSubscription {
    return this.registerTyped(EventRoute.PluginRealtime, listener);
  }

  onPluginCatalogChanged(listener: EventCallback<PluginCatalogChangedEvent>): EventSubscription {
    return this.registerTyped(EventRoute.PluginCatalogChanged, listener);
  }

  private register(
    route: EventRoute | undefined,
    callback: EventCallback<Object> | undefined,
    listener: FlareImEventListener | undefined,
  ): EventSubscription {
    const subscriptionId = this.nextId++;
    const subscription = new DefaultEventSubscription(
      subscriptionId.toString(),
      () => {
        this.subscriptions.delete(subscriptionId);
      },
      route,
      callback,
      listener,
    );
    this.subscriptions.set(subscriptionId, subscription);
    return subscription;
  }

  private registerTyped<T>(route: EventRoute, listener: EventCallback<T>): EventSubscription {
    return this.register(route, (event: Object) => {
      listener(event as T);
    }, undefined);
  }

  /** A throwing callback must not stop the others or reach the native module. */
  private deliver(route: EventRoute, event: Object): void {
    const snapshot = Array.from(this.subscriptions.values());
    for (const subscription of snapshot) {
      try {
        if (subscription.listener !== undefined) {
          this.dispatchToListener(subscription.listener, route, event);
        } else if (subscription.route === route && subscription.callback !== undefined) {
          subscription.callback(event);
        }
      } catch (error) {
        console.error(`flare-core ${route} listener failed: ${error}`);
      }
    }
  }

  private dispatchToListener(listener: FlareImEventListener, route: EventRoute, event: Object): void {
    switch (route) {
      case EventRoute.Initializing:
        listener.onInitializing?.(event as LifecycleEvent);
        break;
      case EventRoute.Initialized:
        listener.onInitialized?.(event as LifecycleEvent);
        break;
      case EventRoute.InitFailed:
        listener.onInitFailed?.(event as LifecycleEvent);
        break;
      case EventRoute.LoginSucceeded:
        listener.onLoginSucceeded?.(event as LifecycleEvent);
        break;
      case EventRoute.LoginFailed:
        listener.onLoginFailed?.(event as LifecycleEvent);
        break;
      case EventRoute.LoggedOut:
        listener.onLoggedOut?.(event as LifecycleEvent);
        break;
      case EventRoute.Disposed:
        listener.onDisposed?.(event as LifecycleEvent);
        break;
      case EventRoute.ConnectionStatusChanged:
        listener.onConnectionStatusChanged?.(event as ConnectionStatus);
        break;
      case EventRoute.AccessSwitched:
        listener.onAccessSwitched?.(event as AccessSwitchedEvent);
        break;
      case EventRoute.AccessChanged:
        listener.onAccessChanged?.(event as AccessChangedEvent);
        break;
      case EventRoute.MessageReceived:
        listener.onMessageReceived?.(event as MessageReceivedEvent);
        break;
      case EventRoute.MessageReceivedBatch:
        listener.onMessageReceivedBatch?.(event as MessageReceivedBatchEvent);
        break;
      case EventRoute.MessageSendAck:
        listener.onMessageSendAck?.(event as MessageSendAckEvent);
        break;
      case EventRoute.MessageSendFailed:
        listener.onMessageSendFailed?.(event as MessageSendFailedEvent);
        break;
      case EventRoute.MessageRecalled:
        listener.onMessageRecalled?.(event as MessageMutationEvent);
        break;
      case EventRoute.MessageEdited:
        listener.onMessageEdited?.(event as MessageMutationEvent);
        break;
      case EventRoute.MessageDeleted:
        listener.onMessageDeleted?.(event as MessageMutationEvent);
        break;
      case EventRoute.MessageReadReceipt:
        listener.onMessageReadReceipt?.(event as ReadReceiptEvent);
        break;
      case EventRoute.MessageReactionChanged:
        listener.onMessageReactionChanged?.(event as ReactionChangedEvent);
        break;
      case EventRoute.InputStatusChanged:
        listener.onInputStatusChanged?.(event as TypingEvent);
        break;
      case EventRoute.TypingAggregateChanged:
        listener.onTypingAggregateChanged?.(event as TypingAggregateEvent);
        break;
      case EventRoute.MessageBurned:
        listener.onMessageBurned?.(event as MessageMutationEvent);
        break;
      case EventRoute.MessagePinned:
        listener.onMessagePinned?.(event as MessageMutationEvent);
        break;
      case EventRoute.MessageUnpinned:
        listener.onMessageUnpinned?.(event as MessageMutationEvent);
        break;
      case EventRoute.MessagePluginStateChanged:
        listener.onMessagePluginStateChanged?.(event as MessageMutationEvent);
        break;
      case EventRoute.ViewUpdated:
        listener.onViewUpdated?.(event as ViewUpdate);
        break;
      case EventRoute.NewConversation:
        listener.onNewConversation?.(event as ConversationEvent);
        break;
      case EventRoute.ConversationChanged:
        listener.onConversationChanged?.(event as ConversationEvent);
        break;
      case EventRoute.TotalUnreadMessageCountChanged:
        listener.onTotalUnreadMessageCountChanged?.(event as ConversationEvent);
        break;
      case EventRoute.ConversationDeleted:
        listener.onConversationDeleted?.(event as ConversationEvent);
        break;
      case EventRoute.SyncServerStart:
        listener.onSyncServerStart?.(event as SyncEvent);
        break;
      case EventRoute.SyncServerFinish:
        listener.onSyncServerFinish?.(event as SyncEvent);
        break;
      case EventRoute.SyncServerFailed:
        listener.onSyncServerFailed?.(event as SyncEvent);
        break;
      case EventRoute.SyncProgress:
        listener.onSyncProgress?.(event as ProgressEvent);
        break;
      case EventRoute.UploadProgress:
        listener.onUploadProgress?.(event as ProgressEvent);
        break;
      case EventRoute.DownloadProgress:
        listener.onDownloadProgress?.(event as ProgressEvent);
        break;
      case EventRoute.PluginRealtime:
        listener.onPluginRealtime?.(event as PluginRealtimeEvent);
        break;
      case EventRoute.PluginCatalogChanged:
        listener.onPluginCatalogChanged?.(event as PluginCatalogChangedEvent);
        break;
      default:
        break;
    }
  }
}
