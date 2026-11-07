import Foundation

/// GENERATED. Do not edit by hand.
/// Progress of the periodic manifest refresh.
public struct AccessRefreshStatus: Codable, Sendable {
    /// wire: `lastAttemptAtMs`. When the last round ran, Unix milliseconds.
    public let lastAttemptAtMs: Int64?
    /// wire: `lastSuccessAtMs`. When a source last gave a trusted answer, Unix milliseconds.
    public let lastSuccessAtMs: Int64?
    /// wire: `lastOutcome`. Outcome of the last round: adopted, upToDate, oldValues or failed; absent before the first round.
    public let lastOutcome: String?
    /// wire: `nextAtMs`. When the next round runs, Unix milliseconds; absent while recovering without a network.
    public let nextAtMs: Int64?

    public init(lastAttemptAtMs: Int64? = nil, lastSuccessAtMs: Int64? = nil, lastOutcome: String? = nil, nextAtMs: Int64? = nil) {
        self.lastAttemptAtMs = lastAttemptAtMs
        self.lastSuccessAtMs = lastSuccessAtMs
        self.lastOutcome = lastOutcome
        self.nextAtMs = nextAtMs
    }
}
