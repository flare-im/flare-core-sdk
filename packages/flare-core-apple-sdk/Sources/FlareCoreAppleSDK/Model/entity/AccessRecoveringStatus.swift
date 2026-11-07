import Foundation

/// GENERATED. Do not edit by hand.
/// Recovery state while every access point has failed.
public struct AccessRecoveringStatus: Codable, Sendable {
    /// wire: `sinceMs`. When recovery began, Unix milliseconds.
    public let sinceMs: Int64
    /// wire: `rounds`. Bootstrap rounds run so far.
    public let rounds: UInt32
    /// wire: `nextRoundAtMs`. When the next round runs, Unix milliseconds; absent while the device has no network.
    public let nextRoundAtMs: Int64?

    public init(sinceMs: Int64 = 0, rounds: UInt32 = 0, nextRoundAtMs: Int64? = nil) {
        self.sinceMs = sinceMs
        self.rounds = rounds
        self.nextRoundAtMs = nextRoundAtMs
    }
}
