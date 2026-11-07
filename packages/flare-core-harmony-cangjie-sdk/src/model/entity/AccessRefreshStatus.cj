package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Progress of the periodic manifest refresh.
public class AccessRefreshStatus {
    // wire: `lastAttemptAtMs`. Optional. When the last round ran, Unix milliseconds.
    public let lastAttemptAtMs: ?Int64
    // wire: `lastSuccessAtMs`. Optional. When a source last gave a trusted answer, Unix milliseconds.
    public let lastSuccessAtMs: ?Int64
    // wire: `lastOutcome`. Optional. Outcome of the last round: adopted, upToDate, oldValues or failed; absent before the first round.
    public let lastOutcome: ?String
    // wire: `nextAtMs`. Optional. When the next round runs, Unix milliseconds; absent while recovering without a network.
    public let nextAtMs: ?Int64

    public init(lastAttemptAtMs!: ?Int64, lastSuccessAtMs!: ?Int64, lastOutcome!: ?String, nextAtMs!: ?Int64) {
        this.lastAttemptAtMs = lastAttemptAtMs
        this.lastSuccessAtMs = lastSuccessAtMs
        this.lastOutcome = lastOutcome
        this.nextAtMs = nextAtMs
    }
}
