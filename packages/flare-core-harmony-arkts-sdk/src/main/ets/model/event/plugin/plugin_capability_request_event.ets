// GENERATED. Do not edit by hand.

/** The engine asks the host to do its part of a plugin host capability; answer with completePluginCapabilityRequest. */
export interface PluginCapabilityRequestEvent {
  /** wire: `requestId`. Pass it back with the result. */
  requestId: number;
  /** wire: `method`. consent, captureDocument, pickFile, confirmPayment or locateOnce. */
  method: string;
  /** wire: `request`. consent: {pluginId, pluginVersion, capability, params?}; captureDocument: {pluginId, side, accept, maxBytes}; pickFile: {pluginId, capability, accept, maxBytes}; confirmPayment: {pluginId, order: {orderId, amount, currency, payee, title, expiresAtMs, operation}}; locateOnce: {pluginId, precision}. */
  request: Record<string, Object>;
}
