import Foundation

/// GENERATED. Do not edit by hand.
/// The engine asks the host to do its part of a plugin host capability; answer with completePluginCapabilityRequest.
public struct PluginCapabilityRequestEvent: Sendable {
    /// wire: `requestId`. Pass it back with the result.
    public let requestId: UInt64
    /// wire: `method`. consent, captureDocument, pickFile, scanCode, confirmPayment, locateOnce or the paymentSettled notice.
    public let method: String
    /// wire: `request`. consent: {pluginId, pluginVersion, capability, params?}; captureDocument: {pluginId, side, accept, maxBytes}; pickFile: {pluginId, capability, accept, maxBytes}; scanCode: {pluginId}; confirmPayment: {pluginId, order: {orderId, amount, currency, payee, title, expiresAtMs, operation, shortfall?, topUp?}, error?: {key, code?}, reportsOutcome?}; locateOnce: {pluginId, precision}; paymentSettled (never answered): {pluginId, orderId}.
    public let request: [String: AnySendable]

    public init(requestId: UInt64 = 0, method: String = "", request: [String: AnySendable] = [:]) {
        self.requestId = requestId
        self.method = method
        self.request = request
    }
}
