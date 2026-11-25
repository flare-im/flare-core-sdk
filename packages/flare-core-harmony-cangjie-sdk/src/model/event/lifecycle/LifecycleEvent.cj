package flare_core_harmony_cangjie_sdk.model.event.lifecycle

import flare_core_harmony_cangjie_sdk.model.common.error.SdkErrorPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Lifecycle notification. Method return values remain the primary success/failure contract.
public class LifecycleEvent {
    // wire: `name`. Lifecycle event name.
    public let name: LifecycleEventName
    // wire: `operation`. Operation associated with this lifecycle event.
    public let operation: String
    // wire: `userId`. Optional. Current user id when known.
    public let userId: ?String
    // wire: `sessionId`. Optional. SDK session id when available.
    public let sessionId: ?String
    // wire: `error`. Optional. Failure details for *_failed events.
    public let error: ?SdkErrorPayload

    public init(name!: LifecycleEventName, operation!: String, userId!: ?String, sessionId!: ?String, error!: ?SdkErrorPayload) {
        this.name = name
        this.operation = operation
        this.userId = userId
        this.sessionId = sessionId
        this.error = error
    }
}
