package flare_core_harmony_cangjie_sdk.model.event.plugin

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The engine asks the host to do its part of a plugin host capability; answer with completePluginCapabilityRequest.
public class PluginCapabilityRequestEvent {
    // wire: `requestId`. Pass it back with the result.
    public let requestId: UInt64
    // wire: `method`. consent, captureDocument, pickFile, scanCode, confirmPayment, locateOnce or the paymentSettled notice.
    public let method: String
    // wire: `request`. consent: {pluginId, pluginVersion, capability, params?}; captureDocument: {pluginId, side, accept, maxBytes}; pickFile: {pluginId, capability, accept, maxBytes}; scanCode: {pluginId}; confirmPayment: {pluginId, order: {orderId, amount, currency, payee, title, expiresAtMs, operation, shortfall?, topUp?}, error?: {key, code?}, reportsOutcome?}; locateOnce: {pluginId, precision}; paymentSettled (never answered): {pluginId, orderId}.
    public let request: String

    public init(requestId!: UInt64, method!: String, request!: String) {
        this.requestId = requestId
        this.method = method
        this.request = request
    }
}
