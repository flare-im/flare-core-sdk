package flare_core_harmony_cangjie_sdk.listener

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Plugin listener callbacks.
public interface PluginEventListener {
    // A plugin delivered a realtime packet to this user's online connections (im.realtime.deliver): online only, at most once, never stored. Expired packets and payloads that are not JSON objects never arrive. Route by pluginId and packetType.
    func onPluginRealtime(event: PluginRealtimeEvent): Unit
    // The tenant's plugin catalog changed (a plugin enabled, disabled or reconfigured). The SDK has already invalidated its plugin catalog; read plugin entries and configuration again. Arrives a random 0-3 s after the notice, with the notices of 3 s merged into one.
    func onPluginCatalogChanged(event: PluginCatalogChangedEvent): Unit
    // The engine asks the host to handle consent, captureDocument, pickFile, scanCode, confirmPayment or locateOnce. Answer with completePluginCapabilityRequest({requestId, result}) within 10 minutes. paymentSettled is a notification and does not require a response.
    func onPluginCapabilityRequest(event: PluginCapabilityRequestEvent): Unit
    // Something for an open web bundle page: post envelope (a bridge event) to the page as it is; close the page when close is set (withdrawn, suspended, disabled, replaced, evicted or signedOut).
    func onPluginBundleEvent(event: PluginBundleEvent): Unit
}
