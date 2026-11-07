package com.flare.im.api

import com.flare.im.api.session.SessionApi
import com.flare.im.api.connection.ConnectionApi
import com.flare.im.api.access.AccessApi
import com.flare.im.api.lifecycle.LifecycleApi
import com.flare.im.api.update.UpdateApi
import com.flare.im.api.conversations.ConversationsApi
import com.flare.im.api.messagebuilder.MessageBuilderApi
import com.flare.im.api.messages.MessagesApi
import com.flare.im.api.sync.SyncApi
import com.flare.im.api.user.UserApi
import com.flare.im.api.presence.PresenceApi
import com.flare.im.api.media.MediaApi
import com.flare.im.api.capabilities.CapabilitiesApi
import com.flare.im.api.views.ViewsApi
import com.flare.im.api.events.EventsApi
import com.flare.im.api.diagnostics.DiagnosticsApi

/** GENERATED. Do not edit by hand. */
/** Root SDK client. Create one instance per app/session boundary. */
interface FlareImClient : SessionApi {
    /** Connection status and manual network lifecycle. */
    val connection: ConnectionApi
    /** Access directory, access point health, manual pinning, manifest refresh and recovery links for the network diagnostics page. */
    val access: AccessApi
    /** Platform lifecycle signals the core needs (foreground and background). */
    val lifecycle: LifecycleApi
    /** Update center: release evaluation, download and the install plan. Works before sign-in and with every IM node down; the release manifest comes from the access mirrors. */
    val update: UpdateApi
    /** Conversation query and local conversation state. */
    val conversations: ConversationsApi
    /** Typed quick-build APIs for all supported message content kinds. Prefer these over raw JSON in adapters. */
    val messageBuilder: MessageBuilderApi
    /** Message build, send, query and mutation. */
    val messages: MessagesApi
    /** Explicit sync operations. */
    val sync: SyncApi
    /** User profile cache (business-fed identity for messages and conversations). */
    val user: UserApi
    /** Presence and input state. */
    val presence: PresenceApi
    /** Media access URL and local cache operations. */
    val media: MediaApi
    /** Capability discovery and optional plugin dispatch through capability dispatch ops. */
    val capabilities: CapabilitiesApi
    /** Core observable message/conversation views. */
    val views: ViewsApi
    /** Typed SDK event stream. */
    val events: EventsApi
    /** SDK version and FFI contract diagnostics. */
    val diagnostics: DiagnosticsApi
}
