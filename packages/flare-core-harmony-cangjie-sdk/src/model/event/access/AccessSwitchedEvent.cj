package flare_core_harmony_cangjie_sdk.model.event.access

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Payload of access://switched: the IM connection moved to another access point (sent once, when the new connection is ready).
public class AccessSwitchedEvent {
    // wire: `from`. Where the connection was.
    public let from: AccessEndpoint
    // wire: `to`. Where the connection is now.
    public let to: AccessEndpoint
    // wire: `reason`. Why: failure, drain, failback, manual or manifest.
    public let reason: String

    public init(from!: AccessEndpoint, to!: AccessEndpoint, reason!: String) {
        this.from = from
        this.to = to
        this.reason = reason
    }
}
