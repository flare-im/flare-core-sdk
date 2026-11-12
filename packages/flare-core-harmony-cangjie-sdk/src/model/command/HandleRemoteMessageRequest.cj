package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One remote push the platform push module received.
public class HandleRemoteMessageRequest {
    // wire: `budgetMs`. Optional. Background execution time the platform holds for this push, in milliseconds. Above zero the engine also wakes the link for one incremental sync within it; the answer never waits for that.
    public let budgetMs: ?UInt32
    // wire: `payload`. The push payload flattened to strings (snake_case keys): uid, tenant_id, conversation_id, message_id, seq, collapse_id, thread_id, disposition, alert_class, count, badge, title, body, sound. Keys the engine does not know are ignored.
    public let payload: String
    // wire: `provider`. Push channel that delivered it: apns, fcm or getui.
    public let provider: String

    public init(budgetMs!: ?UInt32, payload!: String, provider!: String) {
        this.budgetMs = budgetMs
        this.payload = payload
        this.provider = provider
    }
}
