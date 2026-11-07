import Foundation

/// GENERATED. Do not edit by hand.
/// Result of one refresh round.
public struct AccessRefreshReport: Codable, Sendable {
    /// wire: `outcome`. adopted (a new manifest was taken), upToDate (a source confirmed there is no update), oldValues (notified mode only got old values; a manual refresh never reports it), failed (no source gave a trusted answer) or skipped (development mode).
    public let outcome: String
    /// wire: `mode`. Round mode: background, notified or recovering.
    public let mode: String
    /// wire: `serial`. Directory serial when the round ended.
    public let serial: UInt64
    /// wire: `source`. Source of the adopted manifest, in the form of AccessStatus.source; absent when nothing was adopted.
    public let source: String?
    /// wire: `keystateSerial`. Serial of the current key state document.
    public let keystateSerial: UInt64?
    /// wire: `attempts`. Every source tried, in order.
    public let attempts: [AccessRefreshAttempt]

    public init(outcome: String = "", mode: String = "", serial: UInt64 = 0, source: String? = nil, keystateSerial: UInt64? = nil, attempts: [AccessRefreshAttempt] = []) {
        self.outcome = outcome
        self.mode = mode
        self.serial = serial
        self.source = source
        self.keystateSerial = keystateSerial
        self.attempts = attempts
    }
}
