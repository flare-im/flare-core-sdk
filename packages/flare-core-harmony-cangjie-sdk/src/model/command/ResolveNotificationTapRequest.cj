package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The payload of a notification the user tapped.
public class ResolveNotificationTapRequest {
    // wire: `payload`. The push payload flattened to strings, as in handleRemoteMessage.
    public let payload: String

    public init(payload!: String) {
        this.payload = payload
    }
}
