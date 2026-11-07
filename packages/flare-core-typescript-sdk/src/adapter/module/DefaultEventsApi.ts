// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { EventsApi } from '../../api/modules/events';
import type { SubscribeEventsRequest, Subscription, UnsubscribeRequest } from '../../api/types';
import type { EventCallback, EventSubscription, FlareImEventListener } from '../../listener';
import {
  AccessChangedEvent,
  AccessChanges,
  AccessEndpoint,
  AccessEventName,
  AccessSwitchedEvent,
  ConnectionEventName,
  ConnectionPhase,
  ConnectionQuality,
  ConnectionStatus,
  ConnectionSyncStateEvent,
  ConversationEvent,
  ConversationEventName,
  LifecycleEvent,
  LifecycleEventName,
  MessageEventName,
  MessageMutationEvent,
  MessageReceivedBatchEvent,
  MessageReceivedEvent,
  MessageSendAckEvent,
  MessageSendFailedEvent,
  PluginCatalogChangedEvent,
  PluginEventName,
  PluginRealtimeEvent,
  PresenceChangedEvent,
  ProgressEventName,
  ReactionChangedEvent,
  ReadReceiptEvent,
  SdkErrorPayload,
  SyncEvent,
  SyncEventName,
  TypingAggregateEvent,
  TypingEvent,
  UpdateEventName,
  UpdateStatus,
  ViewUpdate,
  ProgressEvent as SdkProgressEvent,
} from '../../model';
import { withoutNullFields } from '../codec/nativeInvoke';
import { messageFromJson, sendAckFromJson, viewUpdateFromJson, wireDecodeResponse } from '../codec/wireCodec';
import { FlareSdkException } from '../../bridge/flareSdkException';

const EVENT_CODE_CONNECTION_SYNC_STATE_CHANGED = 1005;
const EVENT_CODE_CONNECTION_STATUS = 1010;
const EVENT_CODE_ACCESS_SWITCHED = 1011;
const EVENT_CODE_ACCESS_CHANGED = 1012;
const EVENT_CODE_UPDATE_STATE = 1013;
const EVENT_CODE_MESSAGE_RECEIVED = 2001;
const EVENT_CODE_MESSAGE_RECEIVED_BATCH = 2002;
const EVENT_CODE_MESSAGE_SEND_ACK = 2003;
const EVENT_CODE_MESSAGE_SEND_FAILED = 2004;
const EVENT_CODE_MESSAGE_RECALLED = 2005;
const EVENT_CODE_MESSAGE_TYPING = 2006;
const EVENT_CODE_MESSAGE_EDITED = 2008;
const EVENT_CODE_MESSAGE_REACTION_CHANGED = 2009;
const EVENT_CODE_MESSAGE_DELETED = 2010;
const EVENT_CODE_MESSAGE_READ_RECEIPT = 2011;
const EVENT_CODE_MESSAGE_RETENTION_SCHEDULED = 2012;
const EVENT_CODE_MESSAGE_RETENTION_EXPIRED = 2013;
const EVENT_CODE_MESSAGE_RETENTION_PURGED = 2014;
const EVENT_CODE_MESSAGE_PINNED = 2015;
const EVENT_CODE_MESSAGE_UNPINNED = 2016;
const EVENT_CODE_MESSAGE_MARKED = 2017;
const EVENT_CODE_MESSAGE_UNMARKED = 2018;
const EVENT_CODE_MESSAGE_PRESENCE_CHANGED = 2019;
const EVENT_CODE_MESSAGE_CUSTOM = 2020;
const EVENT_CODE_MESSAGE_TYPING_AGGREGATE = 2021;
const EVENT_CODE_MESSAGE_PLUGIN_STATE_CHANGED = 2022;
const EVENT_CODE_MESSAGE_READ_SUMMARIES_CHANGED = 2023;
const EVENT_CODE_CONVERSATION_SYNCED = 3001;
const EVENT_CODE_CONVERSATION_CREATED = 3002;
const EVENT_CODE_CONVERSATION_UPDATED = 3003;
const EVENT_CODE_CONVERSATION_UNREAD_COUNT_CHANGED = 3004;
const EVENT_CODE_CONVERSATION_DELETED = 3005;
const EVENT_CODE_NOTIFICATION_RECEIVED = 3501;
const EVENT_CODE_NOTIFICATION_MESSAGE_SOUND = 3502;
const EVENT_CODE_SYNC_STARTED = 4001;
const EVENT_CODE_SYNC_FINISHED = 4002;
const EVENT_CODE_SYNC_FAILED = 4003;
const EVENT_CODE_SYNC_PROGRESS = 4004;
const EVENT_CODE_SYNC_TASK_COMPLETED = 4005;
const EVENT_CODE_SYNC_STATE_CHANGED = 4006;
const EVENT_CODE_SYNC_RESYNC_NEEDED = 4007;
const EVENT_CODE_SYNC_READINESS = 4008;
const EVENT_CODE_EXTENSION_EVENT = 5001;
const EVENT_CODE_VIEW_UPDATED = 6001;
const EVENT_CODE_PLUGIN_REALTIME = 7001;
const EVENT_CODE_PLUGIN_CATALOG_CHANGED = 7002;

const WEB_EVENT_TYPE_BY_CHANNEL: Record<string, number> = {
  "im://sync_state_changed": EVENT_CODE_CONNECTION_SYNC_STATE_CHANGED,
  "connection://status": EVENT_CODE_CONNECTION_STATUS,
  "access://switched": EVENT_CODE_ACCESS_SWITCHED,
  "access://changed": EVENT_CODE_ACCESS_CHANGED,
  "update://state": EVENT_CODE_UPDATE_STATE,
  "im://message": EVENT_CODE_MESSAGE_RECEIVED,
  "im://message_batch": EVENT_CODE_MESSAGE_RECEIVED_BATCH,
  "im://send_ack": EVENT_CODE_MESSAGE_SEND_ACK,
  "im://send_failed": EVENT_CODE_MESSAGE_SEND_FAILED,
  "im://message_recalled": EVENT_CODE_MESSAGE_RECALLED,
  "im://typing": EVENT_CODE_MESSAGE_TYPING,
  "im://message_edited": EVENT_CODE_MESSAGE_EDITED,
  "im://message_reaction_changed": EVENT_CODE_MESSAGE_REACTION_CHANGED,
  "im://message_deleted": EVENT_CODE_MESSAGE_DELETED,
  "im://message_read_receipt": EVENT_CODE_MESSAGE_READ_RECEIPT,
  "im://message_retention_scheduled": EVENT_CODE_MESSAGE_RETENTION_SCHEDULED,
  "im://message_retention_expired": EVENT_CODE_MESSAGE_RETENTION_EXPIRED,
  "im://message_retention_purged": EVENT_CODE_MESSAGE_RETENTION_PURGED,
  "im://message_pinned": EVENT_CODE_MESSAGE_PINNED,
  "im://message_unpinned": EVENT_CODE_MESSAGE_UNPINNED,
  "im://message_marked": EVENT_CODE_MESSAGE_MARKED,
  "im://message_unmarked": EVENT_CODE_MESSAGE_UNMARKED,
  "im://presence_changed": EVENT_CODE_MESSAGE_PRESENCE_CHANGED,
  "im://message_custom_event": EVENT_CODE_MESSAGE_CUSTOM,
  "im://message_typing_aggregate": EVENT_CODE_MESSAGE_TYPING_AGGREGATE,
  "im://message_plugin_state_changed": EVENT_CODE_MESSAGE_PLUGIN_STATE_CHANGED,
  "im://message_read_summaries_changed": EVENT_CODE_MESSAGE_READ_SUMMARIES_CHANGED,
  "im://conversations_synced": EVENT_CODE_CONVERSATION_SYNCED,
  "im://conversation_created": EVENT_CODE_CONVERSATION_CREATED,
  "im://conversation_updated": EVENT_CODE_CONVERSATION_UPDATED,
  "im://unread_count_changed": EVENT_CODE_CONVERSATION_UNREAD_COUNT_CHANGED,
  "im://conversation_deleted": EVENT_CODE_CONVERSATION_DELETED,
  "im://notification": EVENT_CODE_NOTIFICATION_RECEIVED,
  "im://message_sound": EVENT_CODE_NOTIFICATION_MESSAGE_SOUND,
  "im://sync_started": EVENT_CODE_SYNC_STARTED,
  "im://sync_finished": EVENT_CODE_SYNC_FINISHED,
  "im://sync_failed": EVENT_CODE_SYNC_FAILED,
  "im://sync_progress": EVENT_CODE_SYNC_PROGRESS,
  "im://sync_completed": EVENT_CODE_SYNC_TASK_COMPLETED,
  "im://sync_notify_state_changed": EVENT_CODE_SYNC_STATE_CHANGED,
  "im://resync_needed": EVENT_CODE_SYNC_RESYNC_NEEDED,
  "im://sync_readiness": EVENT_CODE_SYNC_READINESS,
  "im://extension": EVENT_CODE_EXTENSION_EVENT,
  "im://view_updated": EVENT_CODE_VIEW_UPDATED,
  "im://plugin_realtime": EVENT_CODE_PLUGIN_REALTIME,
  "im://plugin_catalog_changed": EVENT_CODE_PLUGIN_CATALOG_CHANGED,
};

export const WEB_EVENT_CHANNELS = Object.freeze(Object.keys(WEB_EVENT_TYPE_BY_CHANNEL));

export function eventTypeForWebChannel(channel: string): number | undefined {
  return WEB_EVENT_TYPE_BY_CHANNEL[channel];
}

function eventPayloadRecord(payload: unknown): Record<string, unknown> {
  const decoded = wireDecodeResponse(payload);
  return decoded && typeof decoded === 'object' && !Array.isArray(decoded)
    ? decoded as Record<string, unknown>
    : {};
}

function invalidEventField(field: string, expected: string): never {
  throw new FlareSdkException('invalidParameter', `invalid event payload field: ${field}`, 'event.decode', { field, expected });
}

function requiredString(value: unknown, field: string): string {
  if (typeof value === 'string' && value.length > 0) return value;
  return invalidEventField(field, 'non-empty string');
}

function optionalString(value: unknown, field: string): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'string' && value.length > 0) return value;
  return invalidEventField(field, 'non-empty string');
}

function requiredNumber(value: unknown, field: string): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  return invalidEventField(field, 'finite number');
}

function optionalNumber(value: unknown, field: string): number | undefined {
  if (value === undefined || value === null) return undefined;
  return requiredNumber(value, field);
}

function requiredBoolean(value: unknown, field: string): boolean {
  if (typeof value === 'boolean') return value;
  return invalidEventField(field, 'boolean');
}

function optionalBoolean(value: unknown, field: string): boolean | undefined {
  if (value === undefined || value === null) return undefined;
  return requiredBoolean(value, field);
}

function requiredArray(value: unknown, field: string): unknown[] {
  if (Array.isArray(value)) return value;
  return invalidEventField(field, 'array');
}

function stringRecord(value: unknown, field: string): Record<string, string> {
  if (value === undefined || value === null) return {};
  const record = eventPayloadRecord(value);
  const out: Record<string, string> = {};
  for (const [key, item] of Object.entries(record)) {
    if (typeof item !== 'string') invalidEventField(`${field}.${key}`, 'string');
    out[key] = item;
  }
  return out;
}

/** The server's typed reason; empty for a local failure, which reads as no reason. */
function machineReasonFromJson(value: unknown): string | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'string') return value;
  return invalidEventField('error.machineReason', 'string');
}

function sdkErrorPayloadFromJson(value: unknown): SdkErrorPayload | undefined {
  if (value === undefined || value === null) return undefined;
  const decoded = wireDecodeResponse(value);
  if (typeof decoded === 'string') return undefined;
  if (!decoded || typeof decoded !== 'object' || Array.isArray(decoded)) invalidEventField('error', 'object');
  const record = decoded as Record<string, unknown>;
  return {
    code: requiredString(record.code, 'error.code'),
    machineReason: machineReasonFromJson(record.machineReason),
    message: requiredString(record.message, 'error.message'),
    operation: optionalString(record.operation, 'error.operation'),
    retryable: optionalBoolean(record.retryable, 'error.retryable'),
    details: stringRecord(record.details, 'error.details'),
  };
}

function nullableString(value: unknown, field: string): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'string') return value;
  return invalidEventField(field, 'string');
}

function requiredStringList(value: unknown, field: string): string[] {
  return requiredArray(value, field).map((item, index) => requiredString(item, `${field}.${index}`));
}

function enumValue<T extends string>(values: Record<string, T>, value: unknown, field: string): T {
  const known = Object.values(values) as string[];
  if (typeof value === 'string' && known.includes(value)) return value as T;
  return invalidEventField(field, known.join(' | '));
}

/** Decodes a `connection://status` payload. Absent and null fields are left out (never null). */
export function connectionStatusFromJson(payload: unknown): ConnectionStatus {
  const record = eventPayloadRecord(payload);
  const status: ConnectionStatus = {
    phase: enumValue(ConnectionPhase, record.phase, 'phase'),
    attempt: requiredNumber(record.attempt, 'attempt'),
    developmentMode: requiredBoolean(record.developmentMode, 'developmentMode'),
  };
  if (record.quality !== undefined && record.quality !== null) status.quality = enumValue(ConnectionQuality, record.quality, 'quality');
  const accessPointId = nullableString(record.accessPointId, 'accessPointId');
  if (accessPointId !== undefined) status.accessPointId = accessPointId;
  const cellId = nullableString(record.cellId, 'cellId');
  if (cellId !== undefined) status.cellId = cellId;
  const regionId = nullableString(record.regionId, 'regionId');
  if (regionId !== undefined) status.regionId = regionId;
  const protocol = nullableString(record.protocol, 'protocol');
  if (protocol !== undefined) status.protocol = protocol;
  const rttMs = optionalNumber(record.rttMs, 'rttMs');
  if (rttMs !== undefined) status.rttMs = rttMs;
  const nextRetryAt = optionalNumber(record.nextRetryAt, 'nextRetryAt');
  if (nextRetryAt !== undefined) status.nextRetryAt = nextRetryAt;
  const reason = nullableString(record.reason, 'reason');
  if (reason !== undefined) status.reason = reason;
  return status;
}

function accessEndpointFromJson(value: unknown, field: string): AccessEndpoint {
  if (!value || typeof value !== 'object' || Array.isArray(value)) invalidEventField(field, 'object');
  const record = value as Record<string, unknown>;
  return { ap: requiredString(record.ap, `${field}.ap`), protocol: requiredString(record.protocol, `${field}.protocol`) };
}

export function accessSwitchedEventFromJson(payload: unknown): AccessSwitchedEvent {
  const record = eventPayloadRecord(payload);
  return {
    from: accessEndpointFromJson(record.from, 'from'),
    to: accessEndpointFromJson(record.to, 'to'),
    reason: requiredString(record.reason, 'reason'),
  };
}

export function accessChangedEventFromJson(payload: unknown): AccessChangedEvent {
  const record = eventPayloadRecord(payload);
  const changes = record.changes;
  if (!changes || typeof changes !== 'object' || Array.isArray(changes)) invalidEventField('changes', 'object');
  const changeRecord = changes as Record<string, unknown>;
  const accessChanges: AccessChanges = {
    accessPointsAdded: requiredStringList(changeRecord.accessPointsAdded, 'changes.accessPointsAdded'),
    accessPointsRemoved: requiredStringList(changeRecord.accessPointsRemoved, 'changes.accessPointsRemoved'),
    policyChanged: requiredBoolean(changeRecord.policyChanged, 'changes.policyChanged'),
  };
  return {
    serial: requiredNumber(record.serial, 'serial'),
    source: requiredString(record.source, 'source'),
    stale: requiredBoolean(record.stale, 'stale'),
    developmentMode: requiredBoolean(record.developmentMode, 'developmentMode'),
    changes: accessChanges,
  };
}

function connectionStatusEvent(payload: unknown): ConnectionStatus & Record<string, unknown> {
  return { ...connectionStatusFromJson(payload), type: 'connection', event: ConnectionEventName.Status };
}

function connectionSyncStateEvent(payload: unknown): ConnectionSyncStateEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { type: 'connection', event: ConnectionEventName.SyncStateChanged, state: requiredString(record.state, 'state') };
}

function accessSwitchedEvent(payload: unknown): AccessSwitchedEvent & Record<string, unknown> {
  return { ...accessSwitchedEventFromJson(payload), type: 'access', event: AccessEventName.Switched };
}

function accessChangedEvent(payload: unknown): AccessChangedEvent & Record<string, unknown> {
  return { ...accessChangedEventFromJson(payload), type: 'access', event: AccessEventName.Changed };
}

function updateStateEvent(payload: unknown): UpdateStatus & Record<string, unknown> {
  return { ...(withoutNullFields(eventPayloadRecord(payload)) as unknown as UpdateStatus), type: 'update', event: UpdateEventName.State };
}

/** The event's own payload without the `type` / `event` routing keys the decoder adds. */
function eventPayloadOf<T>(event: unknown): T {
  const { type: _type, event: _event, ...payload } = event as Record<string, unknown>;
  return payload as T;
}

function messageReceivedEvent(payload: unknown): MessageReceivedEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { type: 'message', event: 'received', message: messageFromJson(record) };
}

function messageReceivedBatchEvent(payload: unknown): MessageReceivedBatchEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  const source = requiredArray(record.messages, 'messages');
  return { ...record, type: 'message', event: 'received_batch', messages: source.map((item) => messageFromJson(item)) };
}

function messageSendAckEvent(payload: unknown): MessageSendAckEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { ...record, type: 'message', event: 'send_ack', ack: sendAckFromJson(record) };
}

function messageSendFailedEvent(payload: unknown): MessageSendFailedEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  const { error: rawError, ...rest } = record;
  const error = sdkErrorPayloadFromJson(rawError);
  return {
    ...rest,
    type: 'message',
    event: 'send_failed',
    clientMsgId: requiredString(record.clientMsgId, 'clientMsgId'),
    reason: requiredString(record.reason, 'reason'),
    ...(error ? { error } : {}),
  };
}

function messageMutationEvent(name: MessageEventName, event: string, payload: unknown): MessageMutationEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return {
    ...record,
    type: 'message',
    event,
    name,
    conversationId: requiredString(record.conversationId, 'conversationId'),
    messageId: optionalString(record.messageId, 'messageId'),
    serverMsgId: optionalString(record.serverMsgId, 'serverMsgId'),
    userId: optionalString(record.userId, 'userId'),
    reason: optionalString(record.reason, 'reason'),
  };
}

function typingEvent(payload: unknown): TypingEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { ...record, type: 'message', event: 'typing', conversationId: requiredString(record.conversationId, 'conversationId'), userId: requiredString(record.userId, 'userId'), typing: requiredBoolean(record.typing, 'typing') };
}

function typingAggregateEvent(payload: unknown): TypingAggregateEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  const typingUserIds = requiredArray(record.typingUserIds, 'typingUserIds').map((item, index) => requiredString(item, `typingUserIds.${index}`));
  return { ...record, type: 'message', event: 'typing_aggregate', name: MessageEventName.TypingAggregate, conversationId: requiredString(record.conversationId, 'conversationId'), typingUserIds, typingCount: requiredNumber(record.typingCount, 'typingCount') };
}

function readReceiptEvent(payload: unknown): ReadReceiptEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { ...record, type: 'message', event: 'read_receipt', conversationId: requiredString(record.conversationId, 'conversationId'), userId: requiredString(record.userId, 'userId'), readSeq: requiredNumber(record.readSeq, 'readSeq') };
}

function reactionChangedEvent(payload: unknown): ReactionChangedEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { ...record, type: 'message', event: 'reaction_changed', conversationId: requiredString(record.conversationId, 'conversationId'), serverMsgId: requiredString(record.serverMsgId, 'serverMsgId'), userId: requiredString(record.userId, 'userId'), emoji: requiredString(record.emoji, 'emoji'), action: requiredNumber(record.action, 'action') };
}

function presenceChangedEvent(payload: unknown): PresenceChangedEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { ...record, type: 'presence', event: 'changed', conversationId: optionalString(record.conversationId, 'conversationId'), userId: requiredString(record.userId, 'userId'), status: requiredString(record.status, 'status'), extra: stringRecord(record.extra, 'extra') };
}

function pluginRealtimeEvent(payload: unknown): PluginRealtimeEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  const body = record.payload;
  if (!body || typeof body !== 'object' || Array.isArray(body)) invalidEventField('payload', 'object');
  return {
    type: 'plugin',
    event: PluginEventName.Realtime,
    pluginId: requiredString(record.pluginId, 'pluginId'),
    packetType: requiredString(record.packetType, 'packetType'),
    conversationId: requiredString(record.conversationId, 'conversationId'),
    payload: body as Record<string, unknown>,
    deliveryId: requiredString(record.deliveryId, 'deliveryId'),
    expiresAtMs: requiredNumber(record.expiresAtMs, 'expiresAtMs'),
  };
}

function pluginCatalogChangedEvent(payload: unknown): PluginCatalogChangedEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { type: 'plugin', event: PluginEventName.CatalogChanged, version: requiredString(record.version, 'version') };
}

function conversationEvent(name: ConversationEventName, event: string, payload: unknown): ConversationEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  const conversationId = optionalString(record.conversationId, 'conversationId');
  const conversationIds = Array.isArray(record.conversationIds)
    ? record.conversationIds.map((item, index) => requiredString(item, `conversationIds.${index}`))
    : conversationId ? [conversationId] : [];
  return { ...record, type: 'conversation', event, name, conversationId, conversationIds, unreadCount: optionalNumber(record.unreadCount, 'unreadCount') };
}

function syncEvent(name: SyncEventName, event: string, payload: unknown): SyncEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  const { error: rawError, ...rest } = record;
  const error = sdkErrorPayloadFromJson(rawError);
  return {
    ...rest,
    type: 'sync',
    event,
    name,
    trigger: optionalString(record.trigger, 'trigger'),
    phase: optionalString(record.phase, 'phase'),
    task: optionalString(record.task, 'task'),
    progress: optionalNumber(record.progress, 'progress'),
    ...(error ? { error } : {}),
    ...(typeof rawError === 'string' ? { message: rawError } : {}),
  };
}

function syncProgressEvent(payload: unknown): SdkProgressEvent & Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  const progress = requiredNumber(record.progress, 'progress');
  return {
    ...record,
    type: 'sync',
    event: 'progress',
    name: ProgressEventName.SyncProgress,
    operation: optionalString(record.task, 'task') ?? 'sync',
    current: progress,
    total: 100,
    taskId: optionalString(record.task, 'task'),
    detail: optionalString(record.detail, 'detail'),
  };
}

function viewUpdatedEvent(payload: unknown): ViewUpdate & Record<string, unknown> {
  return { ...viewUpdateFromJson(wireDecodeResponse(payload)), type: 'view', event: 'updated' };
}

function notificationReceivedEvent(payload: unknown): Record<string, unknown> {
  const record = eventPayloadRecord(payload);
  return { type: 'notification', event: 'received', message: messageFromJson(record) };
}

function contractEvent(type: string, event: string, payload: unknown): Record<string, unknown> {
  return { ...eventPayloadRecord(payload), type, event };
}

function emittedEventRecord(event: unknown): { type?: unknown; event?: unknown; name?: unknown } {
  return event && typeof event === 'object'
    ? event as { type?: unknown; event?: unknown; name?: unknown }
    : {};
}

function eventTypeIs(event: unknown, type: string): boolean {
  return String(emittedEventRecord(event).type ?? '') === type;
}

function eventEventIs(event: unknown, type: string, eventName: string): boolean {
  const record = emittedEventRecord(event);
  return String(record.type ?? '') === type && String(record.event ?? '') === eventName;
}

function eventNameIs(event: unknown, type: string, name: string): boolean {
  const record = emittedEventRecord(event);
  return String(record.type ?? '') === type && String(record.name ?? '') === name;
}

function lifecycleNameIs(event: unknown, name: string): boolean {
  return String(emittedEventRecord(event).name ?? '') === name;
}

export function nativeEventFromCode(eventType: number, payload: unknown): unknown {
  switch (eventType) {
    case EVENT_CODE_CONNECTION_SYNC_STATE_CHANGED: return connectionSyncStateEvent(payload);
    case EVENT_CODE_CONNECTION_STATUS: return connectionStatusEvent(payload);
    case EVENT_CODE_ACCESS_SWITCHED: return accessSwitchedEvent(payload);
    case EVENT_CODE_ACCESS_CHANGED: return accessChangedEvent(payload);
    case EVENT_CODE_UPDATE_STATE: return updateStateEvent(payload);
    case EVENT_CODE_MESSAGE_RECEIVED: return messageReceivedEvent(payload);
    case EVENT_CODE_MESSAGE_RECEIVED_BATCH: return messageReceivedBatchEvent(payload);
    case EVENT_CODE_MESSAGE_SEND_ACK: return messageSendAckEvent(payload);
    case EVENT_CODE_MESSAGE_SEND_FAILED: return messageSendFailedEvent(payload);
    case EVENT_CODE_MESSAGE_RECALLED: return messageMutationEvent(MessageEventName.Recalled, "recalled", payload);
    case EVENT_CODE_MESSAGE_TYPING: return typingEvent(payload);
    case EVENT_CODE_MESSAGE_EDITED: return messageMutationEvent(MessageEventName.Edited, "edited", payload);
    case EVENT_CODE_MESSAGE_REACTION_CHANGED: return reactionChangedEvent(payload);
    case EVENT_CODE_MESSAGE_DELETED: return messageMutationEvent(MessageEventName.Deleted, "deleted", payload);
    case EVENT_CODE_MESSAGE_READ_RECEIPT: return readReceiptEvent(payload);
    case EVENT_CODE_MESSAGE_RETENTION_SCHEDULED: return messageMutationEvent(MessageEventName.RetentionScheduled, "retention_scheduled", payload);
    case EVENT_CODE_MESSAGE_RETENTION_EXPIRED: return messageMutationEvent(MessageEventName.RetentionExpired, "retention_expired", payload);
    case EVENT_CODE_MESSAGE_RETENTION_PURGED: return messageMutationEvent(MessageEventName.RetentionPurged, "retention_purged", payload);
    case EVENT_CODE_MESSAGE_PINNED: return messageMutationEvent(MessageEventName.Pinned, "pinned", payload);
    case EVENT_CODE_MESSAGE_UNPINNED: return messageMutationEvent(MessageEventName.Unpinned, "unpinned", payload);
    case EVENT_CODE_MESSAGE_MARKED: return messageMutationEvent(MessageEventName.Marked, "marked", payload);
    case EVENT_CODE_MESSAGE_UNMARKED: return messageMutationEvent(MessageEventName.Unmarked, "unmarked", payload);
    case EVENT_CODE_MESSAGE_PRESENCE_CHANGED: return presenceChangedEvent(payload);
    case EVENT_CODE_MESSAGE_CUSTOM: return contractEvent("message", "custom", payload);
    case EVENT_CODE_MESSAGE_TYPING_AGGREGATE: return typingAggregateEvent(payload);
    case EVENT_CODE_MESSAGE_PLUGIN_STATE_CHANGED: return messageMutationEvent(MessageEventName.PluginStateChanged, "plugin_state_changed", payload);
    case EVENT_CODE_MESSAGE_READ_SUMMARIES_CHANGED: return undefined;
    case EVENT_CODE_CONVERSATION_SYNCED: return conversationEvent(ConversationEventName.Synced, "synced", payload);
    case EVENT_CODE_CONVERSATION_CREATED: return conversationEvent(ConversationEventName.Created, "created", payload);
    case EVENT_CODE_CONVERSATION_UPDATED: return conversationEvent(ConversationEventName.Updated, "updated", payload);
    case EVENT_CODE_CONVERSATION_UNREAD_COUNT_CHANGED: return conversationEvent(ConversationEventName.UnreadCountChanged, "unread_count_changed", payload);
    case EVENT_CODE_CONVERSATION_DELETED: return conversationEvent(ConversationEventName.Deleted, "deleted", payload);
    case EVENT_CODE_NOTIFICATION_RECEIVED: return notificationReceivedEvent(payload);
    case EVENT_CODE_NOTIFICATION_MESSAGE_SOUND: return undefined;
    case EVENT_CODE_SYNC_STARTED: return syncEvent(SyncEventName.Started, "started", payload);
    case EVENT_CODE_SYNC_FINISHED: return syncEvent(SyncEventName.Finished, "finished", payload);
    case EVENT_CODE_SYNC_FAILED: return syncEvent(SyncEventName.Failed, "failed", payload);
    case EVENT_CODE_SYNC_PROGRESS: return syncProgressEvent(payload);
    case EVENT_CODE_SYNC_TASK_COMPLETED: return syncEvent(SyncEventName.TaskCompleted, "task_completed", payload);
    case EVENT_CODE_SYNC_STATE_CHANGED: return syncEvent(SyncEventName.StateChanged, "state_changed", payload);
    case EVENT_CODE_SYNC_RESYNC_NEEDED: return syncEvent(SyncEventName.ResyncNeeded, "resync_needed", payload);
    case EVENT_CODE_SYNC_READINESS: return undefined;
    case EVENT_CODE_EXTENSION_EVENT: return contractEvent("extension", "event", payload);
    case EVENT_CODE_VIEW_UPDATED: return viewUpdatedEvent(payload);
    case EVENT_CODE_PLUGIN_REALTIME: return pluginRealtimeEvent(payload);
    case EVENT_CODE_PLUGIN_CATALOG_CHANGED: return pluginCatalogChangedEvent(payload);
    default: return {
      type: 'unknown',
      name: 'unknown',
      event: 'unknown',
      eventType,
      payload,
    };
  }
}

class DefaultEventSubscription implements EventSubscription {
  constructor(
    readonly id: string,
    private readonly onDispose: () => void,
    public handler?: unknown,
  ) {}

  unsubscribe(): void {
    this.onDispose();
  }
}

export class DefaultEventsApi implements EventsApi {
  private subscriptions: Map<number, DefaultEventSubscription> = new Map();
  private nextId = 1;

  constructor(private readonly bridge: NativeBridge) {}

  async subscribeEvents(request: SubscribeEventsRequest): Promise<Subscription> {
    return this.bridge.invoke<Subscription>(NativeCallMap.eventSubscribe, this.requestWithDefaultHandler(request));
  }

  async subscribeEventsBatch(request: SubscribeEventsRequest): Promise<Subscription> {
    return this.bridge.invoke<Subscription>(NativeCallMap.eventSubscribeBatch, this.requestWithDefaultHandler(request));
  }

  async unsubscribe(request: Record<string, unknown>): Promise<void> {
    await this.bridge.invoke<void>(NativeCallMap.eventUnsubscribe, request);
  }

  async unsubscribeAll(): Promise<void> {
    this.subscriptions.clear();
    await this.bridge.invoke<void>(NativeCallMap.eventUnsubscribeAll);
  }

  emit(event: unknown): void {
    const subscriptions = this.subscriptions;
    if (subscriptions.size === 0) {
      return;
    }
    // Fast path: a single subscription (the common case) needs no snapshot allocation.
    if (subscriptions.size === 1) {
      const handler = subscriptions.values().next().value?.handler;
      if (handler) {
        this.dispatchSafely(handler, event);
      }
      return;
    }
    // Snapshot so listeners added/removed during dispatch don't change this fan-out.
    for (const subscription of Array.from(subscriptions.values())) {
      if (subscription.handler) {
        this.dispatchSafely(subscription.handler, event);
      }
    }
  }

  private dispatchSafely(handler: unknown, event: unknown): void {
    try {
      if (typeof handler === 'function') {
        (handler as EventCallback<unknown>)(event);
      } else {
        this.dispatchToListener(handler as FlareImEventListener, event);
      }
    } catch (error) {
      console.error('[flare-core] event listener failed', error);
    }
  }

  addEventListener(listener: FlareImEventListener): EventSubscription {
    return this.register(listener);
  }

  removeEventListener(subscription: EventSubscription): void {
    subscription.unsubscribe();
  }

  emitNativeEvent(eventType: number, payload: unknown): void {
    this.emit(nativeEventFromCode(eventType, payload));
  }

  onInitializing(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => lifecycleNameIs(event, LifecycleEventName.Initializing));
  }

  onInitialized(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => lifecycleNameIs(event, LifecycleEventName.Initialized));
  }

  onInitFailed(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => lifecycleNameIs(event, LifecycleEventName.InitFailed));
  }

  onLoginSucceeded(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => lifecycleNameIs(event, LifecycleEventName.LoginSucceeded));
  }

  onLoginFailed(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => lifecycleNameIs(event, LifecycleEventName.LoginFailed));
  }

  onLoggedOut(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => lifecycleNameIs(event, LifecycleEventName.LoggedOut));
  }

  onDisposed(listener: EventCallback<LifecycleEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => lifecycleNameIs(event, LifecycleEventName.Disposed));
  }

  onConnectionStatusChanged(listener: EventCallback<ConnectionStatus>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'connection', ConnectionEventName.Status), eventPayloadOf);
  }

  onAccessSwitched(listener: EventCallback<AccessSwitchedEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'access', AccessEventName.Switched), eventPayloadOf);
  }

  onAccessChanged(listener: EventCallback<AccessChangedEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'access', AccessEventName.Changed), eventPayloadOf);
  }

  onUpdateState(listener: EventCallback<UpdateStatus>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'update', UpdateEventName.State), eventPayloadOf);
  }

  onMessageReceived(listener: EventCallback<MessageReceivedEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.Received));
  }

  onMessageReceivedBatch(listener: EventCallback<MessageReceivedBatchEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.ReceivedBatch));
  }

  onMessageSendAck(listener: EventCallback<MessageSendAckEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.SendAck));
  }

  onMessageSendFailed(listener: EventCallback<MessageSendFailedEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.SendFailed));
  }

  onMessageRecalled(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'message', MessageEventName.Recalled));
  }

  onMessageEdited(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'message', MessageEventName.Edited));
  }

  onMessageDeleted(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'message', MessageEventName.Deleted));
  }

  onMessageReadReceipt(listener: EventCallback<ReadReceiptEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.ReadReceipt));
  }

  onMessageReactionChanged(listener: EventCallback<ReactionChangedEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.ReactionChanged));
  }

  onInputStatusChanged(listener: EventCallback<TypingEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.Typing));
  }

  onTypingAggregateChanged(listener: EventCallback<TypingAggregateEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'message', MessageEventName.TypingAggregate));
  }

  onMessageBurned(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'message', MessageEventName.Burned));
  }

  onMessagePinned(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'message', MessageEventName.Pinned));
  }

  onMessageUnpinned(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'message', MessageEventName.Unpinned));
  }

  onMessagePluginStateChanged(listener: EventCallback<MessageMutationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'message', MessageEventName.PluginStateChanged));
  }

  onViewUpdated(listener: EventCallback<ViewUpdate>): EventSubscription {
    return this.registerWhere(listener, (event) => eventTypeIs(event, 'view'));
  }

  onNewConversation(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'conversation', ConversationEventName.Created));
  }

  onConversationChanged(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventTypeIs(event, 'conversation'));
  }

  onTotalUnreadMessageCountChanged(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'conversation', ConversationEventName.UnreadCountChanged));
  }

  onConversationDeleted(listener: EventCallback<ConversationEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'conversation', ConversationEventName.Deleted));
  }

  onSyncServerStart(listener: EventCallback<SyncEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'sync', SyncEventName.Started));
  }

  onSyncServerFinish(listener: EventCallback<SyncEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'sync', SyncEventName.Finished));
  }

  onSyncServerFailed(listener: EventCallback<SyncEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'sync', SyncEventName.Failed));
  }

  onSyncProgress(listener: EventCallback<SdkProgressEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'sync', ProgressEventName.SyncProgress));
  }

  onUploadProgress(listener: EventCallback<SdkProgressEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'progress', ProgressEventName.UploadProgress));
  }

  onDownloadProgress(listener: EventCallback<SdkProgressEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventNameIs(event, 'progress', ProgressEventName.DownloadProgress));
  }

  onPluginRealtime(listener: EventCallback<PluginRealtimeEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'plugin', PluginEventName.Realtime));
  }

  onPluginCatalogChanged(listener: EventCallback<PluginCatalogChangedEvent>): EventSubscription {
    return this.registerWhere(listener, (event) => eventEventIs(event, 'plugin', PluginEventName.CatalogChanged));
  }

  private requestWithDefaultHandler(request: SubscribeEventsRequest): SubscribeEventsRequest {
    const record = request as Record<string, unknown>;
    if (record.handler !== undefined) {
      return request;
    }
    return {
      ...record,
      handler: (eventType: number, payload: unknown) => this.emitNativeEvent(eventType, payload),
    } as SubscribeEventsRequest;
  }

  private register(handler: unknown): EventSubscription {
    const subscriptionId = this.nextId++;
    const subscription = new DefaultEventSubscription(
      subscriptionId.toString(),
      () => this.subscriptions.delete(subscriptionId),
      handler,
    );
    this.subscriptions.set(subscriptionId, subscription);
    return subscription;
  }

  private registerTyped<T>(listener: EventCallback<T>): EventSubscription {
    return this.register((event: unknown) => {
      listener(event as T);
    });
  }

  private registerWhere<T>(
    listener: EventCallback<T>,
    predicate: (event: unknown) => boolean,
    project: (event: unknown) => T = (event) => event as T,
  ): EventSubscription {
    return this.register((event: unknown) => {
      if (predicate(event)) {
        listener(project(event));
      }
    });
  }

  private dispatchToListener(listener: FlareImEventListener, event: unknown): void {
    const record = event && typeof event === 'object'
      ? event as { type?: unknown; event?: unknown; name?: unknown; state?: unknown }
      : {};
    const type = String(record.type ?? '');
    const eventName = String(record.event ?? '');
    const name = String(record.name ?? '');
    if (type === 'message') {
      switch (eventName) {
        case MessageEventName.Received:
          listener.onMessageReceived?.(event as MessageReceivedEvent);
          return;
        case MessageEventName.ReceivedBatch:
          listener.onMessageReceivedBatch?.(event as MessageReceivedBatchEvent);
          return;
        case MessageEventName.SendAck:
          listener.onMessageSendAck?.(event as MessageSendAckEvent);
          return;
        case MessageEventName.SendFailed:
          listener.onMessageSendFailed?.(event as MessageSendFailedEvent);
          return;
        case MessageEventName.Recalled:
          listener.onMessageRecalled?.(event as MessageMutationEvent);
          return;
        case MessageEventName.Edited:
          listener.onMessageEdited?.(event as MessageMutationEvent);
          return;
        case MessageEventName.Deleted:
          listener.onMessageDeleted?.(event as MessageMutationEvent);
          return;
        case MessageEventName.ReadReceipt:
          listener.onMessageReadReceipt?.(event as ReadReceiptEvent);
          return;
        case MessageEventName.ReactionChanged:
          listener.onMessageReactionChanged?.(event as ReactionChangedEvent);
          return;
        case MessageEventName.Typing:
          listener.onInputStatusChanged?.(event as TypingEvent);
          return;
        case MessageEventName.Burned:
        case MessageEventName.RetentionExpired:
        case MessageEventName.RetentionPurged:
          listener.onMessageBurned?.(event as MessageMutationEvent);
          return;
        case MessageEventName.Pinned:
          listener.onMessagePinned?.(event as MessageMutationEvent);
          return;
        case MessageEventName.Unpinned:
          listener.onMessageUnpinned?.(event as MessageMutationEvent);
          return;
        case MessageEventName.PluginStateChanged:
          listener.onMessagePluginStateChanged?.(event as MessageMutationEvent);
          return;
        default:
          return;
      }
    }
    if (type === 'conversation') {
      switch (name) {
        case ConversationEventName.Created:
          listener.onNewConversation?.(event as ConversationEvent);
          return;
        case ConversationEventName.Deleted:
          listener.onConversationDeleted?.(event as ConversationEvent);
          return;
        case ConversationEventName.UnreadCountChanged:
          listener.onTotalUnreadMessageCountChanged?.(event as ConversationEvent);
          return;
        default:
          listener.onConversationChanged?.(event as ConversationEvent);
          return;
      }
    }
    if (type === 'sync') {
      if (name === ProgressEventName.SyncProgress) {
        listener.onSyncProgress?.(event as SdkProgressEvent);
        return;
      }
      switch (name) {
        case SyncEventName.Started:
          listener.onSyncServerStart?.(event as SyncEvent);
          return;
        case SyncEventName.Finished:
          listener.onSyncServerFinish?.(event as SyncEvent);
          return;
        case SyncEventName.Failed:
          listener.onSyncServerFailed?.(event as SyncEvent);
          return;
        default:
          return;
      }
    }
    if (type === 'connection') {
      if (eventName === ConnectionEventName.Status) {
        listener.onConnectionStatusChanged?.(eventPayloadOf<ConnectionStatus>(event));
      }
      return;
    }
    if (type === 'access') {
      switch (eventName) {
        case AccessEventName.Switched:
          listener.onAccessSwitched?.(eventPayloadOf<AccessSwitchedEvent>(event));
          return;
        case AccessEventName.Changed:
          listener.onAccessChanged?.(eventPayloadOf<AccessChangedEvent>(event));
          return;
        default:
          return;
      }
    }
    if (type === 'update') {
      if (eventName === UpdateEventName.State) listener.onUpdateState?.(eventPayloadOf<UpdateStatus>(event));
      return;
    }
    if (type === 'view') {
      listener.onViewUpdated?.(event as ViewUpdate);
      return;
    }
    if (type === 'plugin') {
      switch (eventName) {
        case PluginEventName.Realtime:
          listener.onPluginRealtime?.(event as PluginRealtimeEvent);
          return;
        case PluginEventName.CatalogChanged:
          listener.onPluginCatalogChanged?.(event as PluginCatalogChangedEvent);
          return;
        default:
          return;
      }
    }
    if ((event as LifecycleEvent).name !== undefined) {
      const lifecycle = event as LifecycleEvent;
      switch (lifecycle.name) {
        case LifecycleEventName.Initializing:
          listener.onInitializing?.(lifecycle);
          break;
        case LifecycleEventName.Initialized:
          listener.onInitialized?.(lifecycle);
          break;
        case LifecycleEventName.InitFailed:
          listener.onInitFailed?.(lifecycle);
          break;
        case LifecycleEventName.LoginSucceeded:
          listener.onLoginSucceeded?.(lifecycle);
          break;
        case LifecycleEventName.LoginFailed:
          listener.onLoginFailed?.(lifecycle);
          break;
        case LifecycleEventName.LoggedOut:
          listener.onLoggedOut?.(lifecycle);
          break;
        case LifecycleEventName.Disposed:
          listener.onDisposed?.(lifecycle);
          break;
        default:
          break;
      }
      return;
    }
  }
}
