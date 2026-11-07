package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Answer to one connect token refresh request.
public class CompleteConnectTokenRefreshRequest {
    // wire: `requestId`. Request id the core asked with.
    public let requestId: UInt64
    // wire: `token`. Optional. The new connect token; omitted or empty when none could be obtained.
    public let token: ?String

    public init(requestId!: UInt64, token!: ?String) {
        this.requestId = requestId
        this.token = token
    }
}
