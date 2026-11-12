// GENERATED. Do not edit by hand.

/// The engine asks the host to do its part of a plugin host capability; answer with completePluginCapabilityRequest.
final class PluginCapabilityRequestEvent {
  /// wire: `requestId`. Pass it back with the result.
  final int requestId;
  /// wire: `method`. consent, captureDocument, pickFile, confirmPayment or locateOnce.
  final String method;
  /// wire: `request`. consent: {pluginId, pluginVersion, capability, params?}; captureDocument: {pluginId, side, accept, maxBytes}; pickFile: {pluginId, capability, accept, maxBytes}; confirmPayment: {pluginId, order: {orderId, amount, currency, payee, title, expiresAtMs, operation}}; locateOnce: {pluginId, precision}.
  final Map<String, Object?> request;

  const PluginCapabilityRequestEvent({
    this.requestId = 0,
    this.method = '',
    this.request = const {},
  });
}
