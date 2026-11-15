// GENERATED. Do not edit by hand.
import { SessionApi } from './modules/session';
import type { ConnectionApi } from './modules/connection';
import type { AccessApi } from './modules/access';
import type { LifecycleApi } from './modules/lifecycle';
import type { UpdateApi } from './modules/update';
import type { ConversationsApi } from './modules/conversations';
import type { MessageBuilderApi } from './modules/message_builder';
import type { MessagesApi } from './modules/messages';
import type { SyncApi } from './modules/sync';
import type { UserApi } from './modules/user';
import type { PresenceApi } from './modules/presence';
import type { MediaApi } from './modules/media';
import type { CapabilitiesApi } from './modules/capabilities';
import type { ViewsApi } from './modules/views';
import type { EventsApi } from './modules/events';
import type { DiagnosticsApi } from './modules/diagnostics';
import type { NotificationApi } from './modules/notification';

export interface FlareImClient extends SessionApi {
  readonly connection: ConnectionApi;
  readonly access: AccessApi;
  readonly lifecycle: LifecycleApi;
  readonly update: UpdateApi;
  readonly conversations: ConversationsApi;
  readonly messageBuilder: MessageBuilderApi;
  readonly messages: MessagesApi;
  readonly sync: SyncApi;
  readonly user: UserApi;
  readonly presence: PresenceApi;
  readonly media: MediaApi;
  readonly capabilities: CapabilitiesApi;
  readonly views: ViewsApi;
  readonly events: EventsApi;
  readonly diagnostics: DiagnosticsApi;
  readonly notification: NotificationApi;
}
