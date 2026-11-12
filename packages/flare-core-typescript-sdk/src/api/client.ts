/**
 * GENERATED. Do not edit by hand.
 *
 * Root client facade composing per-module APIs from `./modules/`.
 */
import type { SessionApi } from './modules/session';
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

/** Root SDK client. Create one instance per app/session boundary. */
export interface FlareImClient extends SessionApi {
  /** Connection status and manual network lifecycle. */
  readonly connection: ConnectionApi;
  /** Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page. */
  readonly access: AccessApi;
  /** Platform lifecycle signals the core needs (foreground and background). */
  readonly lifecycle: LifecycleApi;
  /** Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors. */
  readonly update: UpdateApi;
  /** Conversation query and local conversation state. */
  readonly conversations: ConversationsApi;
  /** Typed quick-build APIs for all supported message content kinds. Prefer these over raw JSON in adapters. */
  readonly messageBuilder: MessageBuilderApi;
  /** Message build, send, query and mutation. */
  readonly messages: MessagesApi;
  /** Explicit sync operations. */
  readonly sync: SyncApi;
  /** User profile cache (business-fed identity for messages and conversations). */
  readonly user: UserApi;
  /** Presence and input state. */
  readonly presence: PresenceApi;
  /** Media access URL and local cache operations. */
  readonly media: MediaApi;
  /** Capability discovery and optional plugin dispatch through capability dispatch ops. */
  readonly capabilities: CapabilitiesApi;
  /** Core observable message/conversation views. */
  readonly views: ViewsApi;
  /** Typed SDK event stream. */
  readonly events: EventsApi;
  /** SDK version and FFI contract diagnostics. */
  readonly diagnostics: DiagnosticsApi;
  /** Notifications while the live link is up: which conversation is on screen, the user's notification settings, and whether the platform presents alerts in the background. The engine decides and renders every alert itself and hands it over as notification.present, notification.clear and notification.badge events. */
  readonly notification: NotificationApi;
}
