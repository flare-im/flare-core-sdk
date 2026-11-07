package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Download progress.
public class UpdateProgress {
    // wire: `received`. Bytes received.
    public let received: UInt64
    // wire: `total`. Bytes in all.
    public let total: UInt64

    public init(received!: UInt64, total!: UInt64) {
        this.received = received
        this.total = total
    }
}
