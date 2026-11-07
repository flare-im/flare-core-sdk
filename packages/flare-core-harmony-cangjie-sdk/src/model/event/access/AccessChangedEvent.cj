package flare_core_harmony_cangjie_sdk.model.event.access

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Payload of access://changed: a new access manifest was accepted. Sent for every adoption; a periodic re-signature has empty changes.
public class AccessChangedEvent {
    // wire: `serial`. Serial of the accepted manifest.
    public let serial: UInt64
    // wire: `source`. Where it came from, in the form of AccessStatus.source.
    public let source: String
    // wire: `stale`. Whether it is past its expiry.
    public let stale: Bool
    // wire: `developmentMode`. Endpoints come from development-mode configuration.
    public let developmentMode: Bool
    // wire: `changes`. What changed against the previous manifest.
    public let changes: AccessChanges

    public init(serial!: UInt64, source!: String, stale!: Bool, developmentMode!: Bool, changes!: AccessChanges) {
        this.serial = serial
        this.source = source
        this.stale = stale
        this.developmentMode = developmentMode
        this.changes = changes
    }
}
