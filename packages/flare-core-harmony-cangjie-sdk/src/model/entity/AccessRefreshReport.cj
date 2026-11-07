package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Result of one refresh round.
public class AccessRefreshReport {
    // wire: `outcome`. adopted (a new manifest was taken), upToDate (a source confirmed there is no update), oldValues (notified mode only got old values; a manual refresh never reports it), failed (no source gave a trusted answer) or skipped (development mode).
    public let outcome: String
    // wire: `mode`. Round mode: background, notified or recovering.
    public let mode: String
    // wire: `serial`. Directory serial when the round ended.
    public let serial: UInt64
    // wire: `source`. Optional. Source of the adopted manifest, in the form of AccessStatus.source; absent when nothing was adopted.
    public let source: ?String
    // wire: `keystateSerial`. Optional. Serial of the current key state document.
    public let keystateSerial: ?UInt64
    // wire: `attempts`. Every source tried, in order.
    public let attempts: String

    public init(outcome!: String, mode!: String, serial!: UInt64, source!: ?String, keystateSerial!: ?UInt64, attempts!: String) {
        this.outcome = outcome
        this.mode = mode
        this.serial = serial
        this.source = source
        this.keystateSerial = keystateSerial
        this.attempts = attempts
    }
}
