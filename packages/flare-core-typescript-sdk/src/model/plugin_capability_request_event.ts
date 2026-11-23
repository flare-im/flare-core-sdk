/** GENERATED. Do not edit by hand. */

/** The engine asks the host to do its part of a plugin host capability; answer with completePluginCapabilityRequest. */
export interface PluginCapabilityRequestEvent {
  /** wire: `requestId`. Pass it back with the result. */
  requestId: number;
  /** wire: `method`. consent, captureDocument, pickFile, confirmPayment, locateOnce or the paymentSettled notice. */
  method: string;
  /** wire: `request`. consent: {pluginId, pluginVersion, capability, params?}; captureDocument: {pluginId, side, accept, maxBytes}; pickFile: {pluginId, capability, accept, maxBytes}; confirmPayment: {pluginId, order: {orderId, amount, currency, payee, title, expiresAtMs, operation, shortfall?, topUp?}, error?: {key, code?}, reportsOutcome?}; locateOnce: {pluginId, precision}; paymentSettled (never answered): {pluginId, orderId}. */
  request: Record<string, unknown>;
}
