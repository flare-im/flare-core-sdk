package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Recovery state while every access point has failed.
public class AccessRecoveringStatus {
    // wire: `sinceMs`. When recovery began, Unix milliseconds.
    public let sinceMs: Int64
    // wire: `rounds`. Bootstrap rounds run so far.
    public let rounds: UInt32
    // wire: `nextRoundAtMs`. Optional. When the next round runs, Unix milliseconds; absent while the device has no network.
    public let nextRoundAtMs: ?Int64

    public init(sinceMs!: Int64, rounds!: UInt32, nextRoundAtMs!: ?Int64) {
        this.sinceMs = sinceMs
        this.rounds = rounds
        this.nextRoundAtMs = nextRoundAtMs
    }
}
