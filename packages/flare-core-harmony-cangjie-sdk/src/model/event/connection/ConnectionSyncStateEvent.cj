package flare_core_harmony_cangjie_sdk.model.event.connection

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Payload of the coarse sync state hint (connection.sync_state_changed). Connection status itself arrives as ConnectionStatus.
public class ConnectionSyncStateEvent {
    // wire: `state`. The core sync state name.
    public let state: String

    public init(state!: String) {
        this.state = state
    }
}
