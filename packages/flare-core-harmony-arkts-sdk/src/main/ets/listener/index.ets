// GENERATED. Do not edit by hand.
export * from './common';
export * from './access';
export * from './connection';
export * from './conversation';
export * from './lifecycle';
export * from './media';
export * from './message';
export * from './notification';
export * from './plugin';
export * from './sync';
export * from './update';
export * from './view';

import { AccessEventListener } from './access';
import { ConnectionEventListener } from './connection';
import { ConversationEventListener } from './conversation';
import { LifecycleEventListener } from './lifecycle';
import { MediaEventListener } from './media';
import { MessageEventListener } from './message';
import { NotificationEventListener } from './notification';
import { PluginEventListener } from './plugin';
import { SyncEventListener } from './sync';
import { UpdateEventListener } from './update';
import { ViewEventListener } from './view';

/** Optional callback surface for apps that prefer one listener object. */
export interface FlareImEventListener extends AccessEventListener, ConnectionEventListener, ConversationEventListener, LifecycleEventListener, MediaEventListener, MessageEventListener, NotificationEventListener, PluginEventListener, SyncEventListener, UpdateEventListener, ViewEventListener {}
