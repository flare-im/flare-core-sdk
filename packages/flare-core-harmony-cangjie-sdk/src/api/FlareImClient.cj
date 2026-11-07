package flare_core_harmony_cangjie_sdk.api

import flare_core_harmony_cangjie_sdk.api.modules.*

// GENERATED. Do not edit by hand.
public interface FlareImClient <: SessionApi {
    prop connection: ConnectionApi
    prop access: AccessApi
    prop lifecycle: LifecycleApi
    prop update: UpdateApi
    prop conversations: ConversationsApi
    prop messageBuilder: MessageBuilderApi
    prop messages: MessagesApi
    prop sync: SyncApi
    prop user: UserApi
    prop presence: PresenceApi
    prop media: MediaApi
    prop capabilities: CapabilitiesApi
    prop views: ViewsApi
    prop events: EventsApi
    prop diagnostics: DiagnosticsApi
}
