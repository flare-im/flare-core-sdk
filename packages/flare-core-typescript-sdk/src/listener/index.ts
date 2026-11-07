/** GENERATED. Do not edit by hand. */
export * from './common';
export * from './access';
export * from './connection';
export * from './conversation';
export * from './lifecycle';
export * from './media';
export * from './message';
export * from './plugin';
export * from './sync';
export * from './update';
export * from './view';

import type { AccessEventListener } from './access';
import type { ConnectionEventListener } from './connection';
import type { ConversationEventListener } from './conversation';
import type { LifecycleEventListener } from './lifecycle';
import type { MediaEventListener } from './media';
import type { MessageEventListener } from './message';
import type { PluginEventListener } from './plugin';
import type { SyncEventListener } from './sync';
import type { UpdateEventListener } from './update';
import type { ViewEventListener } from './view';

/** Optional callback surface for apps that prefer one listener object. */
export interface FlareImEventListener extends AccessEventListener, ConnectionEventListener, ConversationEventListener, LifecycleEventListener, MediaEventListener, MessageEventListener, PluginEventListener, SyncEventListener, UpdateEventListener, ViewEventListener {}
