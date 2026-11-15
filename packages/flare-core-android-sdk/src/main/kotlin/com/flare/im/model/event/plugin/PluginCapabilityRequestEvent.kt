package com.flare.im.model.event.plugin

/** GENERATED. Do not edit by hand. */
/** The engine asks the host to do its part of a plugin host capability; answer with completePluginCapabilityRequest. */
data class PluginCapabilityRequestEvent(
    /** wire: `requestId`. Pass it back with the result. */
    val requestId: Long = 0L,
    /** wire: `method`. consent, captureDocument, pickFile, confirmPayment or locateOnce. */
    val method: String = "",
    /** wire: `request`. consent: {pluginId, pluginVersion, capability, params?}; captureDocument: {pluginId, side, accept, maxBytes}; pickFile: {pluginId, capability, accept, maxBytes}; confirmPayment: {pluginId, order: {orderId, amount, currency, payee, title, expiresAtMs, operation}}; locateOnce: {pluginId, precision}. */
    val request: Map<String, Any?> = emptyMap(),
)
