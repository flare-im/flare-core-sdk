package flare_core_harmony_cangjie_sdk.model.event.message

import flare_core_harmony_cangjie_sdk.model.common.error.SdkErrorPayload

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Message send failure notification.
public class MessageSendFailedEvent {
    // wire: `clientMsgId`. Client message id that failed.
    public let clientMsgId: String
    // wire: `reason`. Failure reason text for people; use error.code and error.machineReason to act on it.
    public let reason: String
    // wire: `error`. Optional. Structured failure: code, machineReason (ErrorDetail.reason when the server rejected), message, operation, retryable, details.
    public let error: ?SdkErrorPayload

    public init(clientMsgId!: String, reason!: String, error!: ?SdkErrorPayload) {
        this.clientMsgId = clientMsgId
        this.reason = reason
        this.error = error
    }
}
