package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Result of accepting a new set of addresses. Link readiness is reported separately through normal connection status.
public class EndpointUpdate {
    // wire: `changed`. 
    public let changed: Bool
    // wire: `revision`. Accepted endpoint generation for this initialized client.
    public let revision: UInt32

    public init(changed!: Bool, revision!: UInt32) {
        this.changed = changed
        this.revision = revision
    }
}
